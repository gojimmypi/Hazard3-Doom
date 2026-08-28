#!/usr/bin/env python3
# -----------------------------------------------------------------------------
# File:        make-boot-hex.py
# Path:        scripts/make-boot-hex.py
#
# Project:     Hazard3-Doom
# Purpose:     Convert the resident monitor binary into 32-bit little-endian
#              FPGA boot-memory initialization data.
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

#
# File: scripts/make-boot-hex.py
#
# See submodule Hazard3 for sram readmemh
#
"""Convert the resident monitor binary to 32-bit little-endian readmemh data."""

from __future__ import annotations

import argparse
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input_bin", type=Path)
    parser.add_argument("output_hex", type=Path)
    parser.add_argument("--bytes", type=lambda value: int(value, 0), default=0x10000,
                        help="preloaded monitor region (default: 64 KiB)")
    parser.add_argument("--load-address", type=lambda value: int(value, 0), default=0x40,
                        help="address of first byte in objcopy binary (default: 0x40)")
    args = parser.parse_args()

    payload = args.input_bin.read_bytes()
    if args.load_address < 0 or args.load_address >= args.bytes:
        raise SystemExit("load address must be inside the preload region")
    if len(payload) > args.bytes - args.load_address:
        raise SystemExit(
            f"monitor binary is {len(payload)} bytes; only "
            f"{args.bytes - args.load_address} bytes remain after load address")

    # GNU objcopy's raw binary starts at the lowest loadable section rather
    # than absolute address zero. link.ld places .vectors/_start at 0x40, so
    # restore that leading address gap before converting to RAM words.
    data = bytes(args.load_address) + payload
    data += bytes(args.bytes - len(data))
    if len(data) % 4:
        data += bytes(4 - (len(data) % 4))

    args.output_hex.parent.mkdir(parents=True, exist_ok=True)
    with args.output_hex.open("w", encoding="ascii", newline="\n") as output:
        for offset in range(0, len(data), 4):
            word = int.from_bytes(data[offset:offset + 4], "little")
            output.write(f"{word:08x}\n")

    print(f"resident monitor: {args.input_bin} (load address 0x{args.load_address:x})")
    print(f"EBR preload hex:  {args.output_hex}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
