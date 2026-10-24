#!/usr/bin/env python3
"""Offline-only tests for SPI native-entry and recovery-authorization audit."""
import importlib.util
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest
import zlib

MODULE = Path(__file__).with_name("audit-ulx5m-spi-boot-layout.py")
SPEC = importlib.util.spec_from_file_location("ulx5m_v35_layout", MODULE)
AUDIT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(AUDIT)


def record(opcode, data):
    header = bytes((opcode, len(data)))
    first = header + AUDIT.V34.crc16_x25(header).to_bytes(2, "little") + data
    return first + AUDIT.V34.crc16_x25(first).to_bytes(2, "little")


def stream(target):
    return (b"pinned-prefix" + record(0xc3, b"\0") +
            record(0xda, target.to_bytes(4, "little")) + b"tail")


class LayoutAuditTests(unittest.TestCase):
    def setUp(self):
        self.bit = AUDIT.NATIVE_SYNC + bytes(range(60))

    def test_u5im_endian_fields_and_checksums(self):
        h = AUDIT.make_u5im_header(self.bit)
        self.assertEqual(len(h), 32)
        self.assertEqual(h[:4], b"U5IM")
        self.assertEqual(struct.unpack_from("<IIII", h, 4), (1, 1, 4096, len(self.bit)))
        self.assertEqual(struct.unpack_from("<I", h, 20)[0], zlib.crc32(self.bit))
        self.assertEqual(struct.unpack_from("<I", h, 24)[0], zlib.crc32(h[:24] + b"\0" * 4 + h[28:]))
        self.assertEqual(h[28:], b"\0" * 4)

    def test_u5im_rejects_bad_magic(self):
        with self.assertRaisesRegex(ValueError, "CMD_PATH"):
            AUDIT.make_u5im_header(b"not GateMate")

    def test_u5im_rejects_bad_offset(self):
        with self.assertRaisesRegex(ValueError, "page-aligned"):
            AUDIT.make_u5im_header(self.bit, 257)

    def test_u5im_rejects_oversize(self):
        with self.assertRaisesRegex(ValueError, "exceeds flash"):
            AUDIT.make_u5im_header(self.bit, 0x200000)

    def test_native_addresses_are_sector_aligned(self):
        self.assertTrue(AUDIT.check_flash_regions(0x200000, 0x201000, 3026))
        with self.assertRaisesRegex(ValueError, "sector aligned"):
            AUDIT.check_flash_regions(0x200000, 0x200100, 3026)

    def test_native_address_flash_boundary(self):
        with self.assertRaisesRegex(ValueError, "exceeds flash"):
            AUDIT.check_flash_regions(0x200000, 0x201000, 0x300000)

    def test_native_memory_staging_only(self):
        blob = AUDIT.memory_fixture(self.bit)
        self.assertEqual(len(blob), AUDIT.FLASH_BYTES)
        self.assertEqual(blob[0x200000:0x200004], b"U5IM")
        self.assertEqual(blob[0x200100:0x200104], b"\xff" * 4)
        self.assertEqual(blob[0x201000:0x201004], AUDIT.NATIVE_SYNC)
        self.assertEqual(blob[0x201000:0x201000 + len(self.bit)], self.bit)
        self.assertEqual(blob[:4096], b"\xff" * 4096)

    def test_correct_jumps_and_identical_surrounding_bytes(self):
        report = AUDIT.compare_bootaddr_commands(stream(0x200000), stream(0x201000))
        self.assertEqual(report["target"], "0x201000")
        self.assertEqual(report["stream_bytes"], len(stream(0x200000)))

    def test_wrong_jump_target_rejected(self):
        with self.assertRaisesRegex(ValueError, "target"):
            AUDIT.compare_bootaddr_commands(stream(0x200000), stream(0x200000))

    def test_wrong_reference_jump_rejected(self):
        with self.assertRaisesRegex(ValueError, "reference"):
            AUDIT.compare_bootaddr_commands(stream(0x201000), stream(0x201000))

    def test_unexpected_mutation_rejected(self):
        altered = b"X" + stream(0x201000)[1:]
        with self.assertRaisesRegex(ValueError, "outside"):
            AUDIT.compare_bootaddr_commands(stream(0x200000), altered)

    def test_corrupt_jump_crc_rejected(self):
        altered = bytearray(stream(0x201000))
        altered[-7] ^= 1
        with self.assertRaisesRegex(ValueError, "exactly one"):
            AUDIT.compare_bootaddr_commands(stream(0x200000), bytes(altered))

    def test_missing_reset_rejected(self):
        reference = b"prefix" + record(0xda, (0x200000).to_bytes(4, "little"))
        candidate = b"prefix" + record(0xda, (0x201000).to_bytes(4, "little"))
        with self.assertRaisesRegex(ValueError, "CFGRST"):
            AUDIT.compare_bootaddr_commands(reference, candidate)

    def test_mismatched_size_rejected(self):
        with self.assertRaisesRegex(ValueError, "length"):
            AUDIT.compare_bootaddr_commands(stream(0x200000), stream(0x201000) + b"\0")

    def test_packer_command_options_and_cleanup(self):
        ref = b"pinned"
        old_hash = AUDIT.REFERENCE_BOOTADDR_SHA256
        AUDIT.REFERENCE_BOOTADDR_SHA256 = AUDIT.digest(stream(0x200000))
        written = []
        def runner(args, **kwargs):
            out = Path(args[-1]); written.append(out)
            target = int(args[args.index("--bootaddr") + 1]) if "--bootaddr" in args else None
            out.write_bytes(ref if target is None else stream(target))
            return subprocess.CompletedProcess(args, 0, "", "")
        try:
            info = AUDIT.pack_variants("unused", ref, runner=runner)
            self.assertEqual(info["target"], "0x201000")
            self.assertTrue(all(not p.exists() for p in written))
        finally:
            AUDIT.REFERENCE_BOOTADDR_SHA256 = old_hash

    def test_packer_default_mismatch_fail_closed(self):
        def runner(args, **kwargs):
            Path(args[-1]).write_bytes(b"corrupt")
            return subprocess.CompletedProcess(args, 0, "", "")
        with self.assertRaisesRegex(ValueError, "default packer"):
            AUDIT.pack_variants("unused", b"pinned", runner=runner)

    def test_packer_failed_command_rejected(self):
        def runner(args, **kwargs):
            return subprocess.CompletedProcess(args, 1, "", "unsupported")
        with self.assertRaisesRegex(RuntimeError, "unsupported"):
            AUDIT.pack_variants("unused", b"pinned", runner=runner)

    def test_verify_firmware_policy_requires_exact_guard(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "fw").mkdir(); (root / "tests").mkdir()
            (root / "fw" / "ulx5m_normal_boot.c").write_text(
                "info.payload_address != ULX5M_NORMAL_BOOT_SLOT + 256u\n", encoding="ascii")
            (root / "fw" / "ulx5m_normal_boot.h").write_text(
                "ULX5M_NORMAL_BOOT_SLOT 0x00200000u\n", encoding="ascii")
            (root / "fw" / "ulx5m_flash_layout.c").write_text(
                "return ULX5M_FLASH_WRITE_PROTECTED;\n", encoding="ascii")
            for name in ("ulx5m_normal_image.c",):
                (root / "fw" / name).write_text("\n", encoding="ascii")
            (root / "tests" / "probe-ulx5m-serv-normal-image.c").write_text("\n", encoding="ascii")
            policy = AUDIT.check_firmware_policy(root)
            self.assertFalse(policy["writes_enabled"])
            self.assertIn("INCOMPATIBLE", policy["existing_normal_boot"])
            (root / "fw" / "ulx5m_normal_boot.c").write_text("changed\n", encoding="ascii")
            with self.assertRaisesRegex(ValueError, "changed"):
                AUDIT.check_firmware_policy(root)


if __name__ == "__main__":
    unittest.main(verbosity=2)
