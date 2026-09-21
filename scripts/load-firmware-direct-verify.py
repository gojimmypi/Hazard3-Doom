#!/usr/bin/env python3
# -----------------------------------------------------------------------------
# File:        load-firmware-direct-verify.py
# Path:        scripts/load-firmware-direct-verify.py
#
# Project:     Hazard3-Doom
# Purpose:     Load and verify firmware through GDB using direct target reads.
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

"""Load an ELF through GDB and verify its loadable sections by direct reads."""

from __future__ import annotations

import argparse
import struct
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class LoadableSection:
    name: str
    address: int
    data: bytes


def loadable_sections(elf_path: Path) -> list[LoadableSection]:
    data = elf_path.read_bytes()
    if len(data) < 52 or data[:4] != b"\x7fELF":
        raise ValueError("not a valid ELF file")
    if data[4] != 1 or data[5] != 1:
        raise ValueError("expected an ELF32 little-endian file")
    e_type, e_machine, e_version = struct.unpack_from("<HHI", data, 16)
    if e_type != 2 or e_machine != 243 or e_version != 1:
        raise ValueError("expected a 32-bit RISC-V executable ELF")

    e_phoff, e_shoff = struct.unpack_from("<II", data, 28)
    e_phentsize, e_phnum, e_shentsize, e_shnum, e_shstrndx = struct.unpack_from(
        "<HHHHH", data, 42
    )
    if e_phentsize < 32 or e_shentsize < 40 or e_shstrndx >= e_shnum:
        raise ValueError("malformed ELF header")

    program_headers = []
    for index in range(e_phnum):
        offset = e_phoff + index * e_phentsize
        if offset + 32 > len(data):
            raise ValueError("malformed ELF program header table")
        program_headers.append(struct.unpack_from("<IIIIIIII", data, offset))

    section_headers = []
    for index in range(e_shnum):
        offset = e_shoff + index * e_shentsize
        if offset + 40 > len(data):
            raise ValueError("malformed ELF section header table")
        section_headers.append(struct.unpack_from("<IIIIIIIIII", data, offset))

    shstr = section_headers[e_shstrndx]
    names_offset = shstr[4]
    names_size = shstr[5]
    if names_offset + names_size > len(data):
        raise ValueError("malformed ELF section-name table")
    names = data[names_offset:names_offset + names_size]

    result = []
    for index, section in enumerate(section_headers):
        sh_name, sh_type, sh_flags, sh_addr, sh_offset, sh_size = section[:6]
        if not (sh_flags & 0x2) or sh_type == 8 or sh_size == 0:
            continue
        if sh_offset + sh_size > len(data):
            raise ValueError(f"malformed ELF section {index}")

        name_end = names.find(b"\0", sh_name)
        if sh_name >= len(names) or name_end < 0:
            name = f"section-{index}"
        else:
            name = names[sh_name:name_end].decode("ascii", errors="replace")

        load_address = sh_addr
        for program_header in program_headers:
            p_type, _, p_vaddr, p_paddr, _, p_memsz = program_header[:6]
            if (
                p_type == 1
                and sh_addr >= p_vaddr
                and sh_addr + sh_size <= p_vaddr + p_memsz
            ):
                load_address = p_paddr + (sh_addr - p_vaddr)
                break

        result.append(
            LoadableSection(
                name=name,
                address=load_address,
                data=data[sh_offset:sh_offset + sh_size],
            )
        )

    if not result:
        raise ValueError("no loadable ELF sections found")
    return result


def run_gdb(
    gdb: str, elf_path: Path, work_dir: Path, commands: list[str]
) -> int:
    args = [
        gdb,
        "--batch",
        "--quiet",
        str(elf_path),
        "-ex",
        "set confirm off",
        "-ex",
        "set pagination off",
        "-ex",
        "set remotetimeout 120",
        "-ex",
        "target extended-remote localhost:3333",
    ]
    for command in commands:
        args.extend(("-ex", command))
    return subprocess.run(args, cwd=work_dir, check=False).returncode


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--gdb", required=True)
    parser.add_argument("--work-dir", type=Path, required=True)
    parser.add_argument("elf", type=Path)
    args = parser.parse_args()

    try:
        sections = loadable_sections(args.elf)
    except (OSError, ValueError) as exc:
        print(f"ERROR: {exc}")
        return 1

    with tempfile.TemporaryDirectory(
        prefix=".hazard3-direct-verify-", dir=args.work_dir
    ) as temp_name:
        temp_dir = Path(temp_name)
        dump_paths = [
            temp_dir / f"section-{index}.bin"
            for index in range(len(sections))
        ]
        gdb_dump_paths = [path.relative_to(args.work_dir) for path in dump_paths]
        commands = ["monitor halt", "load"]
        for section, dump_path in zip(sections, gdb_dump_paths, strict=True):
            commands.append(
                "dump binary memory "
                f"{dump_path.as_posix()} 0x{section.address:08x} "
                f"0x{section.address + len(section.data):08x}"
            )
        commands.append("disconnect")

        rc = run_gdb(args.gdb, args.elf, args.work_dir, commands)
        if rc != 0:
            return rc

        for section, dump_path in zip(sections, dump_paths, strict=True):
            try:
                actual = dump_path.read_bytes()
            except OSError as exc:
                print(
                    f"ERROR: unable to read verification data for "
                    f"{section.name}: {exc}"
                )
                return 1

            end = section.address + len(section.data)
            if actual != section.data:
                print(
                    f"ERROR: Section {section.name}, range "
                    f"0x{section.address:08x} -- 0x{end:08x}: MIS-MATCHED!"
                )
                return 1
            print(
                f"Section {section.name}, range "
                f"0x{section.address:08x} -- 0x{end:08x}: matched."
            )

    return run_gdb(
        args.gdb,
        args.elf,
        args.work_dir,
        ["set $pc = _start", "monitor resume", "disconnect"],
    )


if __name__ == "__main__":
    raise SystemExit(main())
