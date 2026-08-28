#!/usr/bin/env python3
# -----------------------------------------------------------------------------
# File:        build-supercon10-wad.py
# Path:        scripts/build-supercon10-wad.py
#
# Project:     Hazard3-Doom
# Purpose:     Validate and merge the canonical Supercon PWAD with a local
#              DOOM1.WAD.
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

"""Validate and merge the canonical Supercon PWAD into the user's DOOM1.WAD."""

from __future__ import annotations

import argparse
import hashlib
import struct
import subprocess
import sys
from pathlib import Path


def read_lumps(path: Path):
    data = path.read_bytes()
    if len(data) < 12:
        raise SystemExit(f"{path}: too small to be a WAD")
    ident, count, directory = struct.unpack_from("<4sII", data, 0)
    if directory + count * 16 > len(data):
        raise SystemExit(f"{path}: invalid WAD directory")
    lumps = []
    for i in range(count):
        off, size, raw = struct.unpack_from("<II8s", data, directory + i * 16)
        if off + size > len(data):
            raise SystemExit(f"{path}: lump {i} extends past EOF")
        name = raw.rstrip(b"\0").decode("ascii", errors="replace")
        lumps.append((name, data[off:off + size]))
    return ident, lumps


def verify_merged_banner_textures(path: Path) -> None:
    ident, lumps = read_lumps(path)
    if ident != b"IWAD":
        raise SystemExit(f"{path}: expected merged IWAD")
    lookup = {}
    for name, payload in lumps:
        lookup[name] = payload

    pnames = lookup.get("PNAMES")
    texture1 = lookup.get("TEXTURE1")
    if pnames is None or texture1 is None:
        raise SystemExit(f"{path}: missing PNAMES/TEXTURE1")

    pcount = struct.unpack_from("<I", pnames, 0)[0]
    patch_names = [
        pnames[4 + 8 * i:12 + 8 * i].rstrip(b"\0").decode("ascii")
        for i in range(pcount)
    ]

    tcount = struct.unpack_from("<I", texture1, 0)[0]
    offsets = struct.unpack_from("<" + "I" * tcount, texture1, 4)
    for texture_name in ("SC10BANR", "SF10BANR"):
        if texture_name not in patch_names:
            raise SystemExit(f"{path}: {texture_name} missing from PNAMES")
        hits = []
        for off in offsets:
            name = texture1[off:off + 8].rstrip(b"\0").decode("ascii")
            if name == texture_name:
                _, width, height, _, patch_count = struct.unpack_from(
                    "<IhhIh", texture1, off + 8
                )
                hits.append((width, height, patch_count))
        if hits != [(512, 128, 1)]:
            raise SystemExit(
                f"{path}: invalid {texture_name} texture definition: {hits}"
            )


def verify_fixed_heading(path: Path) -> None:
    ident, lumps = read_lumps(path)
    if ident != b"PWAD":
        raise SystemExit(f"{path}: expected PWAD")
    lookup = {name: payload for name, payload in lumps}
    for i in range(1, 5):
        name = f"DEMO{i}"
        demo = lookup.get(name)
        if not demo or len(demo) < 14 or demo[0] != 109 or demo[-1] != 0x80:
            raise SystemExit(f"{path}: invalid {name}")
        for pos in range(13, len(demo) - 1, 4):
            tic = (pos - 13) // 4
            sidemove = demo[pos + 1]
            angleturn = demo[pos + 2]
            buttons = demo[pos + 3]
            if sidemove != 0 or angleturn != 0 or (buttons & 1):
                raise SystemExit(
                    f"{path}: {name} tic {tic} is not fixed-heading/noncombat "
                    f"(sidemove={sidemove}, angleturn={angleturn}, buttons=0x{buttons:02x})"
                )
    for texture_name in ("SC10BANR", "SF10BANR"):
        banner = lookup.get(texture_name)
        if not banner or len(banner) < 8:
            raise SystemExit(f"{path}: missing {texture_name} wall patch")
        width, height = struct.unpack_from("<hh", banner, 0)
        if (width, height) != (512, 128):
            raise SystemExit(
                f"{path}: {texture_name} is {width}x{height}, expected 512x128"
            )

    sidedefs = lookup.get("SIDEDEFS")
    if sidedefs is None or len(sidedefs) % 30:
        raise SystemExit(f"{path}: invalid SIDEDEFS")
    refs = {"SC10BANR": 0, "SF10BANR": 0}
    for off in range(0, len(sidedefs), 30):
        middle = sidedefs[off + 20:off + 28].rstrip(b"\0").decode(
            "ascii", errors="replace"
        )
        if middle in refs:
            refs[middle] += 1
    if refs != {"SC10BANR": 2, "SF10BANR": 2}:
        raise SystemExit(f"{path}: unexpected banner wall references: {refs}")

    info = lookup.get("SC10INFO", b"").decode("ascii", errors="replace")
    required_markers = (
        "FIXED-HEADING",
        "SC10BANR=HACKADAY+SUPERCON10",
        "SF10BANR=SUPPLYFRAME",
        "WALLS=S1:SC10,N4:SF10,S7:SF10,N9:SC10",
        "HELP2=NO-OVERLAP",
    )
    if not all(marker in info for marker in required_markers):
        raise SystemExit(f"{path}: missing canonical SC10INFO markers")


def main() -> None:
    script_dir = Path(__file__).resolve().parent
    root = script_dir.parent
    parser = argparse.ArgumentParser()
    parser.add_argument("--iwad", type=Path, default=root / "wads" / "DOOM1.WAD")
    parser.add_argument("--pwad", type=Path, default=root / "wads" / "supercon10-friendly.wad")
    parser.add_argument("--output", type=Path, default=root / "wads" / "SUPERCON10.WAD")
    args = parser.parse_args()

    merger = root / "wads" / "merge_iwad.py"
    for required in (args.iwad, args.pwad, merger):
        if not required.is_file():
            raise SystemExit(f"Missing required file: {required}")

    iwad_ident, _ = read_lumps(args.iwad)
    if iwad_ident != b"IWAD":
        raise SystemExit(f"{args.iwad}: expected IWAD")

    verify_fixed_heading(args.pwad)
    print("Supercon PWAD verification: PASS")
    print("  DEMO1..DEMO4 sidemove = 0")
    print("  DEMO1..DEMO4 angleturn = 0")
    print("  DEMO1..DEMO4 Attack = 0")
    print("  SC10BANR = Hackaday + Supercon 10, 512x128, 2 wall references")
    print("  SF10BANR = Supplyframe logo/wordmark, 512x128, 2 wall references")
    print("  HELP2 checklist trace overlap = fixed")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [sys.executable, str(merger), str(args.iwad), str(args.pwad), str(args.output)],
        check=True,
    )
    verify_merged_banner_textures(args.output)
    print("Merged banner texture verification: PASS (SC10BANR + SF10BANR)")
    digest = hashlib.sha256(args.output.read_bytes()).hexdigest()
    print(f"Ready to upload: {args.output}")
    print(f"SHA-256: {digest}")


if __name__ == "__main__":
    main()
