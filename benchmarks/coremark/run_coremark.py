#!/usr/bin/env python3
import argparse
import re
import subprocess
import sys
import time
from pathlib import Path

try:
    import serial
except ImportError as exc:
    raise SystemExit("pyserial is required: python3 -m pip install pyserial") from exc

TICKS_RE = re.compile(r"^Total ticks\s*:\s*(\d+)\s*$")
ITERATIONS_RE = re.compile(r"^Iterations\s*:\s*(\d+)\s*$")


def parse_args():
    parser = argparse.ArgumentParser(description="Load and capture Hazard3 ULX3S CoreMark")
    parser.add_argument("--elf", required=True, type=Path)
    parser.add_argument("--port", required=True)
    parser.add_argument("--loader", required=True, type=Path)
    parser.add_argument("--clock-hz", type=int, default=50_000_000)
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--timeout", type=float, default=120.0)
    return parser.parse_args()


def main():
    args = parse_args()
    if not args.elf.is_file():
        raise SystemExit(f"CoreMark ELF not found: {args.elf}")
    if not args.loader.is_file():
        raise SystemExit(f"Loader not found: {args.loader}")

    ticks = None
    iterations = None
    validated = False
    saw_error = False
    deadline = time.monotonic() + args.timeout

    with serial.Serial(args.port, args.baud, timeout=0.25) as ser:
        ser.reset_input_buffer()
        subprocess.run([str(args.loader), str(args.elf)], check=True)

        while time.monotonic() < deadline:
            raw = ser.readline()
            if not raw:
                continue
            line = raw.decode("ascii", errors="replace").rstrip("\r\n")
            print(line, flush=True)

            match = TICKS_RE.match(line)
            if match:
                ticks = int(match.group(1))
            match = ITERATIONS_RE.match(line)
            if match:
                iterations = int(match.group(1))
            if "Correct operation validated." in line:
                validated = True
            if "ERROR!" in line or "Errors detected" in line:
                saw_error = True
            if line == "COREMARK_DONE":
                break
        else:
            raise SystemExit(f"Timed out after {args.timeout:g} seconds waiting for CoreMark")

    if ticks is None or iterations is None:
        raise SystemExit("CoreMark completed, but Total ticks/Iterations were not captured")
    if ticks == 0:
        raise SystemExit("CoreMark reported zero timing ticks")

    elapsed = ticks / args.clock_hz
    iterations_per_sec = iterations / elapsed
    coremark_per_mhz = iterations_per_sec / (args.clock_hz / 1_000_000.0)

    print()
    print("Hazard3 ULX3S CoreMark summary")
    print(f"  cycles          : {ticks}")
    print(f"  elapsed seconds : {elapsed:.6f}")
    print(f"  CoreMark/s      : {iterations_per_sec:.3f}")
    print(f"  CoreMark/MHz    : {coremark_per_mhz:.4f}")
    print(f"  validation      : {'PASS' if validated and not saw_error else 'FAIL'}")

    return 0 if validated and not saw_error else 1


if __name__ == "__main__":
    sys.exit(main())
