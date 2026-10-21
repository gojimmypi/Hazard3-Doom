#!/usr/bin/env python3
"""Read-only USB GET_DESCRIPTOR EP0 stress test for ULX5M-GS SERV."""
import argparse
import sys
import time
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runs", type=int, default=5)
    parser.add_argument("--rounds", type=int, default=128)
    parser.add_argument("--delay-ms", type=float, default=100)
    args = parser.parse_args()
    if args.runs <= 0 or args.rounds <= 0 or args.delay_ms < 0:
        parser.error("runs and rounds must be positive; delay-ms must be nonnegative")

    try:
        import usb.core
        import usb.backend.libusb1
    except ImportError as exc:
        parser.error("PyUSB missing: " + str(exc))

    dll = Path(__file__).resolve().parents[2] / "bin" / "libusb-1.0.dll"
    if sys.platform == "win32" and not dll.is_file():
        parser.error("Windows libusb DLL not found: " + str(dll))
    backend = usb.backend.libusb1.get_backend(
        find_library=(lambda _name: str(dll)) if sys.platform == "win32" else None
    )
    if backend is None:
        parser.error("libusb-1.0 backend not found")
    dev = usb.core.find(idVendor=0x1D50, idProduct=0x614B, backend=backend)
    if dev is None:
        parser.error("ULX5M not found (1D50:614B)")

    total_fail = 0
    for run in range(1, args.runs + 1):
        counts = {8: [0, 0], 16: [0, 0], 18: [0, 0]}
        for round_no in range(1, args.rounds + 1):
            for length in (18, 8, 16):
                try:
                    data = bytes(dev.ctrl_transfer(
                        0x80, 0x06, 0x0100, 0, length, timeout=5000
                    ))
                    if len(data) != length or data[:2] != b"\x12\x01":
                        raise RuntimeError("Invalid device descriptor: " + data.hex())
                    counts[length][0] += 1
                except Exception as exc:
                    counts[length][1] += 1
                    total_fail += 1
                    print("[FAIL] run={} round={} length={}: {}".format(
                        run, round_no, length, exc), flush=True)
                    time.sleep(1)
                time.sleep(args.delay_ms / 1000)
        print("[RUN {}] ".format(run) + " ".join(
            "{}B={}/{}".format(length, counts[length][0], args.rounds)
            for length in (8, 16, 18)
        ), flush=True)
        time.sleep(1)
    print("[{}] {} runs, {} rounds, {} failures".format(
        "PASS" if not total_fail else "FAIL", args.runs, args.rounds, total_fail
    ))
    return int(total_fail != 0)


if __name__ == "__main__":
    sys.exit(main())
