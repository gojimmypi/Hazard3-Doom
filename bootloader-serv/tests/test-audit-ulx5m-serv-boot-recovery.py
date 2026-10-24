#!/usr/bin/env python3
"""Offline no-device tests for the ULX5M boot provenance gate."""

import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
SCRIPT = HERE / "audit-ulx5m-serv-boot-recovery.py"
SPEC = importlib.util.spec_from_file_location("boot_audit", SCRIPT)
audit = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(audit)


def sha(data):
    return hashlib.sha256(data).hexdigest()


class BootAuditTests(unittest.TestCase):
    def setUp(self):
        self.golden = b"\xd9\x01\xed\x96" + b"\x23" * 36
        self.factory = bytearray(b"\xff" * audit.FLASH_BYTES)
        self.factory[:len(self.golden)] = self.golden

    def test_exact_bytes_are_not_recovery_authorization(self):
        result = audit.assess(bytes(self.factory), self.golden)
        self.assertTrue(result["flash_origin_exact_seed147_bytes"])
        self.assertFalse(result["persistent_dfu_recovery_verified"])
        self.assertFalse(result["configuration_handoff_authorized"])
        self.assertFalse(result["flash_write_authorized"])

    def test_one_different_byte_disqualifies_origin(self):
        self.factory[19] ^= 1
        result = audit.assess(bytes(self.factory), self.golden)
        self.assertFalse(result["flash_origin_exact_seed147_bytes"])
        self.assertEqual(result["flash_origin_first_seed147_difference"], 19)

    def test_u5im_magic_cannot_authorize(self):
        self.factory[audit.CANDIDATE_ADDR:audit.CANDIDATE_ADDR + 4] = b"U5IM"
        result = audit.assess(bytes(self.factory), self.golden)
        self.assertTrue(result["candidate_probe_has_u5im_magic"])
        self.assertFalse(result["bootaddr_0x200000_authorized"])
        self.assertFalse(result["configuration_handoff_authorized"])

    def test_erased_sector_is_not_writable_authorization(self):
        result = audit.assess(bytes(self.factory), self.golden)
        self.assertTrue(result["candidate_probe_first_sector_all_ff"])
        self.assertFalse(result["flash_write_authorized"])

    def test_bad_lengths(self):
        for factory, golden in ((b"", self.golden), (bytes(self.factory), b""),
                                (bytes(self.factory), b"x" * (audit.FLASH_BYTES + 1))):
            with self.assertRaises(audit.AuditError):
                audit.assess(factory, golden)

    def test_golden_digest_gate(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "image.bit"
            path.write_bytes(self.golden)
            with self.assertRaises(audit.AuditError):
                audit.checked_golden(path)
            with patch.object(audit, "SEED147_BYTES", len(self.golden)), \
                 patch.object(audit, "SEED147_SHA256", sha(self.golden)):
                self.assertEqual(audit.checked_golden(path), self.golden)
            path.write_bytes(self.golden[:-1] + b"x")
            with patch.object(audit, "SEED147_BYTES", len(self.golden)), \
                 patch.object(audit, "SEED147_SHA256", sha(self.golden)):
                with self.assertRaises(audit.AuditError):
                    audit.checked_golden(path)

    def make_backup(self, root):
        # Construct a full, internally consistent two-pass test fixture.
        spec = importlib.util.spec_from_file_location(
            "existing_checker", HERE / "analyze-ulx5m-serv-flash-backup.py")
        checker = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(checker)
        data = bytes(self.factory)
        report = {
            "format": "ULX5M-GS SERV flash-backup-v1",
            "device_jedec_hex": "1f4216", "size_bytes": audit.FLASH_BYTES,
            "byte_for_byte_match": True,
            "passes": [
                {"file": name, "sha256": sha(data)}
                for name in ("flash-pass1.bin", "flash-pass2.bin")
            ],
            "analysis": checker.sector_map(data),
        }
        (root / "flash-pass1.bin").write_bytes(data)
        (root / "flash-pass2.bin").write_bytes(data)
        (root / "flash-backup-report.json").write_text(json.dumps(report), encoding="utf-8")
        return data

    def test_frozen_factory_digest_gate_and_double_pass(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            data = self.make_backup(root)
            with self.assertRaises(audit.AuditError):
                audit.checked_factory(root)
            with patch.object(audit, "FACTORY_SHA256", sha(data)):
                self.assertEqual(audit.checked_factory(root), data)
                with (root / "flash-pass2.bin").open("r+b") as fd:
                    fd.seek(21)
                    fd.write(b"0")
                with self.assertRaises(audit.AuditError):
                    audit.checked_factory(root)

    def test_no_report_on_invalid_input_and_create_only(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            golden = root / "image.bit"
            golden.write_bytes(self.golden)
            backup = root / "backup"
            backup.mkdir()
            data = self.make_backup(backup)
            report = root / "boot-audit.json"
            with patch.object(audit, "SEED147_BYTES", len(self.golden)), \
                 patch.object(audit, "SEED147_SHA256", sha(self.golden)):
                self.assertEqual(audit.main(["--backup", str(backup),
                                             "--golden-bit", str(golden),
                                             "--json-out", str(report)]), 1)
                self.assertFalse(report.exists())
                with patch.object(audit, "FACTORY_SHA256", sha(data)):
                    self.assertEqual(audit.main(["--backup", str(backup),
                                                 "--golden-bit", str(golden),
                                                 "--json-out", str(report)]), 0)
                    result = json.loads(report.read_text())
                    self.assertFalse(result["persistent_dfu_recovery_verified"])
                    before = report.read_bytes()
                    self.assertEqual(audit.main(["--backup", str(backup),
                                                 "--golden-bit", str(golden),
                                                 "--json-out", str(report)]), 1)
                    self.assertEqual(before, report.read_bytes())

    def test_help_does_not_touch_backup(self):
        result = subprocess.run([sys.executable, str(SCRIPT), "--help"],
                                capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0)
        self.assertIn("--backup", result.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
