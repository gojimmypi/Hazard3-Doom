#!/usr/bin/env python3

import argparse
import http.server
import os
import shutil
import subprocess
import sys
from pathlib import Path


MY_RUFF = os.environ.get("MY_RUFF", "ruff")


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


def main() -> None:
    check_python_script()

    parser = argparse.ArgumentParser(
        description="Serve the Hazard3-Doom web UI.",
    )
    parser.add_argument(
        "port",
        nargs="?",
        type=int,
        default=8000,
        help="HTTP port (default: 8000)",
    )
    args = parser.parse_args()

    web_dir = Path(__file__).resolve().parent
    os.chdir(web_dir)

    server = http.server.ThreadingHTTPServer(
        ("127.0.0.1", args.port),
        http.server.SimpleHTTPRequestHandler,
    )

    print("Serving Hazard3-Doom web UI from:")
    print(f"  {web_dir}")
    print()
    print("Open:")
    print(f"  http://127.0.0.1:{args.port}/")
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