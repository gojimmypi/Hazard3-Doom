#!/usr/bin/env python3
"""Read ULX5M-GS configuration flash via the volatile read-only USB probe.

Requires PyUSB and a Windows libusb-compatible driver already bound to the
FPGA device. Does not change drivers, erase flash, or send USB OUT requests.
"""
import argparse

VID, PID = 0x1d50, 0x614b
CHUNK = 32
FLASH_SIZE = 4 * 1024 * 1024


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--offset", type=lambda v: int(v, 0), default=0)
    parser.add_argument("--length", type=lambda v: int(v, 0), default=32)
    parser.add_argument("--output", help="save read-only data to this file")
    args = parser.parse_args()

    if args.offset < 0 or args.length < 0 or args.offset > FLASH_SIZE or \
            args.length > FLASH_SIZE - args.offset:
        parser.error("offset and length must lie within 0..0x3fffff")
    try:
        import usb.core
    except ImportError:
        parser.error("install PyUSB in the Windows Python used for this script")

    dev = usb.core.find(idVendor=VID, idProduct=PID)
    if dev is None:
        parser.error("ULX5M not found (1d50:614b). Check USB and driver")

    jedec = bytes(dev.ctrl_transfer(0xc0, 0x51, 0, 0, 3, timeout=5000))
    if len(jedec) != 3:
        raise RuntimeError("unexpected JEDEC response length")
    print("JEDEC RDID:", jedec.hex(" "))
    if jedec in (b"\x00" * 3, b"\xff" * 3):
        print("WARNING: invalid or disconnected flash response")

    contents = bytearray()
    for ofs in range(args.offset, args.offset + args.length, CHUNK):
        count = min(CHUNK, args.offset + args.length - ofs)
        data = bytes(dev.ctrl_transfer(
            0xc0, 0x52, ofs & 0xffff, ofs >> 16, count, timeout=5000))
        if len(data) != count:
            raise RuntimeError("short flash read at 0x%06x" % ofs)
        contents.extend(data)
    if args.output:
        with open(args.output, "wb") as f:
            f.write(contents)
        print("Wrote", len(contents), "bytes to", args.output)
    else:
        for i in range(0, len(contents), 16):
            print("%06x: %s" % (args.offset + i, contents[i:i + 16].hex(" ")))


if __name__ == "__main__":
    main()
