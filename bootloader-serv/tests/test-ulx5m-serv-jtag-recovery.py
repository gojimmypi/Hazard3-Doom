#!/usr/bin/env python3
"""Host-only regression for the chunked JTAG recovery-read preflight."""

import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

MODULE_PATH = Path(__file__).with_name("check-ulx5m-serv-jtag-recovery.py")
spec = importlib.util.spec_from_file_location("ulx5m_jtag_recovery", MODULE_PATH)
recovery = importlib.util.module_from_spec(spec)
spec.loader.exec_module(recovery)


class RecoveryReadTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.backup = self.root / "backup"
        self.backup.mkdir()
        # Tests use a synthetic valid 4 MiB fixture; never include factory data.
        content = bytes(range(256)) * (recovery.FLASH_SIZE // 256)
        digest = hashlib.sha256(content).hexdigest()
        for i in (1, 2):
            (self.backup / f"flash-pass{i}.bin").write_bytes(content)
        report = {
            "format": "ULX5M-GS SERV flash-backup-v1",
            "device_jedec_hex": "1f4216",
            "size_bytes": recovery.FLASH_SIZE,
            "byte_for_byte_match": True,
            "passes": [{"file": f"flash-pass{i}.bin", "sha256": digest} for i in (1, 2)],
        }
        (self.backup / "flash-backup-report.json").write_text(json.dumps(report), encoding="utf-8")
        self.loader = self.root / "openFPGALoader.exe"
        self.loader.write_bytes(b"mock executable")
        self.output = self.root / "out.bin"

    def args(self, *more):
        return ["--backup-dir", str(self.backup), "--output", str(self.output),
                "--loader", str(self.loader), *more]

    def run_quiet(self, args):
        with contextlib.redirect_stdout(io.StringIO()), \
             contextlib.redirect_stderr(io.StringIO()):
            return recovery.main(args)

    def mock_dump(self, cmd, check):
        self.assertFalse(check)
        self.assertEqual(cmd[cmd.index("--dump-flash")], "--dump-flash")
        self.assertIn("--offset", cmd)
        self.assertIn("--file-size", cmd)
        offset = int(cmd[cmd.index("--offset") + 1])
        size = int(cmd[cmd.index("--file-size") + 1])
        self.assertLessEqual(size, recovery.CHUNK_SIZE)
        with (self.backup / "flash-pass1.bin").open("rb") as source:
            source.seek(offset)
            Path(cmd[-1]).write_bytes(source.read(size))
        return type("Result", (), {"returncode": 0})()

    def test_preflight_does_not_launch_loader_or_create_output(self):
        with patch.object(recovery.subprocess, "run") as run:
            self.assertEqual(self.run_quiet(self.args()), 0)
            run.assert_not_called()
        self.assertFalse(self.output.exists())

    def test_only_read_arguments_allowed(self):
        cmd = recovery.build_dump_command(self.loader, self.output, 1000, 16384, 16384)
        self.assertEqual(cmd[cmd.index("--offset") + 1], "16384")
        self.assertEqual(cmd[cmd.index("--file-size") + 1], "16384")
        for forbidden in ("-f", "--write-flash", "-m", "--reset", "--bulk-erase",
                          "--unprotect-flash", "--protect-flash"):
            self.assertNotIn(forbidden, cmd)
        self.assertEqual(cmd[-1], str(self.output))
        self.assertNotIn(str(recovery.FLASH_SIZE), cmd)

    def test_chunk_limits(self):
        for size in (4096, 8192, 16384):
            recovery.validate_chunk_size(size)
        for size in (0, 128, 12288, 32768, 65536, recovery.FLASH_SIZE):
            with self.assertRaises(ValueError):
                recovery.validate_chunk_size(size)
        with self.assertRaises(ValueError):
            recovery.build_dump_command(self.loader, self.output, 1000,
                                        recovery.FLASH_SIZE - 4096, 16384)

    def test_probe_matches_and_creates_no_final_output(self):
        with patch.object(recovery.subprocess, "run", side_effect=self.mock_dump) as run:
            self.assertEqual(self.run_quiet(self.args("--probe-only")), 0)
            self.assertEqual(run.call_count, 1)
        self.assertFalse(self.output.exists())
        self.assertFalse(list(self.root.glob("ulx5m-jtag-read-*")))

    def test_full_chunked_match(self):
        with patch.object(recovery.subprocess, "run", side_effect=self.mock_dump) as run:
            self.assertEqual(self.run_quiet(self.args("--run")), 0)
            self.assertEqual(run.call_count, recovery.FLASH_SIZE // recovery.CHUNK_SIZE)
        self.assertEqual(recovery.sha256_file(self.output),
                         recovery.sha256_file(self.backup / "flash-pass1.bin"))
        self.assertFalse(self.output.with_name("out.bin.partial").exists())
        self.assertFalse(self.output.with_name("out.bin.parts").exists())

    def test_refuse_overwrite(self):
        self.output.write_bytes(b"keep")
        with patch.object(recovery.subprocess, "run") as run:
            self.assertEqual(self.run_quiet(self.args("--run")), 1)
            run.assert_not_called()
        self.assertEqual(self.output.read_bytes(), b"keep")

    def test_refuse_existing_partial(self):
        self.output.with_name("out.bin.partial").write_bytes(b"keep")
        with patch.object(recovery.subprocess, "run") as run:
            self.assertEqual(self.run_quiet(self.args("--run")), 1)
            run.assert_not_called()
        self.assertFalse(self.output.exists())
        self.assertEqual(self.output.with_name("out.bin.partial").read_bytes(), b"keep")

    def test_bad_backup_is_not_used(self):
        with (self.backup / "flash-pass2.bin").open("r+b") as stream:
            stream.write(b"corrupt")
        with patch.object(recovery.subprocess, "run") as run:
            self.assertEqual(self.run_quiet(self.args("--run")), 1)
            run.assert_not_called()

    def test_mismatched_jtag_read_rejected_and_preserved(self):
        def corrupted_dump(cmd, check):
            result = self.mock_dump(cmd, check)
            if int(cmd[cmd.index("--offset") + 1]) == recovery.CHUNK_SIZE:
                path = Path(cmd[-1])
                data = bytearray(path.read_bytes())
                data[123] ^= 0xFF
                path.write_bytes(data)
            return result

        with patch.object(recovery.subprocess, "run", side_effect=corrupted_dump) as run:
            self.assertEqual(self.run_quiet(self.args("--run")), 1)
            self.assertEqual(run.call_count, 2)
        self.assertFalse(self.output.exists())
        self.assertEqual(self.output.with_name("out.bin.partial").stat().st_size,
                         recovery.CHUNK_SIZE)
        self.assertTrue(self.output.with_name("out.bin.parts").exists())

    def test_stack_overflow_code_retained_as_failure(self):
        def crashed_dump(cmd, check):
            Path(cmd[-1]).write_bytes(b"")
            return type("Result", (), {"returncode": 3221225725})()
        with patch.object(recovery.subprocess, "run", side_effect=crashed_dump) as run:
            self.assertEqual(self.run_quiet(self.args("--run")), 1)
            self.assertEqual(run.call_count, 1)
        self.assertFalse(self.output.exists())
        self.assertTrue(self.output.with_name("out.bin.parts").exists())

    def test_short_chunk_rejected(self):
        def short_dump(cmd, check):
            Path(cmd[-1]).write_bytes(b"\x00")
            return type("Result", (), {"returncode": 0})()
        with patch.object(recovery.subprocess, "run", side_effect=short_dump):
            self.assertEqual(self.run_quiet(self.args("--probe-only")), 1)
        self.assertFalse(self.output.exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
