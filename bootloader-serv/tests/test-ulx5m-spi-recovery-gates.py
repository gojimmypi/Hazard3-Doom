#!/usr/bin/env python3
"""Host-only tests for stage-zero SPI recovery evidence; uses real C firmware."""
import hashlib
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
AUDIT = ROOT / "tests/audit-ulx5m-spi-recovery-gates.py"
APP = ROOT / "build-ulx5m-gs/top_ulx5m_gs_normal_led.bit"
SPEC = importlib.util.spec_from_file_location("ulx5m_spi_recovery_audit", AUDIT)
audit = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(audit)


class RecoveryTests(unittest.TestCase):
    def test_sector_plan(self):
        self.assertEqual(audit.METADATA_ADDRESS, 0x200000)
        self.assertEqual(audit.NATIVE_ADDRESS, 0x201000)
        self.assertEqual(audit.NATIVE_ADDRESS - audit.METADATA_ADDRESS,
                         audit.ERASE_BYTES)
        self.assertEqual(audit.FLASH_BYTES, 0x400000)

    def test_erase_classification(self):
        self.assertTrue(audit.classify_region(b"\xff" * 100, 1, 20)["erased"])
        self.assertEqual(audit.classify_region(b"\xff\x00\xff", 0, 3)["non_erased_bytes"], 1)

    def test_region_boundaries(self):
        for start, length in ((-1, 3), (99, 2), (0, 0), (2, 99)):
            with self.assertRaises(ValueError):
                audit.classify_region(b"\xff" * 100, start, length)

    def test_empty_candidate_sectors(self):
        flash = bytearray(b"\xff" * audit.FLASH_BYTES)
        regions = audit.inspect_backup(flash)
        self.assertTrue(regions["candidate_metadata_sector"]["erased"])
        flash[audit.NATIVE_ADDRESS + audit.ERASE_BYTES - 1] = 0
        regions = audit.inspect_backup(flash)
        self.assertFalse(regions["candidate_native_sector"]["erased"])
        self.assertTrue(regions["candidate_metadata_sector"]["erased"])

    def test_factory_wrong_size_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "short.bin"
            p.write_bytes(b"\xff" * 4095)
            with self.assertRaisesRegex(ValueError, "4 MiB"):
                audit.verify_factory(p)

    def test_factory_bad_hash_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "fake.bin"
            p.write_bytes(b"\xff" * audit.FLASH_BYTES)
            with self.assertRaisesRegex(ValueError, "SHA-256"):
                audit.verify_factory(p)
            digest = hashlib.sha256(p.read_bytes()).hexdigest()
            self.assertEqual(audit.verify_factory(p, expected_sha=digest), p.read_bytes())

    def test_independent_backup_mismatch_rejected(self):
        with self.assertRaisesRegex(ValueError, "differ"):
            audit.report(b"fake", b"a", b"b")

    def test_no_backup_no_hardware_authorization(self):
        result = audit.report(b"fake")
        self.assertFalse(result["flash_writes_enabled"])
        self.assertFalse(result["persistent_boot_authorized"])
        self.assertFalse(result["stage0_dfu_proven_persistent"])
        self.assertFalse(result["short_jump_accepted_by_cfg_ctrl"])

    def test_exact_fixture(self):
        b = audit.verify_app(APP)
        self.assertEqual(len(b), audit.APP_BYTES)
        self.assertTrue(b.startswith(audit.SYNC))

    def test_c_parser_crc_consistency_gap(self):
        source = ROOT / "tests/test-ulx5m-spi-recovery-gates.c"
        with tempfile.TemporaryDirectory(prefix="ulx5m-v38-test-") as d:
            exe = Path(d) / "verify-parser"
            cmd = ["cc", "-std=c11", "-Wall", "-Wextra", "-Werror", "-I", str(ROOT / "fw"),
                   str(source), str(ROOT / "fw/ulx5m_normal_image.c"),
                   str(ROOT / "fw/ulx5m_flash_layout.c"),
                   str(ROOT / "fw/ulx5m_spi_boot_preflight.c"), "-o", str(exe)]
            subprocess.run(cmd, check=True, capture_output=True, text=True)
            run = subprocess.run([str(exe), str(APP)], check=True, capture_output=True, text=True)
            self.assertIn("Modified, re-CRC'd native image", run.stdout)
            print("\n" + run.stdout.rstrip())


if __name__ == "__main__":
    unittest.main(verbosity=2)
