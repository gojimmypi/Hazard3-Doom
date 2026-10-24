#!/usr/bin/env python3
"""Native Windows ULX5M SERV RAM-only DFU diagnostic.

Default action is read-only STG1 query. --exercise-ram sends one DFU
DNLOAD block. --exercise-blocks sends sequential 64-byte blocks, up to 4096
bytes. Both write volatile RAM only and finish with ABORT; neither sends
zero-length DNLOAD or touches configuration flash.
Do not use dfu-util or a firmware flasher with this staging image.
"""
import argparse
import struct
import sys
import time
import zlib
from pathlib import Path

VID, PID = 0x1D50, 0x614B
STG_INFO_REQ = 0x57
STG_INFO_LEN = 16
FLASH_LAYOUT_REQ = 0x58
FLASH_LAYOUT_LEN = 32
DFU_DNLOAD = 1
DFU_GETSTATUS = 3
DFU_ABORT = 6
DFU_CLRSTATUS = 4
DFU_IDLE = 2
DFU_DNLOAD_SYNC = 3
DFU_DNLOAD_IDLE = 5
DFU_ERROR = 10
STAGE_CAPACITY = 4096
TRANSFER_SIZE = 64


def parse_info(data):
    if len(data) != STG_INFO_LEN or data[:4] != b"STG1":
        raise ValueError("Not a DFU Stage image (expected 16-byte STG1)")
    used, crc, block, state, status = struct.unpack_from("<IIHBB", data, 4)
    return used, crc, block, state, status


def parse_flash_layout(data):
    if len(data) != FLASH_LAYOUT_LEN or data[:4] != b"FLM1":
        raise ValueError("Not an FLM1 flash layout report (32 bytes required)")
    total, erase, page, protected_start, protected_len, writable, flags = \
        struct.unpack_from("<7I", data, 4)
    if (total, erase, page, protected_start, protected_len,
            writable, flags) != (0x400000, 4096, 256, 0, 0x400000, 0, 3):
        raise ValueError("Unexpected flash layout; no writes are permitted")
    return total, erase, page, protected_start, protected_len, writable, flags


def inspect_flash_layout(dev, timeout):
    jedec = bytes(dev.ctrl_transfer(0xc0, 0x51, 0, 0, 3, timeout=timeout))
    layout = bytes(dev.ctrl_transfer(0xc0, FLASH_LAYOUT_REQ, 0, 0,
                                     FLASH_LAYOUT_LEN, timeout=timeout))
    total, erase, page, start, protected, writable, flags = \
        parse_flash_layout(layout)
    print("[FLASH] JEDEC={} total={} erase={} page={}".format(
        jedec.hex(" "), total, erase, page))
    print("[POLICY] protected=0x{:06x}..0x{:06x} writable_regions={} flags=0x{:08x}".format(
        start, start + protected - 1, writable, flags))
    if jedec != bytes((0x1f, 0x42, 0x16)):
        raise RuntimeError("Unexpected flash JEDEC ID; policy not validated for this chip")
    print("[PASS] FLM1 read-only report; all flash writes disabled in firmware")


def read_info(dev, timeout):
    data = bytes(dev.ctrl_transfer(0xC0, STG_INFO_REQ, 0, 0,
                                   STG_INFO_LEN, timeout=timeout))
    return parse_info(data)


def show_info(info, label):
    used, crc, block, state, status = info
    print("[{}] RAM bytes={} CRC32={:08x} next_block={} state={} status={}".format(
        label, used, crc, block, state, status))



def multiblock_payload(start, end):
    """Deterministic varied data; no flash/manifestation image semantics."""
    return bytes((((i * 73 + (i >> 5) * 19) ^
                   (0xff if (i // 16) % 2 else 0)) & 0xff)
                 for i in range(start, end))


def exercise_blocks(dev, timeout, total_bytes, initial=None, sleep=time.sleep):
    """Send bounded contiguous DFU blocks to RAM, validate after each block.

    Never retries a DNLOAD: a lost status acknowledgement could already
    have committed that block. Always attempts ABORT or CLRSTATUS on exit.
    """
    if not 1 <= total_bytes <= STAGE_CAPACITY:
        raise ValueError("RAM byte count must be in 1..4096")
    if initial is None:
        initial = read_info(dev, timeout)
    if initial != (0, 0, 0, DFU_IDLE, 0):
        raise RuntimeError("Stage must be empty and IDLE; no OUT sent")

    count = (total_bytes + TRANSFER_SIZE - 1) // TRANSFER_SIZE
    print("[RUN] RAM-only sequential DFU: {} bytes in {} blocks".format(
        total_bytes, count))
    prior_error = None
    try:
        crc = 0
        offset = 0
        for block in range(count):
            end = min(total_bytes, offset + TRANSFER_SIZE)
            payload = multiblock_payload(offset, end)
            transferred = dev.ctrl_transfer(0x21, DFU_DNLOAD, block, 0,
                                           payload, timeout=timeout)
            if transferred != len(payload):
                raise RuntimeError("Block {}: transferred {} instead of {}".format(
                    block, transferred, len(payload)))
            crc = zlib.crc32(payload, crc) & 0xffffffff

            # The status-IN ACK completes the staging callback. Do not
            # repeat DNLOAD while waiting for firmware to process it.
            info = None
            for attempt in range(8):
                info = read_info(dev, timeout)
                if info[0] == end:
                    break
                if attempt < 7:
                    sleep(0.05)
            expected = (end, crc, block + 1, DFU_DNLOAD_SYNC, 0)
            if info != expected:
                raise RuntimeError("Block {}: STG1 mismatch: {} != {}".format(
                    block, info, expected))

            status = bytes(dev.ctrl_transfer(0xa1, DFU_GETSTATUS, 0, 0,
                                             6, timeout=timeout))
            if (len(status) != 6 or status[0] != 0 or
                    status[4] != DFU_DNLOAD_IDLE):
                raise RuntimeError("Block {}: GETSTATUS {}".format(
                    block, status.hex()))
            if block == count - 1 or count <= 8 or (block + 1) % 8 == 0:
                print("[BLOCK {:02d}/{:02d}] bytes={} CRC32={:08x}".format(
                    block + 1, count, end, crc))
            offset = end
        final = read_info(dev, timeout)
        expected_final = (total_bytes, crc, count, DFU_DNLOAD_IDLE, 0)
        show_info(final, "FINAL")
        if final != expected_final:
            raise RuntimeError("Final STG1 mismatch: {} != {}".format(
                final, expected_final))
    except BaseException as exc:
        prior_error = exc
        raise
    finally:
        try:
            state = read_info(dev, timeout)
            if state[3] == DFU_ERROR:
                print("[CLEANUP] DFU ERROR: CLRSTATUS (no flash access)")
                dev.ctrl_transfer(0x21, DFU_CLRSTATUS, 0, 0, b"",
                                  timeout=timeout)
            elif state != (0, 0, 0, DFU_IDLE, 0):
                dev.ctrl_transfer(0x21, DFU_ABORT, 0, 0, b"",
                                  timeout=timeout)
            cleared = read_info(dev, timeout)
            show_info(cleared, "AFTER CLEANUP")
            if cleared != (0, 0, 0, DFU_IDLE, 0):
                raise RuntimeError("RAM stage was not reset")
        except Exception as exc:
            if prior_error is None:
                raise
            print("[WARN] RAM cleanup failed: {}".format(exc), file=sys.stderr)
    print("[PASS] {} bytes, {} blocks, running CRC32 and ABORT (RAM-only)".format(
        total_bytes, count))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--exercise-ram", action="store_true",
                       help="Send one 9-byte DFU DNLOAD block to RAM, then ABORT")
    modes.add_argument("--exercise-blocks", action="store_true",
                       help="Send multiple DFU blocks to RAM, verify CRC32, then ABORT")
    modes.add_argument("--flash-layout", action="store_true",
                       help="Read-only JEDEC and FLM1 layout report (no RAM/flash writes)")
    parser.add_argument("--bytes", type=int, default=192,
                        help="RAM payload size with --exercise-blocks (1..4096; default 192)")
    parser.add_argument("--timeout-ms", type=int, default=2000)
    args = parser.parse_args()
    if args.timeout_ms <= 0:
        parser.error("--timeout-ms must be positive")
    if not 1 <= args.bytes <= STAGE_CAPACITY:
        parser.error("--bytes must be 1..4096")
    if not args.exercise_blocks and args.bytes != 192:
        parser.error("--bytes is only valid with --exercise-blocks")

    if sys.platform != "win32":
        parser.error("Run from native Windows Python, not from WSL")
    try:
        import usb.backend.libusb1
        import usb.core
    except ImportError as exc:
        parser.error("Native Windows PyUSB required: " + str(exc))

    dll = Path(__file__).resolve().parents[2] / "bin" / "libusb-1.0.dll"
    if not dll.is_file():
        parser.error("Missing libusb DLL: " + str(dll))
    backend = usb.backend.libusb1.get_backend(find_library=lambda _: str(dll))
    if backend is None:
        parser.error("Unable to load Windows libusb backend")
    dev = usb.core.find(idVendor=VID, idProduct=PID, backend=backend)
    if dev is None:
        parser.error("USB device 1D50:614B not found")

    try:
        initial = read_info(dev, args.timeout_ms)
    except Exception as exc:
        print("[ERROR] STG1 not available; this may be the read-only probe firmware.")
        print("        No DFU OUT requests were sent. Detail: {}".format(exc))
        return 2
    show_info(initial, "INITIAL")
    if args.flash_layout:
        inspect_flash_layout(dev, args.timeout_ms)
        return 0
    if not (args.exercise_ram or args.exercise_blocks):
        print("[PASS] RAM staging firmware detected (read-only query only)")
        return 0

    if initial != (0, 0, 0, DFU_IDLE, 0):
        print("[ERROR] Stage must be empty and IDLE before test; no OUT sent")
        return 2
    if args.exercise_blocks:
        exercise_blocks(dev, args.timeout_ms, args.bytes, initial=initial)
        return 0
    payload = b"ULX5M-RAM"
    expected_crc = zlib.crc32(payload) & 0xffffffff
    print("[RUN] Sending {} DNLOAD bytes to volatile RAM only".format(len(payload)))
    transferred = dev.ctrl_transfer(0x21, DFU_DNLOAD, 0, 0,
                                    payload, timeout=args.timeout_ms)
    if transferred != len(payload):
        raise RuntimeError("DNLOAD returned unexpected count {}".format(transferred))

    # The status-IN ACK completes the firmware callback. Poll to permit
    # firmware to service the next control request; never retry DNLOAD.
    info = None
    for _ in range(8):
        info = read_info(dev, args.timeout_ms)
        if info[0] == len(payload):
            break
        time.sleep(0.05)
    show_info(info, "AFTER DNLOAD")
    if info[:3] != (len(payload), expected_crc, 1):
        raise RuntimeError("RAM stage length/CRC32/block mismatch")

    status = bytes(dev.ctrl_transfer(0xA1, DFU_GETSTATUS, 0, 0,
                                     6, timeout=args.timeout_ms))
    if len(status) != 6 or status[0] != 0 or status[4] != DFU_DNLOAD_IDLE:
        raise RuntimeError("Unexpected DFU GETSTATUS: " + status.hex())

    dev.ctrl_transfer(0x21, DFU_ABORT, 0, 0, b"", timeout=args.timeout_ms)
    cleared = read_info(dev, args.timeout_ms)
    show_info(cleared, "AFTER ABORT")
    if cleared != (0, 0, 0, DFU_IDLE, 0):
        raise RuntimeError("RAM staging not cleared by ABORT")
    print("[PASS] Hardware DFU DNLOAD/GETSTATUS/STG1 CRC32/ABORT (RAM-only)")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print("[FAIL] {}: {}".format(type(exc).__name__, exc), file=sys.stderr)
        sys.exit(1)
