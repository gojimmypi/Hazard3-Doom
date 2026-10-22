#!/usr/bin/env python3
"""Host-only tests for guarded ULX5M JTAG flash write qualification."""

import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).with_name("qualify-ulx5m-serv-jtag-write.py")
spec = importlib.util.spec_from_file_location("ulx5m_jtag_write_qualification", SCRIPT)
q = importlib.util.module_from_spec(spec)
spec.loader.exec_module(q)


class FakeJtag:
    def __init__(self, initial):
        self.flash = bytearray(initial)
        self.commands = []
        self.write_count = 0
        self.fail_test_write = False
        self.fail_restore = False
        self.lost_chain = False

    def call(self, cmd, timeout=120):
        self.commands.append(cmd[:])
        if "--detect" in cmd:
            if self.lost_chain:
                return "Jtag frequency : requested 1.00MHz\nfound 0 devices"
            return ("Jtag frequency : requested 1.00MHz\nfound 1 devices\n"
                    "index 0:\n idcode 0x20000001\n")
        if "--dump-flash" in cmd:
            addr = int(cmd[cmd.index("--offset") + 1])
            size = int(cmd[cmd.index("--file-size") + 1])
            Path(cmd[-1]).write_bytes(self.flash[addr:addr + size])
            return "Read Flash JEDEC ID: 0x1f4216\nRead flash: 100%"
        if "-f" in cmd:
            addr = int(cmd[cmd.index("--offset") + 1])
            self.write_count += 1
            data = Path(cmd[-1]).read_bytes()
            if self.fail_test_write and self.write_count == 1:
                self.flash[addr:addr + 32] = data[:32]
                raise ValueError("Injected write failure after first 32 bytes")
            if self.fail_restore and self.write_count >= 2:
                raise ValueError("Injected restoration failure")
            # Model a 64 KiB erase granularity as a conservative case.
            base = addr & ~0xFFFF
            self.flash[base:base + 0x10000] = bytes([255]) * 0x10000
            self.flash[addr:addr + len(data)] = data
            return "Read Flash JEDEC ID: 0x1f4216\nWrite and verify done"
        raise AssertionError(f"Unapproved command: {cmd}")


class WriteQualifyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name)
        self.backup_dir = self.dir / "backup"
        self.backup_dir.mkdir()
        self.backup = bytes([255]) * q.FLASH_BYTES
        self.digest = q.sha(self.backup)
        self.loader = self.dir / "openFPGALoader.exe"
        self.loader.write_bytes(b"test-binary")
        self.fake = FakeJtag(self.backup)
        self.report = self.dir / "report.json"
        self.patch = patch.object(q, "verified_backup", return_value=(self.backup, self.digest))
        self.patch.start()
        self.addCleanup(self.patch.stop)
        self.mockcall = patch.object(q, "call", side_effect=self.fake.call)
        self.mockcall.start()
        self.addCleanup(self.mockcall.stop)

    def argv(self, *args):
        return ["--backup-dir", str(self.backup_dir), "--loader", str(self.loader),
                "--report", str(self.report), *args]

    def report_data(self):
        return json.loads(self.report.read_text(encoding="ascii"))

    def test_default_never_calls_loader(self):
        self.assertEqual(q.main(self.argv()), 0)
        self.assertFalse(self.fake.commands)
        self.assertFalse(self.report.exists())

    def test_read_only_preflight(self):
        self.assertEqual(q.main(self.argv("--run")), 0)
        self.assertEqual(self.report_data()["phase"], "read_only_preflight_passed")
        self.assertEqual(sum("--dump-flash" in c for c in self.fake.commands), 5)
        self.assertEqual(sum("-f" in c for c in self.fake.commands), 0)

    def test_explicit_ack_required(self):
        self.assertEqual(q.main(self.argv("--write-test")), 1)
        self.assertFalse(self.fake.commands)

    def test_protection_on_bad_backup_region(self):
        bad = bytearray(self.backup)
        bad[q.BASE] = 0
        with patch.object(q, "verified_backup", side_effect=ValueError("not erased")):
            self.assertEqual(q.main(self.argv("--run")), 1)
        self.assertFalse(self.fake.commands)

    def test_reject_existing_report_and_files(self):
        self.report.write_text("{}")
        self.assertEqual(q.main(self.argv("--run")), 1)
        self.assertFalse(self.fake.commands)

    def test_invalid_freq_fails_before_loader(self):
        self.assertEqual(q.main(self.argv("--freq-khz", "-1", "--run")), 1)
        self.assertFalse(self.fake.commands)

    def test_wrong_idcode_refuses_all_reads_and_writes(self):
        with patch.object(q, "call", return_value="found 0 devices"):
            self.assertEqual(q.main(self.argv("--run")), 1)
        self.assertEqual(self.report_data()["phase"], "preflight_failed_no_flash_write")

    def test_one_sector_write_and_restore(self):
        self.assertEqual(q.main(self.argv("--write-test", "--confirm-write", q.ACK)), 0)
        self.assertEqual(self.fake.write_count, 2)
        self.assertEqual(self.fake.flash, bytearray(self.backup))
        self.assertEqual(self.report_data()["phase"], "restored_and_verified")
        self.assertTrue(self.report_data()["restored"])
        files = q.artifact_dir(self.report)
        self.assertEqual((files / "original-3ff000.bin").read_bytes(), self.backup[q.BASE:])
        self.assertEqual((files / "test-pattern-3ff000.bin").stat().st_size, 4096)
        for cmd in self.fake.commands:
            self.assertNotIn("--bulk-erase", cmd)
            self.assertNotIn("--unprotect-flash", cmd)
            if "-f" in cmd:
                self.assertIn("--verify", cmd)
                self.assertEqual(int(cmd[cmd.index("--offset") + 1]), q.BASE)

    def test_interrupted_test_write_still_restores(self):
        self.fake.fail_test_write = True
        self.assertEqual(q.main(self.argv("--write-test", "--confirm-write", q.ACK)), 1)
        self.assertEqual(self.fake.write_count, 2)
        self.assertEqual(self.fake.flash, bytearray(self.backup))
        self.assertTrue(self.report_data()["restored"])

    def test_restore_failure_keeps_recovery_data_and_resume(self):
        self.fake.fail_restore = True
        self.assertEqual(q.main(self.argv("--write-test", "--confirm-write", q.ACK)), 1)
        files = q.artifact_dir(self.report)
        self.assertTrue(files.exists())
        self.assertEqual(self.report_data()["phase"], "RESTORE_UNVERIFIED_MANUAL_RECOVERY_NEEDED")
        self.fake.fail_restore = False
        second = self.dir / "restore-report.json"
        self.assertEqual(q.main(["--backup-dir", str(self.backup_dir),
                                 "--loader", str(self.loader), "--report", str(second),
                                 "--restore-only", str(files),
                                 "--confirm-write", q.ACK]), 0)
        self.assertEqual(self.fake.flash, bytearray(self.backup))
        self.assertTrue(json.loads(second.read_text())["restored"])

    def test_readback_mismatch_fails_without_write(self):
        self.fake.flash[0x3FE000] = 0
        self.assertEqual(q.main(self.argv("--write-test", "--confirm-write", q.ACK)), 1)
        self.assertEqual(self.fake.write_count, 0)

    def test_write_command_bounds_and_suffix(self):
        small = self.dir / "test.bin"
        small.write_bytes(bytes(256))
        with self.assertRaises(ValueError):
            q.write_cmd(self.loader, 1000, small)
        small.write_bytes(bytes(4096))
        with self.assertRaises(ValueError):
            q.write_cmd(self.loader, 1000, small, 0x000000)
        self.assertIn("-f", q.write_cmd(self.loader, 1000, small))


if __name__ == "__main__":
    unittest.main(verbosity=2)
