#!/usr/bin/env python3
import argparse
import sys
import time

import serial


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Capture the Hazard3 software verifier UART result."
    )
    parser.add_argument("--port", required=True)
    parser.add_argument("--timeout", type=float, default=120.0)
    args = parser.parse_args()

    deadline = time.monotonic() + args.timeout
    buffer = bytearray()

    with serial.Serial(args.port, 115200, timeout=0.1) as port:
        port.reset_input_buffer()
        while time.monotonic() < deadline:
            data = port.read(4096)
            if not data:
                continue

            sys.stdout.buffer.write(data)
            sys.stdout.buffer.flush()
            buffer.extend(data)
            if len(buffer) > 8192:
                del buffer[:-8192]

            if b"VERIFY RESULT: PASS" in buffer:
                return 0
            if b"VERIFY RESULT: FAIL" in buffer:
                return 1

    print("\nERROR: verifier UART result timed out", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
