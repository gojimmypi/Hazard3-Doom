#!/usr/bin/env python3
"""Offline regressions for the read-only ULX5M-GS flash sector analyzer."""

import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

SCRIPT = Path(__file__).with_name("analyze-ulx5m-serv-flash-backup.py")
spec = importlib.util.spec_from_file_location("flash_analysis", SCRIPT)
flash_analysis = importlib.util.module_from_spec(spec)
spec.loader.exec_module(flash_analysis)


class FlashAnalysisTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.directory = Path(cls.temp.name)
        image = bytearray(b"\xff" * flash_analysis.FLASH_BYTES)
        image[0] = 0xd9
        image[3 * 4096:4 * 4096] = b"\x00" * 4096
        image[314 * 4096 + 31] = 0x42
        cls.image = bytes(image)
        cls.sectors = flash_analysis.sector_map(cls.image)
        digest = hashlib.sha256(cls.image).hexdigest()
        cls.report = {
            "format": "ULX5M-GS SERV flash-backup-v1",
            "device_jedec_hex": "1f4216",
            "size_bytes": flash_analysis.FLASH_BYTES,
            "read_chunk_bytes": 32,
            "flash_policy": "FLM1 all-write-protected; boundaries unverified",
            "passes": [
                {"file": "flash-pass1.bin", "sha256": digest},
                {"file": "flash-pass2.bin", "sha256": digest},
            ],
            "byte_for_byte_match": True,
            "analysis": {key: value for key, value in cls.sectors.items()
                         if key != "sector_runs" and key != "sector_count"},
        }
        (cls.directory / "flash-pass1.bin").write_bytes(cls.image)
        (cls.directory / "flash-pass2.bin").write_bytes(cls.image)
        (cls.directory / "flash-backup-report.json").write_text(
            json.dumps(cls.report), encoding="utf-8")

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def test_real_size_sector_geometry_and_ff_not_write_authorized(self):
        result = flash_analysis.analyze(self.directory)
        self.assertTrue(result["both_reads_verified"])
        self.assertFalse(result["write_authorized"])
        self.assertEqual(result["flash_bytes"], 4 * 1024 * 1024)
        self.assertEqual(result["sector_analysis"]["sector_count"], 1024)
        self.assertEqual(result["sector_analysis"]["all_00_sectors"], 1)
        self.assertEqual(result["sector_analysis"]["other_sectors"], 2)
        self.assertEqual(result["sector_analysis"]["all_ff_sectors"], 1021)
        self.assertEqual(result["sector_analysis"]["last_non_ff_offset"],
                         314 * 4096 + 31)

    def test_zip_input_without_extraction(self):
        zip_name = self.directory / "backups.zip"
        with zipfile.ZipFile(zip_name, "w", compression=zipfile.ZIP_DEFLATED) as zf:
            for name in flash_analysis.BACKUP_FILES:
                zf.write(self.directory / name, arcname="flash-backup-20261022/" + name)
        self.assertEqual(flash_analysis.analyze(zip_name)["sha256"],
                         self.report["passes"][0]["sha256"])

    def test_two_pass_mismatch_rejected_even_with_updated_hash(self):
        files = flash_analysis.read_backup(self.directory)
        corrupted = bytearray(files["flash-pass2.bin"])
        corrupted[0x100] ^= 1
        files["flash-pass2.bin"] = bytes(corrupted)
        report = json.loads(files["flash-backup-report.json"])
        report["passes"][1]["sha256"] = hashlib.sha256(corrupted).hexdigest()
        files["flash-backup-report.json"] = json.dumps(report).encode("utf-8")
        with self.assertRaisesRegex(flash_analysis.BackupError, "differ"):
            flash_analysis.checked_report(files)

    def test_hash_mismatch_rejected(self):
        files = flash_analysis.read_backup(self.directory)
        report = json.loads(files["flash-backup-report.json"])
        report["passes"][0]["sha256"] = "0" * 64
        files["flash-backup-report.json"] = json.dumps(report).encode("utf-8")
        with self.assertRaisesRegex(flash_analysis.BackupError, "SHA-256"):
            flash_analysis.checked_report(files)

    def test_inconsistent_sector_report_rejected(self):
        files = flash_analysis.read_backup(self.directory)
        report = json.loads(files["flash-backup-report.json"])
        report["analysis"]["all_ff_sectors"] += 1
        files["flash-backup-report.json"] = json.dumps(report).encode("utf-8")
        with tempfile.TemporaryDirectory() as temporary:
            backup = Path(temporary)
            for name, content in files.items():
                (backup / name).write_bytes(content)
            with self.assertRaisesRegex(flash_analysis.BackupError, "all_ff_sectors"):
                flash_analysis.analyze(backup)

    def test_report_cannot_authorize_write(self):
        files = flash_analysis.read_backup(self.directory)
        report = json.loads(files["flash-backup-report.json"])
        report["flash_policy"] = "writable: arbitrary"
        files["flash-backup-report.json"] = json.dumps(report).encode("utf-8")
        with tempfile.TemporaryDirectory() as temporary:
            backup = Path(temporary)
            for name, content in files.items():
                (backup / name).write_bytes(content)
            self.assertFalse(flash_analysis.analyze(backup)["write_authorized"])

    def test_truncated_image_rejected(self):
        files = flash_analysis.read_backup(self.directory)
        files["flash-pass1.bin"] = files["flash-pass1.bin"][:-1]
        with self.assertRaisesRegex(flash_analysis.BackupError, "length"):
            flash_analysis.checked_report(files)

    def test_json_output_create_only(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "map.json"
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(flash_analysis.main([
                    "--input", str(self.directory), "--json-out", str(output)]), 0)
            result = json.loads(output.read_text(encoding="utf-8"))
            self.assertFalse(result["write_authorized"])
            original = output.read_bytes()
            with contextlib.redirect_stdout(io.StringIO()), \
                 contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(flash_analysis.main([
                    "--input", str(self.directory), "--json-out", str(output)]), 1)
            self.assertEqual(output.read_bytes(), original)

    def test_empty_all_ff_image(self):
        result = flash_analysis.sector_map(b"\xff" * flash_analysis.FLASH_BYTES)
        self.assertEqual(result["all_ff_sectors"], 1024)
        self.assertIsNone(result["first_non_ff_offset"])
        self.assertIsNone(result["last_non_ff_offset"])
        self.assertEqual(result["non_ff_sector_ranges_end_exclusive"], [])


if __name__ == "__main__":
    unittest.main(verbosity=2)
