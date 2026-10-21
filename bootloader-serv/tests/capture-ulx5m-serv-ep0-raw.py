#!/usr/bin/env python3
"""Read the frozen ULX5M SERV EP0 GateMate IDDR capture through vendor EP0.

Run in native Windows PowerShell. USB readback can be intermittent; each page
is retried independently. This is not an external analog or USB wire capture.
"""
import argparse
import csv
import struct
import sys
import time
from pathlib import Path

VID, PID = 0x1D50, 0x614B
REQ_READ, REQ_ARM = 0x55, 0x56
MAGIC = 0x31575255  # URW1
WORDS = 128


def decode_header(data):
    if len(data) != 16:
        raise ValueError("expected 16-byte URW1 header")
    magic, meta, marker, last_result = struct.unpack("<4I", data)
    if magic != MAGIC or (marker & 0xffff) != 0x5257:
        raise ValueError("URW1 trace not present; rebuild v16g RTL/firmware")
    return {
        "count": (meta >> 16) & 0x1ff,
        "status": meta & 0xffff,
        "last_ack_result": last_result & 0xffff,
    }


def decode_samples(pages, count):
    if not 0 <= count <= 256:
        raise ValueError("invalid sample count")
    if len(pages) != 16 or any(len(page) != 16 for page in pages):
        raise ValueError("expected 16 complete 16-byte waveform pages")
    return b"".join(pages)[:count]


def sample_row(i, byte):
    dp = (byte >> 6) & 3
    dn = (byte >> 4) & 3
    return [i, dp & 1, (dp >> 1) & 1, dn & 1, (dn >> 1) & 1,
            (byte >> 3) & 1, (byte >> 2) & 1,
            (byte >> 1) & 1, byte & 1, f"0x{byte:02x}"]


def states(samples):
    out = []
    for byte in samples:
        # CC_IDDR Q0/Q1 phase assignment must be confirmed on GateMate.
        for bit in (0, 1):
            dp = (byte >> (6 + bit)) & 1
            dn = (byte >> (4 + bit)) & 1
            out.append("J" if (dp, dn) == (1, 0) else
                       "K" if (dp, dn) == (0, 1) else
                       "0" if (dp, dn) == (0, 0) else "1")
    return "".join(out)


def selftest():
    fake = bytes([0x91, 0x99] * 128)
    pages = [fake[i * 16:(i + 1) * 16] for i in range(16)]
    assert decode_samples(pages, 3) == fake[:3]
    assert sample_row(0, 0x99)[1:5] == [0, 1, 1, 0]
    hdr = struct.pack("<4I", MAGIC, (193 << 16) | 9, 0x5257, 0x120)
    assert decode_header(hdr)["count"] == 193
    assert len(states(bytes([0x91, 0x99]))) == 4
    for invalid in (bytes(16), bytes(15)):
        try:
            decode_header(invalid)
        except ValueError:
            pass
        else:
            raise AssertionError("bad header accepted")
    print("[PASS] URW1 header, page assembly, IDDR sample decoder")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--arm", action="store_true", help="rearm capture, discard old frozen data")
    parser.add_argument("--dump", action="store_true", help="read frozen data into CSV and raw binary")
    parser.add_argument("--output", default="ulx5m-raw-ack", help="output filename prefix")
    parser.add_argument("--retries", type=int, default=12)
    parser.add_argument("--timeout-ms", type=int, default=2000)
    parser.add_argument("--selftest", action="store_true")
    args = parser.parse_args()
    if args.selftest:
        selftest()
        return
    if not args.arm and not args.dump:
        parser.error("specify --arm or --dump")
    if args.retries < 1 or args.timeout_ms <= 0:
        parser.error("retries and timeout must be positive")
    if sys.platform != "win32":
        parser.error("Run in Windows PowerShell; WSL does not have USB access")

    try:
        import usb.core
        import usb.backend.libusb1
    except ImportError as exc:
        parser.error("PyUSB is required: " + str(exc))
    dll = Path(__file__).resolve().parents[2] / "bin" / "libusb-1.0.dll"
    if not dll.is_file():
        parser.error("Missing Windows libusb DLL: " + str(dll))
    backend = usb.backend.libusb1.get_backend(find_library=lambda _: str(dll))
    dev = usb.core.find(idVendor=VID, idProduct=PID, backend=backend)
    if dev is None:
        parser.error("ULX5M 1d50:614b not found")

    def attempt(label, fn):
        for i in range(args.retries):
            try:
                return fn()
            except Exception as exc:
                print(f"[RETRY] {label} {i + 1}/{args.retries}: {exc}", flush=True)
                time.sleep(0.15)
        raise RuntimeError(f"{label} failed after {args.retries} attempts")

    def read_page(page):
        return bytes(attempt(f"page {page}", lambda: dev.ctrl_transfer(
            0xc0, REQ_READ, page, 0, 16, timeout=args.timeout_ms)))

    if args.arm:
        attempt("arm", lambda: dev.ctrl_transfer(
            0x40, REQ_ARM, 0, 0, b"", timeout=args.timeout_ms))
        print("[ARM] Capture rearmed. Run descriptor stress test before --dump.")
        if not args.dump:
            return
    hdr = decode_header(read_page(0))
    print("[CAPTURE] status=0x{:04x} count={} last_ack_result=0x{:04x}".format(
        hdr["status"], hdr["count"], hdr["last_ack_result"]))
    if not (hdr["status"] & 8):
        print("[INFO] No frozen ACK timeout capture. Do not rearm if still waiting for a failure.")
        return
    pages = [read_page(i) for i in range(1, 17)]
    samples = decode_samples(pages, hdr["count"])
    # Confirm frozen capture did not change during retries.
    hdr2 = decode_header(read_page(0))
    if hdr2["count"] != hdr["count"] or not (hdr2["status"] & 8):
        raise RuntimeError("capture changed during download")
    prefix = Path(args.output)
    prefix.parent.mkdir(parents=True, exist_ok=True)
    binary = prefix.with_suffix(".bin")
    csvfile = prefix.with_suffix(".csv")
    binary.write_bytes(samples)
    with csvfile.open("w", newline="", encoding="ascii") as handle:
        writer = csv.writer(handle)
        writer.writerow(["cycle", "dp_q0", "dp_q1", "dn_q0", "dn_q1",
                         "rx_change", "rx_sync", "tx_oe", "rx_hold", "raw"])
        writer.writerows(sample_row(i, v) for i, v in enumerate(samples))
    print("[CAPTURE] wrote {} samples to {} and {}".format(len(samples), binary, csvfile))
    waveform = states(samples)
    print("[IDDR] two half-cycle symbols per sample, J/K/0(SE0)/1(SE1):")
    for pos in range(0, len(waveform), 80):
        print(f"  {pos:03d}: {waveform[pos:pos + 80]}")
    print("[NOTE] Internal DDR samples are not an independent USB pad capture.")


if __name__ == "__main__":
    main()
