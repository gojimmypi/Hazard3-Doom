#!/usr/bin/env python3
"""Read ULX5M-GS configuration flash via the volatile read-only USB probe.

Requires PyUSB and a Windows libusb-compatible driver already bound to the
FPGA device. Does not change drivers, erase flash, or send USB OUT requests.
"""
import argparse
import sys
from pathlib import Path

VID, PID = 0x1d50, 0x614b
CHUNK = 32
FLASH_SIZE = 4 * 1024 * 1024


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--offset", type=lambda v: int(v, 0), default=0)
    parser.add_argument("--length", type=lambda v: int(v, 0), default=32)
    parser.add_argument("--output", help="save read-only data to this file")
    parser.add_argument("--chunk-size", type=int, default=CHUNK,
                        help="bytes per USB request (1..32, default: 32)")
    parser.add_argument("--delay-ms", type=int, default=0,
                        help="pause between USB read requests (default: 0)")
    parser.add_argument("--progress", action="store_true",
                        help="print each completed USB read request")
    args = parser.parse_args()
    if not 1 <= args.chunk_size <= CHUNK:
        parser.error("--chunk-size must be 1..32")
    if args.delay_ms < 0:
        parser.error("--delay-ms must not be negative")

    if args.offset < 0 or args.length < 0 or args.offset > FLASH_SIZE or \
            args.length > FLASH_SIZE - args.offset:
        parser.error("offset and length must lie within 0..0x3fffff")
    try:
        import usb.core
    except ImportError:
        parser.error("install PyUSB in the Windows Python used for this script")

    # Windows Python may not discover libusb-1.0.dll in the repository bin/.
    # Prefer that known working DLL with the existing WinUSB device driver.
    backend = None
    if sys.platform == "win32":
        import usb.backend.libusb1
        dll = Path(__file__).resolve().parents[2] / "bin" / "libusb-1.0.dll"
        if dll.is_file():
            backend = usb.backend.libusb1.get_backend(
                find_library=lambda _name: str(dll))
            if backend is None:
                parser.error("unable to load %s (check DLL architecture)" % dll)

    dev = usb.core.find(idVendor=VID, idProduct=PID, backend=backend)
    if dev is None:
        parser.error("ULX5M not found (1d50:614b). Check USB and driver")

    jedec = bytes(dev.ctrl_transfer(0xc0, 0x51, 0, 0, 3, timeout=5000))
    if len(jedec) != 3:
        raise RuntimeError("unexpected JEDEC response length")
    print("JEDEC RDID:", jedec.hex(" "))
    if jedec in (b"\x00" * 3, b"\xff" * 3):
        print("WARNING: invalid or disconnected flash response")

    contents = bytearray()
    for ofs in range(args.offset, args.offset + args.length, args.chunk_size):
        count = min(args.chunk_size, args.offset + args.length - ofs)
        request_num = len(contents) // args.chunk_size + 1
        try:
            data = bytes(dev.ctrl_transfer(
                0xc0, 0x52, ofs & 0xffff, ofs >> 16, count, timeout=5000))
        except usb.core.USBError as exc:
            parser.exit(1, "[FAIL] flash read at 0x%06x (%d bytes, request %d, "
                        "%d bytes completed): %s\n" %
                        (ofs, count, request_num, len(contents), exc))
        if len(data) != count:
            parser.exit(1, "[FAIL] short flash read at 0x%06x "
                        "(request %d, expected %d, got %d)\n" %
                        (ofs, request_num, count, len(data)))
        contents.extend(data)
        if args.progress:
            print("[OK] request %d offset=0x%06x count=%d" %
                  (request_num, ofs, count), flush=True)
        if args.delay_ms and len(contents) < args.length:
            import time
            time.sleep(args.delay_ms / 1000.0)
    if args.output:
        with open(args.output, "wb") as f:
            f.write(contents)
        print("Wrote", len(contents), "bytes to", args.output)
    else:
        for i in range(0, len(contents), 16):
            print("%06x: %s" % (args.offset + i, contents[i:i + 16].hex(" ")))


if __name__ == "__main__":
    main()
