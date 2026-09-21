#!/usr/bin/env python3
# -----------------------------------------------------------------------------
# File:        upload-doom-image.py
# Path:        doom/upload-doom-image.py
#
# Project:     Hazard3-Doom
# Purpose:     Upload a Hazard3-Doom H3IMG executable image over the monitor serial
#              protocol.
#
# Copyright (c) 2026 gojimmypi
#
# Licensed under the Apache License, Version 2.0.
#
# SPDX-License-Identifier: Apache-2.0
#
# This software is provided under the terms of the applicable license.
# See LICENSES/Apache-2.0.txt for the complete license terms.
# See LICENSING.md for project licensing policy and scope.
# -----------------------------------------------------------------------------

import argparse
import pathlib
import struct
import sys
import time
import zlib

IMAGE_MAGIC_BYTES = b"H3I1"
IMAGE_MAGIC = int.from_bytes(IMAGE_MAGIC_BYTES, "little")
HEADER_BYTES = 64
FORMAT_VERSION = 1
FLAG_CRC32 = 1
IMAGE_BASE = 0x20100000
IMAGE_LIMIT = 0x20400000
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

def range_is_valid(address: int, byte_count: int) -> bool:
    if address < IMAGE_BASE or address > IMAGE_LIMIT:
        return False
    return byte_count <= IMAGE_LIMIT - address

def validate_package(package: bytes) -> tuple[int, int]:
    if len(package) < HEADER_BYTES: raise RuntimeError("package shorter than header")
    words = struct.unpack("<16I", package[:HEADER_BYTES])
    if words[0] != IMAGE_MAGIC: raise RuntimeError("bad package magic")
    if words[1] != HEADER_BYTES: raise RuntimeError("unsupported header size")
    if words[2] != FORMAT_VERSION: raise RuntimeError("unsupported format version")
    if words[3] != FLAG_CRC32: raise RuntimeError("unsupported package flags")
    if words[4] != IMAGE_BASE: raise RuntimeError("unexpected load address")
    if words[5] == 0: raise RuntimeError("payload size must be nonzero")
    if not range_is_valid(words[4], words[5]): raise RuntimeError("payload range outside image reservation")
    if not range_is_valid(words[7], words[8]): raise RuntimeError("BSS range outside image reservation")
    load_end = words[4] + words[5]
    bss_end = words[7] + words[8]
    if words[6] < words[4] or words[6] >= load_end: raise RuntimeError("entry address outside payload")
    if words[7] < load_end: raise RuntimeError("BSS overlaps payload")
    if words[7] & 3: raise RuntimeError("BSS address is not 4-byte aligned")
    if bss_end > IMAGE_LIMIT: raise RuntimeError("BSS end outside image reservation")
    if any(words[10:]): raise RuntimeError("reserved header words must be zero")
    if len(package) != HEADER_BYTES + words[5]: raise RuntimeError("package length mismatch")
    payload = package[HEADER_BYTES:]
    actual_crc = zlib.crc32(payload) & 0xffffffff
    if actual_crc != words[9]: raise RuntimeError("payload CRC32 mismatch")
    return words[5], words[9]

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("image", type=pathlib.Path)
    parser.add_argument("--port")
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--chunk-size", type=int, default=4096)
    parser.add_argument("--launch", action="store_true")
    parser.add_argument("--launch-read-seconds", type=float, default=15.0)
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    if args.chunk_size <= 0: raise RuntimeError("chunk size must be positive")
    package = args.image.read_bytes()
    image_bytes, crc = validate_package(package)
    if args.validate_only:
        print(f"Validated {args.image}: payload={image_bytes} bytes, CRC32=0x{crc:08x}")
        return 0
    if args.port is None: parser.error("--port is required unless --validate-only is used")
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
