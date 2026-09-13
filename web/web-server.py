#!/usr/bin/env python3

import argparse
import getpass
import hmac
import http.server
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from urllib.parse import parse_qs, urlsplit


OPENOCD_GDB_HOST = "127.0.0.1"
OPENOCD_GDB_PORT = 3333
MY_RUFF = os.environ.get("MY_RUFF", "ruff")
MAX_FIRMWARE_BYTES = 16 * 1024 * 1024
DEFAULT_ALLOWED_ORIGINS = frozenset(
    {
        "https://gojimmypi.github.io",
        "https://ulx3s.github.io",
        # See below for allowed_origins.update based on the port argument.
    }
)
API_PATHS = frozenset(
    {
        "/api/console-firmware/status",
        "/api/console-firmware/load",
    }
)
ALLOWED_CORS_HEADERS = frozenset(
    {
        "content-type",
        "x-hazard3-doom-key",
        "x-hazard3-doom-local",
    }
)


class Hazard3DoomRequestHandler(http.server.SimpleHTTPRequestHandler):
    """Serve static files and load console firmware through local GDB."""

    firmware_loader = Path()
    repo_root = Path()
    allowed_origins = DEFAULT_ALLOWED_ORIGINS
    access_key: str | None = None

    def request_path(self) -> str:
        return urlsplit(self.path).path

    def is_api_request(self) -> bool:
        return self.request_path() in API_PATHS

    def request_origin_allowed(self) -> bool:
        origin = self.headers.get("Origin")
        return origin is None or origin in self.allowed_origins

    def send_cors_headers(self) -> None:
        origin = self.headers.get("Origin")
        if origin is not None and origin in self.allowed_origins:
            self.send_header("Access-Control-Allow-Origin", origin)
            self.send_header("Vary", "Origin")

    def send_json(self, status: int, response: dict[str, object]) -> None:
        payload = json.dumps(response).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        if self.is_api_request():
            self.send_cors_headers()
        self.end_headers()
        self.wfile.write(payload)

    def require_allowed_origin(self) -> bool:
        if self.request_origin_allowed():
            return True
        self.send_json(403, {"ok": False, "error": "Origin is not allowed."})
        return False

    def access_key_valid(self) -> bool:
        if self.access_key is None:
            return True
        supplied_key = self.headers.get("X-Hazard3-Doom-Key", "")
        return hmac.compare_digest(supplied_key, self.access_key)

    def require_access_key(self) -> bool:
        if self.access_key_valid():
            return True
        self.send_json(
            401,
            {
                "ok": False,
                "available": False,
                "authentication_required": True,
                "error": "Local loader access key is required or incorrect.",
            },
        )
        return False

    def do_OPTIONS(self) -> None:
        if not self.is_api_request():
            self.send_error(404)
            return
        if not self.request_origin_allowed():
            self.send_error(403)
            return

        requested_method = self.headers.get("Access-Control-Request-Method", "")
        if requested_method and requested_method not in {"GET", "POST"}:
            self.send_error(405)
            return

        requested_headers = {
            item.strip().lower()
            for item in self.headers.get("Access-Control-Request-Headers", "").split(",")
            if item.strip()
        }
        if not requested_headers.issubset(ALLOWED_CORS_HEADERS):
            self.send_error(403)
            return

        self.send_response(204)
        self.send_cors_headers()
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header(
            "Access-Control-Allow-Headers",
            "Content-Type, X-Hazard3-Doom-Local, X-Hazard3-Doom-Key",
        )
        self.send_header("Access-Control-Max-Age", "600")
        if self.headers.get("Access-Control-Request-Private-Network") == "true":
            self.send_header("Access-Control-Allow-Private-Network", "true")
        self.end_headers()

    def do_GET(self) -> None:
        if self.request_path() == "/api/console-firmware/status":
            if not self.require_allowed_origin() or not self.require_access_key():
                return
            query = parse_qs(urlsplit(self.path).query)
            challenge = query.get("challenge", [""])[0]
            self.send_json(
                200,
                {
                    "available": self.firmware_loader.is_file()
                    and os.access(self.firmware_loader, os.X_OK),
                    "authentication_required": self.access_key is not None,
                    "openocd_gdb_ready": openocd_gdb_port_is_ready(),
                    "openocd_gdb_host": OPENOCD_GDB_HOST,
                    "openocd_gdb_port": OPENOCD_GDB_PORT,
                    "challenge": challenge,
                },
            )
            return
        super().do_GET()

    def do_POST(self) -> None:
        if self.request_path() != "/api/console-firmware/load":
            self.send_error(404)
            return
        if not self.require_allowed_origin() or not self.require_access_key():
            return
        if self.headers.get("X-Hazard3-Doom-Local") != "1":
            self.send_json(403, {"ok": False, "error": "Missing local request header."})
            return
        if self.headers.get_content_type() != "application/octet-stream":
            self.send_json(415, {"ok": False, "error": "Expected an ELF byte stream."})
            return

        try:
            content_length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            self.send_json(400, {"ok": False, "error": "Invalid Content-Length."})
            return

        if content_length < 52 or content_length > MAX_FIRMWARE_BYTES:
            self.send_json(
                400,
                {
                    "ok": False,
                    "error": "Firmware must be a 32-bit RISC-V ELF no larger than 16 MiB.",
                },
            )
            return
        if not self.firmware_loader.is_file() or not os.access(
            self.firmware_loader,
            os.X_OK,
        ):
            self.send_json(
                503,
                {
                    "ok": False,
                    "error": "Firmware loader script was not found or is not executable.",
                },
            )
            return

        firmware = self.rfile.read(content_length)
        if len(firmware) != content_length:
            self.send_json(400, {"ok": False, "error": "Firmware upload ended early."})
            return
        if (
            firmware[:4] != b"\x7fELF"
            or firmware[4] != 1
            or firmware[5] != 1
            or firmware[6] != 1
            or int.from_bytes(firmware[16:18], "little") != 2
            or int.from_bytes(firmware[18:20], "little") != 243
            or int.from_bytes(firmware[20:24], "little") != 1
        ):
            self.send_json(
                400,
                {
                    "ok": False,
                    "error": "Selected file is not a 32-bit little-endian RISC-V ELF.",
                },
            )
            return

        temporary_path: Path | None = None
        try:
            with tempfile.NamedTemporaryFile(
                prefix="hazard3-console-firmware-",
                suffix=".elf",
                delete=False,
            ) as temporary:
                temporary.write(firmware)
                temporary_path = Path(temporary.name)

            result = subprocess.run(
                [str(self.firmware_loader), str(temporary_path)],
                cwd=self.repo_root,
                capture_output=True,
                text=True,
                timeout=180,
                check=False,
            )
            output = "".join((result.stdout, result.stderr))
            if result.returncode != 0:
                self.send_json(
                    500,
                    {
                        "ok": False,
                        "error": f"Firmware loader exited with status {result.returncode}.",
                        "output": output,
                    },
                )
                return

            self.send_json(200, {"ok": True, "output": output})
        except subprocess.TimeoutExpired as error:
            stdout = (
                error.stdout.decode(errors="replace")
                if isinstance(error.stdout, bytes)
                else error.stdout
            )
            stderr = (
                error.stderr.decode(errors="replace")
                if isinstance(error.stderr, bytes)
                else error.stderr
            )
            output = "".join((stdout or "", stderr or ""))
            self.send_json(
                504,
                {
                    "ok": False,
                    "error": "Firmware loader timed out after 180 seconds.",
                    "output": output,
                },
            )
        except OSError as error:
            self.send_json(500, {"ok": False, "error": str(error)})
        finally:
            if temporary_path is not None:
                temporary_path.unlink(missing_ok=True)


def check_python_script() -> None:
    """Check this script before continuing."""
    script = Path(__file__).resolve()

    subprocess.run(
        [sys.executable, "-m", "py_compile", str(script)],
        check=True,
    )

    # Check if the executable is available in the PATH.
    if shutil.which(MY_RUFF):
        result = subprocess.run(
            [MY_RUFF, "check", str(script)],
            stdout=sys.stderr,
            stderr=sys.stderr,
            check=False,
        )
        if result.returncode != 0:
            raise SystemExit(result.returncode)
    else:
        print(
            f"{MY_RUFF} is not installed. "
            "Please install it if changes to this script have been made.",
            file=sys.stderr,
        )

def _linux_tcp_listener_is_present(port: int) -> bool:
    """Check Linux TCP socket tables without connecting to the service."""
    port_hex = f"{port:04X}"
    for table in (Path("/proc/net/tcp"), Path("/proc/net/tcp6")):
        try:
            lines = table.read_text(encoding="ascii").splitlines()[1:]
        except OSError:
            continue

        for line in lines:
            fields = line.split()
            if len(fields) < 4 or fields[3] != "0A":
                continue
            local_address = fields[1]
            if local_address.rsplit(":", 1)[-1].upper() == port_hex:
                return True
    return False


def _windows_tcp_listener_is_present(port: int) -> bool:
    """Check the Windows TCP listener table without opening a connection."""
    netstat = shutil.which("netstat.exe")
    if netstat is None and os.name == "nt":
        netstat = shutil.which("netstat")
    if netstat is None:
        return False

    try:
        result = subprocess.run(
            [netstat, "-an", "-p", "tcp"],
            capture_output=True,
            text=True,
            timeout=2,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return False

    wanted_port = str(port)
    for line in result.stdout.splitlines():
        fields = line.split()
        if len(fields) < 4 or fields[0].upper() != "TCP":
            continue
        if fields[-1].upper() != "LISTENING":
            continue
        if fields[1].rsplit(":", 1)[-1] == wanted_port:
            return True
    return False


def openocd_gdb_port_is_ready() -> bool:
    """Passively check for a GDB listener; never connect to OpenOCD port 3333."""
    if _linux_tcp_listener_is_present(OPENOCD_GDB_PORT):
        return True
    return _windows_tcp_listener_is_present(OPENOCD_GDB_PORT)

def main() -> None:
    check_python_script()

    parser = argparse.ArgumentParser(
        description="Serve the Hazard3-Doom web UI and loopback loader API.",
    )
    parser.add_argument(
        "port",
        nargs="?",
        type=int,
        default=8000,
        help="HTTP port (default: 8000)",
    )
    parser.add_argument(
        "--firmware-loader",
        type=Path,
        help="firmware loader script (default: ../scripts/load-firmware.sh)",
    )
    parser.add_argument(
        "--access-key",
        nargs="?",
        const=True,
        default=False,
        metavar="KEY",
        help=(
            "require an access key for the loader API; omit KEY to prompt without echo"
        ),
    )
    parser.add_argument(
        "--allow-origin",
        action="append",
        default=[],
        metavar="ORIGIN",
        help="add an exact CORS origin allowed to use the loopback API",
    )
    args = parser.parse_args()

    access_key: str | None
    if args.access_key is True:
        access_key = getpass.getpass("Local loader access key: ")
        if not access_key:
            parser.error("--access-key requires a non-empty key")
    elif args.access_key is False:
        access_key = None
    else:
        access_key = args.access_key
        if not access_key:
            parser.error("--access-key requires a non-empty key")

    allowed_origins = set(DEFAULT_ALLOWED_ORIGINS)
    loopback_port = "" if args.port == 80 else f":{args.port}"
    allowed_origins.update(
        {
            f"http://127.0.0.1{loopback_port}",
            f"http://localhost{loopback_port}",
        }
    )
    for origin in args.allow_origin:
        if origin == "*":
            parser.error("--allow-origin '*' is not permitted")
        allowed_origins.add(origin.rstrip("/"))

    web_dir = Path(__file__).resolve().parent
    repo_root = web_dir.parent
    firmware_loader = (
        args.firmware_loader.resolve()
        if args.firmware_loader
        else repo_root / "scripts" / "load-firmware.sh"
    )
    Hazard3DoomRequestHandler.firmware_loader = firmware_loader
    Hazard3DoomRequestHandler.repo_root = repo_root
    Hazard3DoomRequestHandler.allowed_origins = frozenset(allowed_origins)
    Hazard3DoomRequestHandler.access_key = access_key
    os.chdir(web_dir)

    server = http.server.ThreadingHTTPServer(
        ("127.0.0.1", args.port),
        Hazard3DoomRequestHandler,
    )

    print("Serving Hazard3-Doom web UI from:")
    print(f"  {web_dir}")
    print()
    print("Open:")
    print(f"  http://127.0.0.1:{args.port}/")
    print()
    print("Console firmware loader:")
    print(f"  {firmware_loader}")
    print(f"  access key: {'required' if access_key is not None else 'disabled, consider using --access-key'}")

    if openocd_gdb_port_is_ready():
        print(
            "  OpenOCD: ready - GDB server detected on "
            f"{OPENOCD_GDB_HOST}:{OPENOCD_GDB_PORT}"
        )
    else:
        print(
            "  OpenOCD: WARNING - no GDB server detected on "
            f"{OPENOCD_GDB_HOST}:{OPENOCD_GDB_PORT}"
        )
        print(
            "           Console ELF loading will not work until "
            "OpenOCD is started."
        )

    print("  allowed API origins:")

    for origin in sorted(allowed_origins):
        print(f"    {origin}")
    print()
    print("Press Ctrl-C to stop.")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print()
        print("Server stopped.")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
