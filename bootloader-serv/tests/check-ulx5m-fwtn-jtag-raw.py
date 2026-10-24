#!/usr/bin/env python3
"""Read-only check of native-slot JTAG-SPI reads, without modifying dumps.

A clean raw dump must exactly match the JTAG-tested 3026-byte image plus
1070 erased bytes. Identify the known one-bit stream shift, but do not
silently repair it or treat a shifted dump as a clean reader pass.
"""

import argparse
import hashlib
from pathlib import Path
import subprocess
import sys

APP_SHA256 = "68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd"
SECTOR_SHA256 = "28b1e5cbfa45a319600ec38c81207a36d9889c3179e8055f5a663c616ef97bee"
APP_LENGTH = 3026
SECTOR_LENGTH = 4096
FLASH_OFFSET = 0x201000
REPO = Path(__file__).resolve().parents[2]
APP = REPO / "bootloader-serv/build-ulx5m-gs/top_ulx5m_gs_normal_led.bit"
LOADER = REPO / "bin/openFPGALoader.exe"


def expected_sector(app_path):
    app = Path(app_path).read_bytes()
    if len(app) != APP_LENGTH or hashlib.sha256(app).hexdigest() != APP_SHA256:
        raise ValueError("expected 3026-byte JTAG-proven application not found")
    expected = app + b"\xff" * (SECTOR_LENGTH - len(app))
    if hashlib.sha256(expected).hexdigest() != SECTOR_SHA256:
        raise ValueError("native sector fixture SHA-256 mismatch")
    return expected


def diagnose(raw, expected):
    """Return (status, message). Never rewrite the raw bytes."""
    if len(raw) not in (SECTOR_LENGTH, SECTOR_LENGTH + 1):
        return "invalid", f"unexpected dump length {len(raw)} (expected 4096 or 4097)"
    if raw[:SECTOR_LENGTH] == expected:
        return "clean", "raw flash bytes match the native sector without correction"

    # This comparison is diagnostic only. A shifted read is NEVER a clean pass.
    count = min(len(raw) - 1, SECTOR_LENGTH)
    matches = sum(
        (((raw[i] << 1) & 0xff) | (raw[i + 1] >> 7)) == expected[i]
        for i in range(count)
    )
    if matches == count:
        return "shifted", f"JTAG-SPI stream shifted right by one bit ({matches}/{count} decoded bytes match)"

    first_bad = next(i for i, (a, b) in enumerate(zip(raw, expected)) if a != b)
    return "mismatch", f"raw flash differs at sector offset 0x{first_bad:03x}"


def read_command(loader, output, freq_khz, invert_read_edge=False):
    if not 1 <= freq_khz <= 10000:
        raise ValueError("JTAG frequency must be in 1..10000 kHz")
    command = [str(loader), "-c", "tigard", "--freq", f"{freq_khz}k"]
    if invert_read_edge:
        command.append("--invert-read-edge")
    return command + ["--dump-flash", "--offset", str(FLASH_OFFSET),
                      "--file-size", str(SECTOR_LENGTH + 1), str(output)]


def inverted_read_command(loader, output, freq_khz):
    return read_command(loader, output, freq_khz, invert_read_edge=True)


def run_read_probe(loader, output, freq_khz, invert_read_edge=False):
    loader = Path(loader)
    output = Path(output)
    if not loader.is_file():
        raise ValueError("Windows openFPGALoader.exe not found; run from WSL with bin/ installed")
    if output.exists():
        raise ValueError("output exists; refuse to overwrite " + str(output))
    if not output.parent.is_dir():
        raise ValueError("output directory does not exist")
    cmd = read_command(loader, output, freq_khz, invert_read_edge)
    mode = "inverted" if invert_read_edge else "standard"
    print(f"[INFO] Running read-only {mode}-edge JTAG-SPI dump", flush=True)
    print("[INFO] " + " ".join(cmd), flush=True)
    try:
        result = subprocess.run(cmd, timeout=150, check=False)
    except subprocess.TimeoutExpired as exc:
        raise ValueError("flash read timed out; do not use partial dump") from exc
    if result.returncode != 0:
        raise ValueError("OpenFPGALoader flash read failed; do not use partial dump")
    if not output.is_file():
        raise ValueError("flash read exited successfully but no output file was produced")
    return output.read_bytes()


def run_inverted_probe(loader, output, freq_khz):
    return run_read_probe(loader, output, freq_khz, invert_read_edge=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--dump", type=Path, help="offline analysis of an existing raw dump")
    group.add_argument("--probe-inverted", type=Path,
                       help="read a new 4097-byte dump using --invert-read-edge (no writes)")
    group.add_argument("--probe-standard", type=Path,
                       help="read a new 4097-byte dump with the normal edge (no writes)")
    parser.add_argument("--app", type=Path, default=APP)
    parser.add_argument("--loader", type=Path, default=LOADER)
    parser.add_argument("--freq-khz", type=int, default=1000)
    args = parser.parse_args(argv)
    try:
        expected = expected_sector(args.app)
        if args.dump is not None:
            raw = args.dump.read_bytes()
            path = args.dump
        elif args.probe_inverted is not None:
            raw = run_inverted_probe(args.loader, args.probe_inverted, args.freq_khz)
            path = args.probe_inverted
        else:
            raw = run_read_probe(args.loader, args.probe_standard, args.freq_khz)
            path = args.probe_standard
        status, detail = diagnose(raw, expected)
        print(f"[INFO] Raw dump: {path}")
        print(f"[INFO] Raw SHA-256: {hashlib.sha256(raw).hexdigest()}")
        if status == "clean":
            print("[PASS] " + detail)
            print("[PASS] 3026 application bytes and 1070 erased tail bytes")
            print("[PASS] No post-extraction bit correction required")
            return 0
        if status == "shifted":
            print("[SHIFTED] " + detail)
            print("[BLOCK] Reader shift remains; raw dump is not an unmodified verification PASS")
            print("[NOTE] No file was modified; investigate OpenFPGALoader/Tigard JTAG-SPI alignment")
            return 2
        print("[FAIL] " + detail)
        return 1
    except (OSError, ValueError) as exc:
        print("[FAIL] " + str(exc))
        return 1


if __name__ == "__main__":
    sys.exit(main())
