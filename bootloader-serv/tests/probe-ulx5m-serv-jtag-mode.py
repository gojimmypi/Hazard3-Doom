#!/usr/bin/env python3
"""Read-only Tigard JTAG detection and 4 KiB flash-recovery mode probe.

Report one manually established ULX5M configuration state per invocation.
This tool NEVER changes reset, configuration straps, or flash contents.
"""

import argparse
import importlib.util
import json
import re
from pathlib import Path
import subprocess
import sys
import tempfile

RECOVERY_FILE = Path(__file__).with_name("check-ulx5m-serv-jtag-recovery.py")
_spec = importlib.util.spec_from_file_location("ulx5m_jtag_recovery_readonly", RECOVERY_FILE)
_recovery = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_recovery)

CHUNK_BYTES = 4096
GATEMATE_IDCODE = 0x20000001
STATES = ("flash-boot", "sram-loaded", "jtag-selected")
FORBIDDEN = {"-f", "--write-flash", "-m", "--reset", "--bulk-erase",
             "--unprotect-flash", "--protect-flash"}


def commands(loader, freq_khz, output):
    if freq_khz <= 0 or freq_khz > 10000:
        raise ValueError("JTAG frequency must be between 1 and 10000 kHz")
    detect = [str(loader), "-c", "tigard", "--freq", f"{freq_khz}k", "--detect", "-v"]
    dump = _recovery.build_dump_command(loader, output, freq_khz, 0, CHUNK_BYTES)
    for cmd in (detect, dump):
        if any(part in FORBIDDEN for part in cmd):
            raise ValueError("Unsafe programmer command was constructed")
    return detect, dump


def execute(cmd, timeout_seconds=120):
    try:
        result = subprocess.run(cmd, capture_output=True, text=True,
                                check=False, timeout=timeout_seconds)
        output = (result.stdout or "") + (result.stderr or "")
        # Some drivers report failure in output even when process exit is zero.
        detected_error = "no device found" in output.lower()
        return {"ok": result.returncode == 0 and not detected_error,
                "returncode": result.returncode,
                "detail": (output.strip() if "--detect" in cmd
                           else output.strip()[-2000:])}
    except subprocess.TimeoutExpired:
        return {"ok": False, "returncode": None,
                "detail": "Read-only openFPGALoader command timed out"}
    except OSError as exc:
        return {"ok": False, "returncode": None,
                "detail": f"openFPGALoader launch failed: {exc}"}


def parse_jtag_detection(result):
    """Require a GateMate IDCODE, not merely --detect exit status.

    openFPGALoader may exit 0 on an empty JTAG chain in --detect mode.
    """
    detail = result['detail']
    indices = re.findall(r"(?m)^\s*index\s+(\d+):\s*$", detail)
    idcodes = [int(value, 16) for value in re.findall(
        r"(?im)^\s*idcode\s+(0x[0-9a-f]+)\s*$", detail)]
    result['jtag_indices'] = [int(value) for value in indices]
    result['idcodes'] = [f"0x{value:08x}" for value in idcodes]
    result['gatemate_found'] = (bool(indices) and GATEMATE_IDCODE in idcodes)
    if result['ok'] and not indices:
        result['ok'] = False
        result['reason'] = ("openFPGALoader --detect exited 0 but reported "
                            "no JTAG devices")
    elif result['ok'] and not result['gatemate_found']:
        result['ok'] = False
        result['reason'] = "GateMate IDCODE 0x20000001 not found in JTAG chain"
    elif not result['ok']:
        result['reason'] = "JTAG detection command failed"
    else:
        result['reason'] = "GateMate IDCODE confirmed"
    return result


def run_probe(args, backup_sha):
    with tempfile.TemporaryDirectory(prefix="ulx5m-jtag-mode-") as temp:
        output = Path(temp) / "jtag-4k-read.bin"
        detect_cmd, dump_cmd = commands(args.loader, args.freq_khz, output)
        print("[DETECT] " + subprocess.list2cmdline(detect_cmd), flush=True)
        detect = parse_jtag_detection(execute(detect_cmd))
        print(f"[DETECT] {'PASS' if detect['ok'] else 'FAIL'} "
              f"exit={detect['returncode']} "
              f"devices={len(detect['jtag_indices'])} "
              f"idcodes={','.join(detect['idcodes']) or 'none'} "
              f"{detect['reason']}", flush=True)
        # GateMate JTAG can disappear after its configuration bank changes
        # to user I/O. An empty TAP chain cannot support JTAG-SPI flash access.
        # Do not issue a guaranteed-to-fail read when the chain is empty.
        if not detect['jtag_indices']:
            detail = ("SKIPPED: empty JTAG chain. GateMate JTAG can be disabled "
                      "after configuration-bank switch to user I/O. Restore "
                      "FPGA global reset (RST_N), not merely USB/firmware "
                      "reset; verify the board's reset wiring and CFG_MD "
                      "before testing again.")
            print(f"[FLASH] {detail}", flush=True)
            return {"format": "ULX5M-GS JTAG recovery mode probe-v3",
                    "state": args.state, "readonly": True,
                    "flash_size": _recovery.FLASH_SIZE,
                    "flash_backup_sha256": backup_sha,
                    "jtag_detect": detect,
                    "flash_read": {"ok": False, "skipped": True,
                                   "returncode": None, "offset": 0,
                                   "length": CHUNK_BYTES, "detail": detail}}
        print("[FLASH] " + subprocess.list2cmdline(dump_cmd), flush=True)
        dump = execute(dump_cmd)
        matched = False
        detail = dump['detail']
        if dump['ok']:
            if not output.is_file() or output.stat().st_size != CHUNK_BYTES:
                detail = "Read returned success but did not create exactly 4096 bytes"
            else:
                with (args.backup_dir / "flash-pass1.bin").open("rb") as f:
                    expected = f.read(CHUNK_BYTES)
                data = output.read_bytes()
                matched = data == expected
                if not matched:
                    first = next(i for i in range(CHUNK_BYTES)
                                 if data[i] != expected[i])
                    detail = f"First mismatch at flash address 0x{first:06x}"
                else:
                    detail = "4096 bytes match both verified USB backups"
        flash_ok = dump['ok'] and matched
        print(f"[FLASH] {'PASS' if flash_ok else 'FAIL'} {detail if not flash_ok else ''}",
              flush=True)
        return {"format": "ULX5M-GS JTAG recovery mode probe-v3",
                "state": args.state, "readonly": True,
                "flash_size": _recovery.FLASH_SIZE,
                "flash_backup_sha256": backup_sha,
                "jtag_detect": detect,
                "flash_read": {"ok": flash_ok, "skipped": False,
                               "returncode": dump['returncode'],
                               "offset": 0, "length": CHUNK_BYTES,
                               "detail": detail}}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    root = Path(__file__).resolve().parents[2]
    parser.add_argument("--backup-dir", type=Path, required=True)
    parser.add_argument("--state", choices=STATES, required=True,
                        help="Manually established state, not changed by this program")
    parser.add_argument("--report", type=Path, required=True,
                        help="New JSON report file; no overwrite permitted")
    parser.add_argument("--loader", type=Path,
                        default=root / "bin" / "openFPGALoader.exe")
    parser.add_argument("--freq-khz", type=int, default=1000)
    parser.add_argument("--run", action="store_true",
                        help="Execute read-only detection and 4 KiB flash probe")
    args = parser.parse_args(argv)
    try:
        # Always verify the two original backups first, even in dry-run mode.
        backup_sha = _recovery.check_reference(args.backup_dir)
        if args.report.exists():
            raise ValueError(f"Report already exists (refusing overwrite): {args.report}")
        if not args.loader.is_file():
            raise ValueError(f"Cannot find programmer: {args.loader}")
        detect_cmd, dump_cmd = commands(args.loader, args.freq_khz,
                                        Path("<temporary-4096-byte-file>"))
        print(f"[BACKUP] Verified 2 x 4 MiB, SHA-256 {backup_sha}")
        print(f"[MODE] {args.state} (manually selected; no state changes issued)")
        if not args.run:
            print("[DRY RUN] " + subprocess.list2cmdline(detect_cmd))
            print("[DRY RUN] " + subprocess.list2cmdline(dump_cmd))
            print("[DRY RUN] Nothing executed. Add --run for read-only operations.")
            return 0
        report = run_probe(args, backup_sha)
        args.report.parent.mkdir(parents=True, exist_ok=True)
        with args.report.open("x", encoding="utf-8", newline="\n") as dest:
            json.dump(report, dest, indent=2, sort_keys=True)
            dest.write("\n")
        print(f"[REPORT] {args.report}")
        print("[POLICY] Flash WRITE and boot selection remain unverified and DISABLED")
        return 0 if report['flash_read']['ok'] else 1
    except (ValueError, OSError, json.JSONDecodeError) as exc:
        print(f"[FAIL] {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
