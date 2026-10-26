#!/usr/bin/env python3
"""Host-only tests for guarded ULX5M JTAG flash write qualification."""

import importlib.util
import json
import os
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).with_name("qualify-ulx5m-serv-jtag-write.py")
spec = importlib.util.spec_from_file_location("ulx5m_jtag_write_qualification", SCRIPT)
q = importlib.util.module_from_spec(spec)
spec.loader.exec_module(q)
REAL_CHECK_LOADER = q.check_loader
REAL_WINDOWS_FILE_ARGUMENT = q.windows_file_argument


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
        self.app_sector = bytes([0x5A]) * q.APP_SECTOR_BYTES
        self.live = q.expected_current_flash(self.backup, self.app_sector)
        self.digest = q.sha(self.backup)
        self.loader = self.dir / "openFPGALoader.exe"
        self.loader.write_bytes(b"test-binary")
        self.fake = FakeJtag(self.live)
        self.report = self.dir / "report.json"
        self.patch = patch.object(q, "verified_backup", return_value=(self.backup, self.digest))
        self.patch.start()
        self.addCleanup(self.patch.stop)
        self.mockloader = patch.object(q, "check_loader", return_value=q.UPSTREAM_LOADER_SHA256)
        self.mockloader.start()
        self.addCleanup(self.mockloader.stop)
        self.mocksector = patch.object(q, "verified_app_sector", return_value=self.app_sector)
        self.mocksector.start()
        self.addCleanup(self.mocksector.stop)
        self.mockcall = patch.object(q, "call", side_effect=self.fake.call)
        self.mockcall.start()
        self.addCleanup(self.mockcall.stop)
        # The fake JTAG device is host-native and does not require WSL paths.
        self.mockpath = patch.object(q, "windows_file_argument", side_effect=str)
        self.mockpath.start()
        self.addCleanup(self.mockpath.stop)

    def argv(self, *args):
        return ["--backup-dir", str(self.backup_dir), "--loader", str(self.loader),
                "--report", str(self.report), *args]

    def report_data(self):
        return json.loads(self.report.read_text(encoding="ascii"))

    def test_discover_single_valid_factory_backup(self):
        base = self.dir / "bootloader-serv" / "build-ulx5m-gs.bak"
        candidate = base / "flash-backup-sample"
        candidate.mkdir(parents=True)
        (candidate / "flash-pass1.bin").write_bytes(self.backup)
        (candidate / "flash-pass2.bin").write_bytes(self.backup)
        with patch.object(q, "FACTORY_SHA256", q.sha(self.backup)):
            self.assertEqual(q.discover_backup(self.dir), candidate)

    def test_discover_rejects_missing_corrupt_and_ambiguous_backups(self):
        base = self.dir / "bootloader-serv" / "build-ulx5m-gs.bak"
        candidate = base / "one"
        candidate.mkdir(parents=True)
        (candidate / "flash-pass1.bin").write_bytes(self.backup)
        with patch.object(q, "FACTORY_SHA256", q.sha(self.backup)):
            with self.assertRaisesRegex(ValueError, "found 0"):
                q.discover_backup(self.dir)
            (candidate / "flash-pass2.bin").write_bytes(b"corrupt")
            with self.assertRaisesRegex(ValueError, "found 0"):
                q.discover_backup(self.dir)
            (candidate / "flash-pass2.bin").write_bytes(self.backup)
            second = base / "two"
            second.mkdir()
            (second / "flash-pass1.bin").write_bytes(self.backup)
            (second / "flash-pass2.bin").write_bytes(self.backup)
            with self.assertRaisesRegex(ValueError, "found 2"):
                q.discover_backup(self.dir)

    def test_auto_report_is_under_repository_and_unique(self):
        first = q.default_report(self.dir, "readonly")
        second = q.default_report(self.dir, "readonly")
        self.assertEqual(first.parent, self.dir / "bootloader-serv" / "build-ulx5m-gs")
        self.assertNotEqual(first, second)
        self.assertTrue(first.name.startswith("v54-jtag-readonly-"))
        self.assertEqual(first.suffix, ".json")

    def test_optional_paths_autoresolve_but_never_write_without_ack(self):
        with patch.object(q, "discover_backup", return_value=self.backup_dir), \
                patch.object(q, "default_report", return_value=self.report):
            self.assertEqual(q.main(["--loader", str(self.loader),
                                     "--sector-dump", str(self.dir / "sector.bin")]), 0)
            self.assertFalse(self.fake.commands)
            self.assertFalse(self.report.exists())
            self.assertEqual(q.main(["--loader", str(self.loader),
                                     "--write-test"]), 1)
            self.assertFalse(self.fake.commands)

    def test_reject_corrupt_secondary_sector(self):
        with patch.object(q, "verified_app_sector", side_effect=ValueError("wrong sector")):
            self.assertEqual(q.main(self.argv("--run")), 1)
        self.assertFalse(self.fake.commands)

    def test_loader_preflight_requires_live_secondary_match(self):
        self.fake.flash[q.APP_SECTOR_ADDRESS] ^= 0x10
        self.assertEqual(q.main(self.argv("--run")), 1)
        self.assertEqual(self.fake.write_count, 0)

    def test_reject_loader_with_rx_shift_patch_hash(self):
        with patch.object(q, "check_loader", side_effect=ValueError("RX patched loader rejected")):
            self.assertEqual(q.main(self.argv("--run")), 1)
        self.assertFalse(self.fake.commands)

    def test_verify_real_loader_digest(self):
        with patch.object(q, "UPSTREAM_LOADER_SHA256", q.sha(b"upstream-fixture")):
            self.loader.write_bytes(b"upstream-fixture")
            self.assertEqual(REAL_CHECK_LOADER(self.loader), q.sha(b"upstream-fixture"))
            self.loader.write_bytes(b"rx-patch-fixture")
            with self.assertRaisesRegex(ValueError, "not the verified"):
                REAL_CHECK_LOADER(self.loader)

    def test_mutating_clock_must_be_100khz(self):
        self.assertEqual(q.main(self.argv("--freq-khz", "1000", "--write-test", 
                                           "--confirm-write", q.ACK)), 1)
        self.assertFalse(self.fake.commands)

    def test_default_never_calls_loader(self):
        self.assertEqual(q.main(self.argv()), 0)
        self.assertFalse(self.fake.commands)
        self.assertFalse(self.report.exists())

    def test_read_only_preflight(self):
        self.assertEqual(q.main(self.argv("--run")), 0)
        self.assertEqual(self.report_data()["phase"], "read_only_preflight_passed")
        self.assertEqual(sum("--dump-flash" in c for c in self.fake.commands), 6)
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

    def test_detect_accepts_upstream_index_without_found_summary(self):
        with patch.object(q, "call", return_value=("Jtag frequency : requested 100kHz\n"
                                                   "index 0:\n idcode 0x20000001\n")):
            q.detect(self.loader, 100)

    def test_detect_rejects_extra_jtag_device(self):
        with patch.object(q, "call", return_value=("index 0:\n idcode 0x20000001\n"
                                                   "index 1:\n idcode 0x20000001\n")):
            with self.assertRaisesRegex(ValueError, "Expected exactly one"):
                q.detect(self.loader, 100)

    def test_wrong_idcode_refuses_all_reads_and_writes(self):
        with patch.object(q, "call", return_value="found 0 devices"):
            self.assertEqual(q.main(self.argv("--run")), 1)
        self.assertEqual(self.report_data()["phase"], "preflight_failed_no_flash_write")

    def test_one_sector_write_and_restore(self):
        self.assertEqual(q.main(self.argv("--write-test", "--confirm-write", q.ACK)), 0)
        self.assertEqual(self.fake.write_count, 2)
        self.assertEqual(self.fake.flash, bytearray(self.live))
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
        self.assertEqual(self.fake.flash, bytearray(self.live))
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
        self.assertEqual(self.fake.flash, bytearray(self.live))
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


    def test_wsl_dump_file_uses_windows_drive_path(self):
        """Regression: Linux /tmp must never reach the native Windows .exe."""
        source = Path("/mnt/c/workspace/Hazard3-Doom/read-000000.bin")
        seen = []

        def runner(cmd, **kwargs):
            seen.append(cmd)
            if cmd[0] == "wslpath":
                self.assertEqual(cmd, ["wslpath", "-w", str(source)])
                return SimpleNamespace(returncode=0,
                                       stdout="C:\\workspace\\Hazard3-Doom\\read-000000.bin\n",
                                       stderr="")
            self.assertIn("--dump-flash", cmd)
            self.assertEqual(cmd[-1], "C:\\workspace\\Hazard3-Doom\\read-000000.bin")
            return SimpleNamespace(returncode=0,
                                   stdout="Read Flash JEDEC ID: 0x1f4216", stderr="")

        self.mockcall.stop()
        self.mockpath.stop()
        with patch.dict(os.environ, {"WSL_DISTRO_NAME": "Ubuntu"}):
            with patch.object(q.subprocess, "run", side_effect=runner):
                output = q.call(q.read_cmd(self.loader, 100, 0, 4096, source))
        self.assertIn("0x1f4216", output)
        self.assertEqual(len(seen), 2)

    def test_wsl_non_drive_file_fails_before_programmer(self):
        self.mockpath.stop()
        runner = []

        def fake_run(cmd, **kwargs):
            runner.append(cmd)
            return SimpleNamespace(returncode=0,
                                   stdout="\\wsl.localhost\\Ubuntu\\tmp\\read.bin\n", stderr="")

        with patch.dict(os.environ, {"WSL_DISTRO_NAME": "Ubuntu"}):
            with patch.object(q.subprocess, "run", side_effect=fake_run):
                with self.assertRaisesRegex(ValueError, "Windows-mounted drive"):
                    REAL_WINDOWS_FILE_ARGUMENT(Path("/tmp/read.bin"))
        self.assertEqual(len(runner), 1)
        self.assertEqual(runner[0][0], "wslpath")

    def test_read_temp_directory_is_under_project_build(self):
        root = q.HERE.parent / "build-ulx5m-gs"
        self.mockcall.stop()
        seen = []

        def fake_call(cmd, timeout=120):
            if "--dump-flash" not in cmd:
                raise AssertionError("Unexpected command")
            output = Path(cmd[-1])
            self.assertTrue(output.is_relative_to(root))
            seen.append(output)
            output.write_bytes(bytes([0xff]) * 4096)
            return "Read Flash JEDEC ID: 0x1f4216"

        with patch.object(q, "call", side_effect=fake_call):
            self.assertEqual(q.read_region(self.loader, 100, 0, 4096), bytes([0xff]) * 4096)
        self.assertEqual(len(seen), 1)
        self.assertFalse(seen[0].exists())

    def test_write_test_refuses_unreachable_windows_report_path(self):
        self.mockpath.stop()
        with patch.object(q, "windows_file_argument",
                          side_effect=ValueError("not a Windows-mounted drive")):
            self.assertEqual(q.main(self.argv("--write-test", "--confirm-write", q.ACK)), 1)
        self.assertEqual(self.fake.commands, [])
        self.assertEqual(self.fake.write_count, 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
