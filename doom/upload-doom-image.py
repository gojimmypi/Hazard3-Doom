#!/usr/bin/env python3
import argparse
import pathlib
import struct
import sys
import time

IMAGE_MAGIC = 0x31443348
HEADER_BYTES = 64
READY_MARKER = b"H3L READY\r\n"
DATA_MARKER = b"H3L DATA\r\n"
OK_MARKER = b"H3L OK"
ERROR_MARKER = b"H3L ERROR"

def import_serial():
    try: import serial
    except ImportError as error:
        raise RuntimeError("pyserial required: python -m pip install pyserial") from error
    return serial

def read_until_any(port, markers: tuple[bytes, ...], timeout_seconds: float) -> bytes:
    deadline = time.monotonic() + timeout_seconds
    received = bytearray()
    while time.monotonic() < deadline:
        chunk = port.read(256)
        if chunk:
            received.extend(chunk)
            if any(marker in received for marker in markers): return bytes(received)
        else: time.sleep(0.01)
    raise TimeoutError("timed out waiting for loader response")

def validate_package(package: bytes) -> tuple[int, int]:
    if len(package) < HEADER_BYTES: raise RuntimeError("package shorter than header")
    words = struct.unpack("<16I", package[:HEADER_BYTES])
    if words[0] != IMAGE_MAGIC: raise RuntimeError("bad package magic")
    if words[1] != HEADER_BYTES: raise RuntimeError("unsupported header size")
    if len(package) != HEADER_BYTES + words[5]: raise RuntimeError("package length mismatch")
    return words[5], words[9]

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("image", type=pathlib.Path)
    parser.add_argument("--port", required=True)
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--chunk-size", type=int, default=4096)
    parser.add_argument("--launch", action="store_true")
    parser.add_argument("--launch-read-seconds", type=float, default=15.0)
    args = parser.parse_args()
    if args.chunk_size <= 0: raise RuntimeError("chunk size must be positive")
    package = args.image.read_bytes()
    image_bytes, crc = validate_package(package)
    serial = import_serial()
    print(f"Opening {args.port} at {args.baud}; payload={image_bytes}, CRC32=0x{crc:08x}")
    with serial.Serial(args.port, args.baud, timeout=0.1, write_timeout=10.0) as port:
        port.reset_input_buffer(); port.reset_output_buffer(); port.write(b"l"); port.flush()
        text = read_until_any(port, (READY_MARKER,), 10.0)
        sys.stdout.write(text.decode("ascii", errors="replace")); sys.stdout.flush()
        start = time.monotonic()

        # Send the package header by itself.  The monitor validates it and
        # prints its summary before announcing that it is ready for payload
        # bytes.  Without this handshake, the monitor's two-byte RX FIFO can
        # overflow while it is transmitting the summary.
        port.write(package[:HEADER_BYTES]); port.flush()
        response = read_until_any(port, (DATA_MARKER, ERROR_MARKER), 10.0)
        sys.stdout.write(response.decode("ascii", errors="replace")); sys.stdout.flush()
        if ERROR_MARKER in response: return 1

        payload = package[HEADER_BYTES:]
        sent = 0
        while sent < len(payload):
            end = min(sent + args.chunk_size, len(payload))
            port.write(payload[sent:end]); sent = end
            print(f"\rUploading payload: {sent}/{len(payload)} ({sent*100.0/len(payload):5.1f}%)", end="")
            sys.stdout.flush()
        port.flush(); print()
        wire_seconds = (HEADER_BYTES + len(payload)) * 10.0 / args.baud
        response = read_until_any(port, (OK_MARKER, ERROR_MARKER), max(20.0, wire_seconds+20.0))
        sys.stdout.write(response.decode("ascii", errors="replace")); sys.stdout.flush()
        if ERROR_MARKER in response: return 1
        print(f"Upload accepted in {time.monotonic()-start:.1f} seconds")
        if args.launch:
            port.write(b"j"); port.flush(); deadline = time.monotonic()+args.launch_read_seconds
            while time.monotonic() < deadline:
                chunk = port.read(512)
                if chunk: sys.stdout.write(chunk.decode("ascii", errors="replace")); sys.stdout.flush()
                else: time.sleep(0.01)
    return 0

if __name__ == "__main__":
    try: raise SystemExit(main())
    except (OSError, RuntimeError, TimeoutError) as error:
        print(f"error: {error}", file=sys.stderr); raise SystemExit(1)
