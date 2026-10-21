#!/usr/bin/env python3
"""Windows-only, descriptor-only ULX5M SERV USB link A/B test.

The run deliberately sends no vendor diagnostics, USB resets, DFU operations,
or flash writes. Compare runs after changing only cable/port/hub configuration.
"""

import argparse
import csv
import datetime
import sys
import time
from pathlib import Path

VID, PID = 0x1D50, 0x614B
REQ_GET_DESCRIPTOR = 0x06
DEVICE_DESCRIPTOR = 0x0100


def lengths_arg(value):
    try:
        values = [int(item.strip(), 10) for item in value.split(",")]
    except ValueError as exc:
        raise argparse.ArgumentTypeError("lengths must be comma-separated decimal integers") from exc
    if not values or any(v < 2 or v > 18 for v in values):
        raise argparse.ArgumentTypeError("lengths must contain integers from 2 through 18")
    return values


def run_trial(device, lengths, rounds, delay_ms, timeout_ms, sleep=time.sleep,
              timer=time.perf_counter):
    """Stop at first failure; return request-level data without changing device state."""
    rows = []
    completed = 0
    for round_no in range(1, rounds + 1):
        for length in lengths:
            start = timer()
            error = ""
            received = 0
            try:
                data = bytes(device.ctrl_transfer(0x80, REQ_GET_DESCRIPTOR,
                                                  DEVICE_DESCRIPTOR, 0, length,
                                                  timeout=timeout_ms))
                received = len(data)
                if received != length or data[:2] != b"\x12\x01":
                    raise RuntimeError("unexpected descriptor: " + data.hex())
                completed += 1
            except Exception as exc:
                error = str(exc).encode("ascii", "backslashreplace").decode("ascii")
            elapsed_ms = (timer() - start) * 1000.0
            rows.append({"round": round_no, "requested": length, "received": received,
                         "elapsed_ms": round(elapsed_ms, 3),
                         "result": "FAIL" if error else "PASS", "error": error})
            if error:
                return completed, rows
            if delay_ms:
                sleep(delay_ms / 1000.0)
    return completed, rows


def selftest():
    class Dummy:
        def __init__(self, fail_at=0):
            self.n = 0
            self.fail_at = fail_at
        def ctrl_transfer(self, typ, req, val, index, length, timeout):
            assert (typ, req, val, index, timeout) == (0x80, 6, 0x100, 0, 3000)
            self.n += 1
            if self.n == self.fail_at:
                raise OSError("Pipe error")
            return bytes([18, 1] + [0] * (length - 2))

    n, rows = run_trial(Dummy(), [18, 8, 16], 2, 0, 3000)
    assert n == 6 and len(rows) == 6 and all(r["result"] == "PASS" for r in rows)
    n, rows = run_trial(Dummy(4), [18, 8, 16], 8, 0, 3000)
    assert n == 3 and len(rows) == 4 and rows[-1]["result"] == "FAIL"
    assert (rows[-1]["round"], rows[-1]["requested"]) == (2, 18)
    assert lengths_arg("18,8,16") == [18, 8, 16]
    print("[PASS] descriptor-only A/B experiment selftest")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", required=False, default="untagged",
                        help="Cable/port label, e.g. direct-usb2 or dock-usb3")
    parser.add_argument("--lengths", type=lengths_arg, default=[18, 8, 16],
                        help="Comma-separated requested descriptor lengths (default 18,8,16)")
    parser.add_argument("--rounds", type=int, default=256)
    parser.add_argument("--delay-ms", type=float, default=100)
    parser.add_argument("--timeout-ms", type=int, default=3000)
    parser.add_argument("--output", type=Path, help="Explicit CSV output file")
    parser.add_argument("--selftest", action="store_true")
    args = parser.parse_args()

    if args.selftest:
        selftest()
        return 0
    if args.rounds < 1 or args.delay_ms < 0 or args.timeout_ms <= 0:
        parser.error("rounds must be >=1, delay >=0, and timeout >0")
    if sys.platform != "win32":
        parser.error("Run hardware tests in native Windows PowerShell, not WSL")

    try:
        import usb.core
        import usb.backend.libusb1
    except ImportError as exc:
        parser.error("PyUSB is required: " + str(exc))

    dll = Path(__file__).resolve().parents[2] / "bin" / "libusb-1.0.dll"
    if not dll.is_file():
        parser.error("Expected libusb DLL: " + str(dll))
    backend = usb.backend.libusb1.get_backend(find_library=lambda _: str(dll))
    if backend is None:
        parser.error("Could not load libusb backend")
    dev = usb.core.find(idVendor=VID, idProduct=PID, backend=backend)
    if dev is None:
        parser.error("ULX5M 1d50:614b not found; check USB connection")

    timestamp = datetime.datetime.now().strftime("%Y%m%dT%H%M%S")
    filename = args.output or Path("ulx5m-usb-{}-{}.csv".format(
        "".join(c if c.isalnum() or c in "-_" else "_" for c in args.tag), timestamp))
    filename.parent.mkdir(parents=True, exist_ok=True)
    print("[RUN] tag={} lengths={} rounds={} delay_ms={} file={}".format(
        args.tag, ",".join(map(str, args.lengths)), args.rounds, args.delay_ms, filename),
        flush=True)

    completed, rows = run_trial(dev, args.lengths, args.rounds,
                                args.delay_ms, args.timeout_ms)
    with filename.open("w", newline="", encoding="ascii") as f:
        writer = csv.DictWriter(f, fieldnames=["round", "requested", "received",
                                                  "elapsed_ms", "result", "error"])
        writer.writeheader()
        writer.writerows(rows)

    total = len(rows)
    failed = total > completed
    print("[{}] completed={} attempted={} first_failure={} tag={} csv={}".format(
        "FAIL" if failed else "PASS", completed, total,
        "round={} length={}: {}".format(rows[-1]["round"], rows[-1]["requested"],
                                         rows[-1]["error"]) if failed else "none",
        args.tag, filename))
    print("[NOTE] This checks host-visible control requests, not on-wire ACKs.")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
