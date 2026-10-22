#!/usr/bin/env python3
"""Windows-only ULX5M SERV discard-only DFU streaming diagnostic.

Firmware receives up to 2 MiB of ordered 64-byte DNLOAD blocks, counts and
CRC32-checks each block, and discards them. This is NOT flash programming.
No zero-length manifestation request is sent; ABORT clears the state.
"""
import argparse
import sys
import time
import zlib
from pathlib import Path

VID, PID = 0x1d50, 0x614b
INFO_REQ = 0x59
INFO_LEN = 20
MAX_BYTES = 0x200000
BLOCK_BYTES = 64
DFU_IDLE = 2
DFU_SYNC = 3
DFU_DOWNLOAD_IDLE = 5
DFU_ERROR = 10


def parse_info(raw):
    raw = bytes(raw)
    if len(raw) != INFO_LEN or raw[:4] != b"STR1":
        raise ValueError("STR1 streaming firmware not detected")
    used = int.from_bytes(raw[4:8], "little")
    crc = int.from_bytes(raw[8:12], "little")
    block = int.from_bytes(raw[12:14], "little")
    state, status = raw[14:16]
    capacity = int.from_bytes(raw[16:20], "little")
    if capacity != MAX_BYTES or used > capacity or block > capacity // BLOCK_BYTES:
        raise ValueError("Unexpected STR1 capacity or invalid counters")
    return used, crc, block, state, status, capacity


def read_info(dev, timeout_ms):
    return parse_info(dev.ctrl_transfer(0xc0, INFO_REQ, 0, 0,
                                        INFO_LEN, timeout=timeout_ms))


def payload_byte(i):
    return ((i * 73 + (i >> 5) * 19) ^ (0xff if (i // 16) % 2 else 0)) & 0xff


def exercise(dev, payload, timeout_ms=2000, sleep=time.sleep, progress=print):
    """Prove end-to-end ordered USB transfer without writing external flash.

    Do not blindly retry DNLOAD after a timeout: the firmware may have
    committed the CRC and block counter before the ACK reached the host.
    """
    if not 1 <= len(payload) <= MAX_BYTES:
        raise ValueError("Payload size must be 1..2097152 bytes")
    empty = (0, 0, 0, DFU_IDLE, 0, MAX_BYTES)
    if read_info(dev, timeout_ms) != empty:
        raise RuntimeError("Streaming receiver is not empty and IDLE")
    count = (len(payload) + BLOCK_BYTES - 1) // BLOCK_BYTES
    error = None
    crc = 0
    try:
        for n in range(count):
            chunk = payload[n * BLOCK_BYTES:(n + 1) * BLOCK_BYTES]
            wrote = dev.ctrl_transfer(0x21, 1, n, 0, chunk, timeout=timeout_ms)
            if wrote != len(chunk):
                raise RuntimeError("Block {}: short USB OUT transfer".format(n))
            crc = zlib.crc32(chunk, crc) & 0xffffffff
            expected = (min(len(payload), (n + 1) * BLOCK_BYTES), crc,
                        n + 1, DFU_SYNC, 0, MAX_BYTES)
            snapshot = None
            for attempt in range(8):
                snapshot = read_info(dev, timeout_ms)
                if snapshot == expected:
                    break
                if attempt < 7:
                    sleep(0.05)
            if snapshot != expected:
                raise RuntimeError("Block {} STR1 mismatch: {} != {}".format(
                    n, snapshot, expected))
            status = bytes(dev.ctrl_transfer(0xa1, 3, 0, 0, 6,
                                             timeout=timeout_ms))
            if len(status) != 6 or status[0] or status[4] != DFU_DOWNLOAD_IDLE:
                raise RuntimeError("Block {} GETSTATUS mismatch: {}".format(
                    n, status.hex()))
            if n == count - 1 or (n + 1) % 256 == 0:
                progress("[STREAM] {}/{} bytes CRC32={:08x}".format(
                    expected[0], len(payload), crc))
        final = (len(payload), crc, count, DFU_DOWNLOAD_IDLE, 0, MAX_BYTES)
        if read_info(dev, timeout_ms) != final:
            raise RuntimeError("Final STR1 report mismatch")
    except BaseException as exc:
        error = exc
        raise
    finally:
        try:
            current = read_info(dev, timeout_ms)
            if current[3] == DFU_ERROR:
                dev.ctrl_transfer(0x21, 4, 0, 0, b"", timeout=timeout_ms)
            elif current != empty:
                dev.ctrl_transfer(0x21, 6, 0, 0, b"", timeout=timeout_ms)
            if read_info(dev, timeout_ms) != empty:
                raise RuntimeError("Streaming receiver did not reset")
        except Exception as exc:
            if error is None:
                raise
            print("[WARN] DFU cleanup failed: {}".format(exc), file=sys.stderr)
    progress("[PASS] {} bytes streamed and discarded; no flash commands".format(
        len(payload)))
    return crc


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--exercise-bytes", type=int, metavar="N",
                       help="Send N deterministic bytes (1..2097152) to volatile DFU")
    group.add_argument("--stream-file", type=Path,
                       help="Send actual file bytes to volatile DFU (DISCARDED)")
    parser.add_argument("--timeout-ms", type=int, default=2000)
    args = parser.parse_args()
    if args.timeout_ms <= 0:
        parser.error("--timeout-ms must be positive")
    if args.exercise_bytes is not None and not 1 <= args.exercise_bytes <= MAX_BYTES:
        parser.error("--exercise-bytes must be in 1..2097152")
    payload = None
    if args.stream_file:
        if not args.stream_file.is_file():
            parser.error("Missing file: {}".format(args.stream_file))
        size = args.stream_file.stat().st_size
        if not 1 <= size <= MAX_BYTES:
            parser.error("File must be 1..2097152 bytes")
        payload = args.stream_file.read_bytes()
    elif args.exercise_bytes is not None:
        payload = bytes(payload_byte(i) for i in range(args.exercise_bytes))
    if sys.platform != "win32":
        parser.error("Use native Windows Python, not WSL")

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
        parser.error("Unable to load libusb backend")
    dev = usb.core.find(idVendor=VID, idProduct=PID, backend=backend)
    if dev is None:
        parser.error("USB device 1D50:614B not found")
    initial = read_info(dev, args.timeout_ms)
    print("[STR1] received={} CRC32={:08x} block={} state={} status={} capacity={}".format(
        *initial))
    if payload is None:
        print("[PASS] Discard-only streaming firmware detected; no OUT attempted")
        return 0
    if initial != (0, 0, 0, DFU_IDLE, 0, MAX_BYTES):
        raise RuntimeError("Receiver must be IDLE before exercise")
    print("[RUN] {} bytes; NO flash programming (payload discarded)".format(
        len(payload)))
    exercise(dev, payload, timeout_ms=args.timeout_ms)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print("[FAIL] {}: {}".format(type(exc).__name__, exc), file=sys.stderr)
        sys.exit(1)
