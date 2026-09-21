# -----------------------------------------------------------------------------
# File:        test_host_tools.py
# Path:        tests/test_host_tools.py
#
# Project:     Hazard3-Doom
# Purpose:     Unit-test Hazard3-Doom host-side packaging and upload utilities.
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

import importlib.util
import pathlib
import stat
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib


ROOT_DIR = pathlib.Path(__file__).resolve().parents[1]
DOOM_DIR = ROOT_DIR / "doom"


def load_script(module_name: str, filename: str):
    spec = importlib.util.spec_from_file_location(module_name, DOOM_DIR / filename)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"could not load {filename}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


upload_image = load_script("upload_doom_image", "upload-doom-image.py")
upload_wad = load_script("upload_wad", "upload-wad.py")


def make_h3img_package(payload: bytes) -> bytes:
    crc = zlib.crc32(payload) & 0xFFFFFFFF
    words = [
        upload_image.IMAGE_MAGIC,
        upload_image.HEADER_BYTES,
        upload_image.FORMAT_VERSION,
        upload_image.FLAG_CRC32,
        upload_image.IMAGE_BASE,
        len(payload),
        upload_image.IMAGE_BASE,
        upload_image.IMAGE_BASE + len(payload),
        0,
        crc,
    ] + [0] * 6
    return struct.pack("<16I", *words) + payload


def make_iwad() -> bytes:
    directory_offset = 12
    lump_position = directory_offset + 16
    header = struct.pack("<4sII", b"IWAD", 1, directory_offset)
    directory = struct.pack("<II8s", lump_position, 4, b"PLAYPAL\0")
    return header + directory + b"DATA"


class ChunkPort:
    def __init__(self, chunks: list[bytes]):
        self._chunks = list(chunks)

    def read(self, _size: int) -> bytes:
        if self._chunks:
            return self._chunks.pop(0)
        return b""


class DoomImagePackageTests(unittest.TestCase):
    def test_validate_package_accepts_valid_package(self):
        payload = b"Hazard3 Doom"
        package = make_h3img_package(payload)
        expected_crc = zlib.crc32(payload) & 0xFFFFFFFF

        self.assertEqual(
            upload_image.validate_package(package),
            (len(payload), expected_crc),
        )

    def test_read_until_any_accepts_split_marker(self):
        port = ChunkPort([b"boot\r\nH3L ", b"READY\r\n"])
        received = upload_image.read_until_any(
            port,
            (upload_image.READY_MARKER,),
            0.2,
        )
        self.assertIn(upload_image.READY_MARKER, received)

    def test_validate_package_rejects_bad_headers(self):
        payload = b"Doom"
        valid = bytearray(make_h3img_package(payload))
        cases = []

        cases.append((b"short", "package shorter than header"))

        bad_magic = bytearray(valid)
        struct.pack_into("<I", bad_magic, 0, 0)
        cases.append((bytes(bad_magic), "bad package magic"))

        bad_header_size = bytearray(valid)
        struct.pack_into("<I", bad_header_size, 4, 32)
        cases.append((bytes(bad_header_size), "unsupported header size"))

        bad_format_version = bytearray(valid)
        struct.pack_into("<I", bad_format_version, 8, upload_image.FORMAT_VERSION + 1)
        cases.append((bytes(bad_format_version), "unsupported format version"))

        bad_flags = bytearray(valid)
        struct.pack_into("<I", bad_flags, 12, 0)
        cases.append((bytes(bad_flags), "unsupported package flags"))

        bad_load_address = bytearray(valid)
        struct.pack_into("<I", bad_load_address, 16, upload_image.IMAGE_BASE + 4)
        cases.append((bytes(bad_load_address), "unexpected load address"))

        zero_payload = bytearray(valid)
        struct.pack_into("<I", zero_payload, 20, 0)
        cases.append((bytes(zero_payload), "payload size must be nonzero"))

        oversized_payload = bytearray(valid)
        struct.pack_into(
            "<I", oversized_payload, 20,
            upload_image.IMAGE_LIMIT - upload_image.IMAGE_BASE + 1)
        cases.append((bytes(oversized_payload), "payload range outside image reservation"))

        bad_bss_range = bytearray(valid)
        struct.pack_into("<I", bad_bss_range, 28, upload_image.IMAGE_LIMIT + 4)
        cases.append((bytes(bad_bss_range), "BSS range outside image reservation"))

        bad_entry = bytearray(valid)
        struct.pack_into("<I", bad_entry, 24, upload_image.IMAGE_BASE + len(payload))
        cases.append((bytes(bad_entry), "entry address outside payload"))

        overlapping_bss = bytearray(valid)
        struct.pack_into("<I", overlapping_bss, 28, upload_image.IMAGE_BASE)
        cases.append((bytes(overlapping_bss), "BSS overlaps payload"))

        unaligned_bss = bytearray(valid)
        struct.pack_into(
            "<I", unaligned_bss, 28, upload_image.IMAGE_BASE + len(payload) + 1)
        cases.append((bytes(unaligned_bss), "BSS address is not 4-byte aligned"))

        bad_bss_end = bytearray(valid)
        struct.pack_into("<I", bad_bss_end, 28, upload_image.IMAGE_LIMIT - 4)
        struct.pack_into("<I", bad_bss_end, 32, 8)
        cases.append((bytes(bad_bss_end), "BSS range outside image reservation"))

        bad_reserved = bytearray(valid)
        struct.pack_into("<I", bad_reserved, 40, 1)
        cases.append((bytes(bad_reserved), "reserved header words must be zero"))

        cases.append((bytes(valid[:-1]), "package length mismatch"))

        bad_payload_crc = bytearray(valid)
        bad_payload_crc[-1] ^= 0xFF
        cases.append((bytes(bad_payload_crc), "payload CRC32 mismatch"))

        for package, message in cases:
            with self.subTest(message=message):
                with self.assertRaisesRegex(RuntimeError, message):
                    upload_image.validate_package(package)

    def test_validate_only_cli(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            image = pathlib.Path(temporary_directory) / "doom.h3img"
            image.write_bytes(make_h3img_package(b"Hazard3 Doom"))

            result = subprocess.run(
                [
                    sys.executable,
                    str(DOOM_DIR / "upload-doom-image.py"),
                    str(image),
                    "--validate-only",
                ],
                check=True,
                capture_output=True,
                text=True,
            )

            self.assertIn("Validated", result.stdout)


class WadPackageTests(unittest.TestCase):
    def test_read_until_any_accepts_split_marker(self):
        port = ChunkPort([b"monitor\r\nH3W D", b"ATA\r\n"])
        received = upload_wad.read_until_any(
            port,
            (upload_wad.DATA_MARKER,),
            0.2,
        )
        self.assertIn(upload_wad.DATA_MARKER, received)

    def test_validate_name(self):
        encoded = upload_wad.validate_name("doom1.wad")
        self.assertEqual(len(encoded), 16)
        self.assertEqual(encoded.rstrip(b"\0"), b"doom1.wad")

        invalid_names = (
            ".wad",
            "123456789012.wad",
            "doom1.txt",
            "doom one.wad",
        )
        for name in invalid_names:
            with self.subTest(name=name):
                with self.assertRaises(RuntimeError):
                    upload_wad.validate_name(name)

    def test_validate_iwad_accepts_valid_directory(self):
        wad = make_iwad()
        self.assertEqual(upload_wad.validate_iwad(wad, 0, 4096), (1, 12))

    def test_validate_iwad_rejects_invalid_files(self):
        valid = make_iwad()
        cases = (
            b"short",
            b"PWAD" + valid[4:],
            struct.pack("<4sII", b"IWAD", 0, 12),
            struct.pack("<4sII", b"IWAD", 1, 13),
            struct.pack("<4sII", b"IWAD", 1, 12)
            + struct.pack("<II8s", 100, 4, b"PLAYPAL\0"),
        )
        for wad in cases:
            with self.subTest(wad=wad[:12]):
                with self.assertRaises(RuntimeError):
                    upload_wad.validate_iwad(wad, 0, 4096)

        with self.assertRaisesRegex(RuntimeError, "exceeds the reserved"):
            upload_wad.validate_iwad(valid, 0, len(valid) - 1)

    def test_create_header(self):
        wad = make_iwad()
        name = upload_wad.validate_name("doom1.wad")
        wad_base = 0x22C00000

        header, crc = upload_wad.create_header(wad, name, wad_base)
        values = struct.unpack("<8I16s4I", header)

        self.assertEqual(len(header), upload_wad.WAD_HEADER_BYTES)
        self.assertEqual(values[0], upload_wad.WAD_PACKAGE_MAGIC)
        self.assertEqual(values[1], upload_wad.WAD_HEADER_BYTES)
        self.assertEqual(values[4], wad_base)
        self.assertEqual(values[5], len(wad))
        self.assertEqual(values[6], crc)
        self.assertEqual(values[8], name)
        self.assertEqual(crc, zlib.crc32(wad) & 0xFFFFFFFF)


class DoomImagePackagerTests(unittest.TestCase):
    def test_packager_pads_payload_and_writes_crc(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            temporary = pathlib.Path(temporary_directory)
            elf = temporary / "doom.elf"
            binary = temporary / "doom.bin"
            image = temporary / "doom.h3img"
            fake_nm = temporary / "fake-nm"

            elf.write_bytes(b"not used by the fake nm tool")
            binary.write_bytes(b"DO")
            fake_nm.write_text(
                "#!/bin/sh\n"
                "cat <<'SYMBOLS'\n"
                "20100000 T _doom_start\n"
                "20100004 B __doom_image_load_end\n"
                "20100004 B __doom_bss_start\n"
                "20100008 B __doom_bss_end\n"
                "20100008 B __doom_image_end\n"
                "SYMBOLS\n",
                encoding="ascii",
            )
            fake_nm.chmod(fake_nm.stat().st_mode | stat.S_IXUSR)

            subprocess.run(
                [
                    sys.executable,
                    str(DOOM_DIR / "package-doom-image.py"),
                    "--elf",
                    str(elf),
                    "--binary",
                    str(binary),
                    "--output",
                    str(image),
                    "--nm",
                    str(fake_nm),
                ],
                check=True,
                capture_output=True,
                text=True,
            )

            package = image.read_bytes()
            payload_bytes, crc = upload_image.validate_package(package)
            payload = package[upload_image.HEADER_BYTES :]

            self.assertEqual(payload_bytes, 4)
            self.assertEqual(payload, b"DO\0\0")
            self.assertEqual(crc, zlib.crc32(payload) & 0xFFFFFFFF)


if __name__ == "__main__":
    unittest.main()
