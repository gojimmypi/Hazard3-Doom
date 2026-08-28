#!/usr/bin/env python3
# -----------------------------------------------------------------------------
# File:        reference-wad.py
# Path:        tests/doom-init-verify/reference-wad.py
#
# Project:     Hazard3-Doom
# Purpose:     Generate reference WAD metadata and verification values for Doom
#              initialization tests.
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
import struct
import sys

FNV_OFFSET = 2166136261
FNV_PRIME = 16777619
EXPECTED = {
    "PNAMES": (2804, 0x70DCD40A),
    "TEXTURE1": (9234, 0x7BFCE9C1),
}


def fnv1a(data):
    value = FNV_OFFSET
    for byte in data:
        value ^= byte
        value = (value * FNV_PRIME) & 0xFFFFFFFF
    return value


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("wad")
    args = parser.parse_args()

    data = open(args.wad, "rb").read()
    if len(data) < 12:
        raise SystemExit("WAD is too short")

    ident, count, directory = struct.unpack_from("<4sII", data, 0)
    if ident not in (b"IWAD", b"PWAD"):
        raise SystemExit("invalid WAD signature")

    found = {}
    for index in range(count):
        off = directory + index * 16
        position, size, raw_name = struct.unpack_from("<II8s", data, off)
        name = raw_name.rstrip(b"\0").decode("ascii", "replace")
        if name in EXPECTED:
            payload = data[position:position + size]
            found[name] = (index, size, fnv1a(payload))

    ok = True
    for name in ("PNAMES", "TEXTURE1"):
        expected_size, expected_hash = EXPECTED[name]
        if name not in found:
            print(f"{name}: MISSING")
            ok = False
            continue
        index, size, actual_hash = found[name]
        passed = size == expected_size and actual_hash == expected_hash
        print(
            f"{name}: {'PASS' if passed else 'FAIL'} "
            f"lump={index} bytes={size} fnv1a=0x{actual_hash:08X} "
            f"expected_bytes={expected_size} expected_fnv1a=0x{expected_hash:08X}"
        )
        ok &= passed

    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
