#!/usr/bin/env python3
"""Pin and render a known walking-LED configuration as read-only ROM bytes.

Output is a hex initialization file for a separate SRAM/JTAG-only probe.
This program never accesses FPGA, JTAG, USB or SPI flash.
"""
import argparse
import hashlib
from pathlib import Path
import sys

KNOWN_SHA256 = "68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd"
KNOWN_BYTES = 3026
SYNC = bytes.fromhex("d901ed96")


def prepare(source: Path, destination: Path) -> str:
    data = source.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    if digest != KNOWN_SHA256 or len(data) != KNOWN_BYTES or not data.startswith(SYNC):
        raise ValueError("not the exact independently tested 3026-byte LED fixture")
    result = "".join(f"{byte:02x}\n" for byte in data)
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        if destination.read_text(encoding="ascii") != result:
            raise ValueError("existing ROM output differs; will not overwrite")
    else:
        with destination.open("x", encoding="ascii", newline="\n") as out:
            out.write(result)
    return digest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", required=True, type=Path)
    parser.add_argument("--rom", required=True, type=Path)
    args = parser.parse_args()
    try:
        digest = prepare(args.image, args.rom)
        print("[PASS] Exact 3026-byte walking-LED ROM SHA-256=" + digest)
        print("[BLOCK] No hardware programming or flash operation")
    except (OSError, UnicodeError, ValueError) as exc:
        print("[FAIL] " + str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
