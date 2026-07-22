#!/usr/bin/env python3
import argparse
import pathlib
import struct
import subprocess
import sys
import zlib

IMAGE_MAGIC = 0x31443348
FORMAT_VERSION = 1
HEADER_BYTES = 64
FLAG_CRC32 = 1
IMAGE_BASE = 0x20100000
IMAGE_LIMIT = 0x20400000

def read_symbols(nm_path: str, elf_path: pathlib.Path) -> dict[str, int]:
    output = subprocess.check_output([nm_path, "-n", str(elf_path)], text=True)
    symbols: dict[str, int] = {}
    for line in output.splitlines():
        fields = line.split()
        if len(fields) >= 3:
            try: value = int(fields[0], 16)
            except ValueError: continue
            symbols[fields[2]] = value
    return symbols

def require_symbol(symbols: dict[str, int], name: str) -> int:
    if name not in symbols: raise RuntimeError(f"missing linker symbol: {name}")
    return symbols[name]

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--elf", required=True, type=pathlib.Path)
    parser.add_argument("--binary", required=True, type=pathlib.Path)
    parser.add_argument("--output", required=True, type=pathlib.Path)
    parser.add_argument("--nm", required=True)
    args = parser.parse_args()
    symbols = read_symbols(args.nm, args.elf)
    entry = require_symbol(symbols, "_doom_start")
    load_end = require_symbol(symbols, "__doom_image_load_end")
    bss = require_symbol(symbols, "__doom_bss_start")
    bss_end = require_symbol(symbols, "__doom_bss_end")
    image_end = require_symbol(symbols, "__doom_image_end")
    payload = args.binary.read_bytes()
    expected = load_end - IMAGE_BASE
    if not (IMAGE_BASE <= entry < load_end):
        raise RuntimeError("entry is outside payload")
    if bss != load_end:
        raise RuntimeError(
            f"BSS start 0x{bss:08x} != aligned payload end 0x{load_end:08x}")
    if len(payload) > expected:
        raise RuntimeError(
            f"binary length {len(payload)} exceeds expected payload length {expected}")
    if len(payload) < expected:
        padding = expected - len(payload)
        payload += bytes(padding)
        print(f"Added padding:  0x{padding:08x} ({padding})")
    if image_end > IMAGE_LIMIT: raise RuntimeError("image exceeds reservation")
    crc = zlib.crc32(payload) & 0xffffffff
    words = [IMAGE_MAGIC, HEADER_BYTES, FORMAT_VERSION, FLAG_CRC32,
             IMAGE_BASE, len(payload), entry, bss, bss_end-bss, crc] + [0]*6
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(struct.pack("<16I", *words) + payload)
    print(f"Packaged:      {args.output}")
    print(f"Payload bytes: 0x{len(payload):08x} ({len(payload)})")
    print(f"Entry:         0x{entry:08x}")
    print(f"BSS:           0x{bss:08x} + 0x{bss_end-bss:08x}")
    print(f"Image end:     0x{image_end:08x}")
    print(f"CRC32:         0x{crc:08x}")
    return 0

if __name__ == "__main__":
    try: raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"error: {error}", file=sys.stderr); raise SystemExit(1)
