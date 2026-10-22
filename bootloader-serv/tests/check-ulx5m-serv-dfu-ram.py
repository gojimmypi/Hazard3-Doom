#!/usr/bin/env python3
"""Check staged SERV ELF symbols keep at least 2 KiB below sp=0x8000.

Accepts the output of riscv-none-elf-nm -n <ELF>. No third-party modules.
"""
import argparse
from pathlib import Path

RAM_END = 0x8000
MIN_STACK_BYTES = 2048


def check_symbols(text):
    symbols = {}
    for line in text.splitlines():
        fields = line.split()
        if len(fields) != 3:
            continue
        address, _kind, name = fields
        if name in ("_heap_start", "_ebss"):
            symbols[name] = int(address, 16)
    for name in ("_heap_start", "_ebss"):
        if name not in symbols:
            raise ValueError("Missing linker symbol: " + name)
    end = max(symbols.values())
    free = RAM_END - end
    if free < MIN_STACK_BYTES:
        raise ValueError("Insufficient SERV RAM stack space: {} bytes (min {})".format(
            free, MIN_STACK_BYTES))
    return end, free


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("symbols", nargs="?", help="nm -n symbol text file")
    parser.add_argument("--selftest", action="store_true")
    args = parser.parse_args()
    if args.selftest:
        assert check_symbols("00006000 B _ebss\n00006000 B _heap_start\n") == (0x6000, 8192)
        for content in ("00007900 B _heap_start\n00007900 B _ebss\n",
                        "00002000 B _ebss\n"):
            try:
                check_symbols(content)
            except ValueError:
                pass
            else:
                raise AssertionError("Invalid symbols not rejected")
        print("[PASS] DFU RAM/stack guard selftest")
        return 0
    if not args.symbols:
        parser.error("symbols file required")
    end, free = check_symbols(Path(args.symbols).read_text(encoding="ascii"))
    print("[PASS] DFU RAM ends at 0x{:04x}; minimum stack headroom {} bytes".format(
        end, free))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
