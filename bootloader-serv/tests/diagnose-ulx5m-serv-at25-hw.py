#!/usr/bin/env python3
"""Native Windows read-only AT25QL321 MMIO adapter diagnostic.

Compares new driver 0x5B with the hardware-validated legacy 0x52 request.
No DFU DNLOAD, vendor OUT, flash erase or flash page program is performed.
"""
import argparse
import hashlib
import sys
from pathlib import Path

VID, PID = 0x1d50, 0x614b
STATUS_REQ, NEW_READ_REQ, OLD_READ_REQ = 0x5a, 0x5b, 0x52
FLASH_BYTES = 0x400000
EXPECTED_ID = bytes.fromhex("1f4216")
SAMPLES = (0, 0x30, 0x100, 0xfff, 0x1000, 0x13a080, 0x13a0bf,
           0x13b000, 0x1fffff, 0x200000, 0x3fffdf, 0x3fffff)


def parse_status(raw):
    data = bytes(raw)
    if len(data) != 8 or data[:4] != b"A251":
        raise ValueError("A251 read-only hardware diagnostic not detected")
    if data[4:7] != EXPECTED_ID:
        raise ValueError("Unexpected flash JEDEC: " + data[4:7].hex())
    return data[7]


def read(dev, request, address, count, timeout_ms):
    if not 0 <= address < FLASH_BYTES or not 1 <= count <= 32 or \
            count > FLASH_BYTES - address:
        raise ValueError("Flash read range outside chip or USB limit")
    data = bytes(dev.ctrl_transfer(0xc0, request, address & 0xffff,
                                   address >> 16, count, timeout=timeout_ms))
    if len(data) != count:
        raise RuntimeError("Short read at 0x{:06x}".format(address))
    return data


def compare(dev, timeout_ms=2000, backup=None, report=print):
    raw = dev.ctrl_transfer(0xc0, STATUS_REQ, 0, 0, 8,
                            timeout=timeout_ms)
    sr = parse_status(raw)
    report("[A251] JEDEC=1f 42 16 status1=0x{:02x} WIP={} WEL={}".format(
        sr, sr & 1, (sr >> 1) & 1))
    if sr & 0x03:
        raise RuntimeError("Flash is BUSY or write-enable latch set")
    if backup is not None and len(backup) != FLASH_BYTES:
        raise ValueError("Backup must be exactly 4 MiB")
    for address in SAMPLES:
        n = min(32, FLASH_BYTES - address)
        previous = read(dev, OLD_READ_REQ, address, n, timeout_ms)
        current = read(dev, NEW_READ_REQ, address, n, timeout_ms)
        if previous != current:
            raise RuntimeError("Readback mismatch at 0x{:06x}".format(address))
        if backup is not None and current != backup[address:address + n]:
            raise RuntimeError("Backup mismatch at 0x{:06x}".format(address))
        report("[MATCH] 0x{:06x} ({} bytes)".format(address, n))
    report("[PASS] {} locations: legacy/new hardware SPI reads match; "
           "NO flash writes".format(len(SAMPLES)))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--timeout-ms", type=int, default=2000)
    p.add_argument("--backup", type=Path,
                   help="Optional full 4 MiB verified flash-pass1.bin")
    args = p.parse_args()
    if args.timeout_ms <= 0:
        p.error("--timeout-ms must be positive")
    backup = None
    if args.backup:
        if not args.backup.is_file() or args.backup.stat().st_size != FLASH_BYTES:
            p.error("--backup requires an existing 4 MiB file")
        backup = args.backup.read_bytes()
        print("[BACKUP] SHA-256 " + hashlib.sha256(backup).hexdigest())
    if sys.platform != "win32":
        p.error("Use native Windows Python, not WSL")
    try:
        import usb.backend.libusb1
        import usb.core
    except ImportError as exc:
        p.error("Native Windows PyUSB required: " + str(exc))
    dll = Path(__file__).resolve().parents[2] / "bin" / "libusb-1.0.dll"
    if not dll.is_file():
        p.error("Missing libusb DLL: " + str(dll))
    backend = usb.backend.libusb1.get_backend(find_library=lambda _: str(dll))
    if backend is None:
        p.error("Unable to load libusb backend")
    dev = usb.core.find(idVendor=VID, idProduct=PID, backend=backend)
    if dev is None:
        p.error("USB device 1D50:614B not found")
    compare(dev, args.timeout_ms, backup)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print("[FAIL] {}: {}".format(type(exc).__name__, exc), file=sys.stderr)
        sys.exit(1)
