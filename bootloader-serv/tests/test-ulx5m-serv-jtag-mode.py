#!/usr/bin/env python3
"""Host mock tests for read-only JTAG recovery mode analysis."""

import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).with_name("probe-ulx5m-serv-jtag-mode.py")
spec = importlib.util.spec_from_file_location("ulx5m_jtag_mode", SOURCE)
mode = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mode)


class ModeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.backup = self.root / "backup"
        self.backup.mkdir()
        data = bytes(range(256)) * (mode._recovery.FLASH_SIZE // 256)
        digest = hashlib.sha256(data).hexdigest()
        for i in (1, 2):
            (self.backup / f"flash-pass{i}.bin").write_bytes(data)
        (self.backup / "flash-backup-report.json").write_text(json.dumps({
            "format": "ULX5M-GS SERV flash-backup-v1",
            "device_jedec_hex": "1f4216", "size_bytes": mode._recovery.FLASH_SIZE,
            "byte_for_byte_match": True,
            "passes": [{"file": f"flash-pass{i}.bin", "sha256": digest}
                       for i in (1, 2)]
        }), encoding="utf-8")
        self.loader = self.root / "openFPGALoader.exe"
        self.loader.write_bytes(b"mock")
        self.report = self.root / "state.json"

    def args(self, *extra):
        return ["--backup-dir", str(self.backup), "--state", "sram-loaded",
                "--report", str(self.report), "--loader", str(self.loader), *extra]

    def silent(self, *extra):
        with contextlib.redirect_stdout(io.StringIO()), \
             contextlib.redirect_stderr(io.StringIO()):
            return mode.main(self.args(*extra))

    def mock_run(self, cmd, **kwargs):
        self.assertEqual(kwargs.get('check'), False)
        self.assertTrue(kwargs.get('capture_output'))
        self.assertTrue(kwargs.get('text'))
        if '--detect' in cmd:
            return type('P', (), {'returncode': 0, 'stdout': ('Jtag frequency : requested 1.00MHz    -> real 1.00MHz\n'
                                                   'index 0:\n'
                                                   '\tidcode 0x20000001\n'
                                                   '\tmanufacturer colognechip\n'
                                                   '\tfamily GateMate Series\n'
                                                   '\tmodel GM1Ax\n'),
                                  'stderr': ''})()
        self.assertIn('--dump-flash', cmd)
        self.assertEqual(int(cmd[cmd.index('--file-size') + 1]), 4096)
        self.assertEqual(int(cmd[cmd.index('--offset') + 1]), 0)
        Path(cmd[-1]).write_bytes((self.backup / 'flash-pass1.bin').read_bytes()[:4096])
        return type('P', (), {'returncode': 0, 'stdout': 'Done', 'stderr': ''})()

    def test_dry_run_never_calls_programmer(self):
        with patch.object(mode.subprocess, 'run') as runner:
            self.assertEqual(self.silent(), 0)
            runner.assert_not_called()
        self.assertFalse(self.report.exists())

    def test_allowed_commands_read_only(self):
        detect, dump = mode.commands(self.loader, 1000, self.root / 'chunk')
        self.assertIn('--detect', detect)
        self.assertIn('-v', detect)
        self.assertIn('--dump-flash', dump)
        self.assertTrue(all(not (set(command) & mode.FORBIDDEN)
                            for command in (detect, dump)))
        self.assertNotIn('--reset', ' '.join(detect + dump))

    def test_successful_detection_and_read(self):
        with patch.object(mode.subprocess, 'run', side_effect=self.mock_run) as runner:
            self.assertEqual(self.silent('--run'), 0)
            self.assertEqual(runner.call_count, 2)
        report = json.loads(self.report.read_text(encoding='utf-8'))
        self.assertTrue(report['jtag_detect']['ok'])
        self.assertEqual(report['jtag_detect']['idcodes'], ['0x20000001'])
        self.assertTrue(report['jtag_detect']['gatemate_found'])
        self.assertTrue(report['flash_read']['ok'])
        self.assertEqual(report['flash_read']['length'], 4096)
        self.assertTrue(report['readonly'])

    def test_detect_empty_chain_exits_zero_but_must_fail(self):
        def run(cmd, **kwargs):
            if '--detect' in cmd:
                return type('P', (), {'returncode': 0,
                                      'stdout': 'Jtag frequency : requested 1.00MHz -> real 1.00MHz\n',
                                      'stderr': ''})()
            return self.mock_run(cmd, **kwargs)
        with patch.object(mode.subprocess, 'run', side_effect=run) as runner:
            self.assertEqual(self.silent('--run'), 1)
            self.assertEqual(runner.call_count, 1)
        report = json.loads(self.report.read_text(encoding='utf-8'))
        self.assertFalse(report['jtag_detect']['ok'])
        self.assertFalse(report['jtag_detect']['gatemate_found'])
        self.assertEqual(report['jtag_detect']['jtag_indices'], [])
        self.assertIn('exited 0', report['jtag_detect']['reason'])
        self.assertFalse(report['flash_read']['ok'])
        self.assertTrue(report['flash_read']['skipped'])
        self.assertIn('RST_N', report['flash_read']['detail'])

    def test_detect_unrecognized_device_exits_zero_but_must_fail(self):
        def run(cmd, **kwargs):
            if '--detect' in cmd:
                return type('P', (), {'returncode': 0,
                                      'stdout': ('index 0:\n\tidcode 0x41111043\n'
                                                 '	manufacturer lattice\n'),
                                      'stderr': ''})()
            return self.mock_run(cmd, **kwargs)
        with patch.object(mode.subprocess, 'run', side_effect=run):
            self.assertEqual(self.silent('--run'), 0)
        report = json.loads(self.report.read_text(encoding='utf-8'))
        self.assertFalse(report['jtag_detect']['ok'])
        self.assertEqual(report['jtag_detect']['idcodes'], ['0x41111043'])
        self.assertIn('GateMate', report['jtag_detect']['reason'])

    def test_detect_fails_but_flash_read_still_probed(self):
        def run(cmd, **kwargs):
            if '--detect' in cmd:
                return type('P', (), {'returncode': 1,
                                      'stdout': ('index 0:\n'
                                                 '  idcode 0x20000001\n'
                                                 'Error: scan failed'), 'stderr': ''})()
            return self.mock_run(cmd, **kwargs)
        with patch.object(mode.subprocess, 'run', side_effect=run) as runner:
            self.assertEqual(self.silent('--run'), 0)
            self.assertEqual(runner.call_count, 2)
        report = json.loads(self.report.read_text())
        self.assertFalse(report['jtag_detect']['ok'])
        self.assertTrue(report['flash_read']['ok'])

    def test_sram_loaded_empty_chain_is_not_an_spi_failure(self):
        def empty(cmd, **kwargs):
            self.assertIn('--detect', cmd)
            return type('P', (), {'returncode': 0,
                                  'stdout': 'found 0 devices\n',
                                  'stderr': ''})()
        with patch.object(mode.subprocess, 'run', side_effect=empty) as runner:
            self.assertEqual(self.silent('--run'), 1)
            self.assertEqual(runner.call_count, 1)
        report = json.loads(self.report.read_text(encoding='utf-8'))
        self.assertTrue(report['flash_read']['skipped'])
        self.assertIsNone(report['flash_read']['returncode'])
        self.assertTrue(report['readonly'])

    def test_jtag_no_device_found_preserves_report(self):
        def no_device(cmd, **kwargs):
            return type('P', (), {'returncode': 1,
                                  'stdout': 'Error: no device found', 'stderr': ''})()
        with patch.object(mode.subprocess, 'run', side_effect=no_device) as runner:
            self.assertEqual(self.silent('--run'), 1)
            self.assertEqual(runner.call_count, 1)
        report = json.loads(self.report.read_text())
        self.assertFalse(report['flash_read']['ok'])
        self.assertTrue(report['flash_read']['skipped'])
        self.assertFalse(report['jtag_detect']['ok'])

    def test_mismatch_returns_failure_and_report(self):
        def mismatch(cmd, **kwargs):
            result = self.mock_run(cmd, **kwargs)
            if '--dump-flash' in cmd:
                Path(cmd[-1]).write_bytes(bytes([0xff]) * 4096)
            return result
        with patch.object(mode.subprocess, 'run', side_effect=mismatch):
            self.assertEqual(self.silent('--run'), 1)
        report = json.loads(self.report.read_text())
        self.assertIn('0x000000', report['flash_read']['detail'])

    def test_existing_report_does_not_run(self):
        self.report.write_bytes(b'original')
        with patch.object(mode.subprocess, 'run') as runner:
            self.assertEqual(self.silent('--run'), 1)
            runner.assert_not_called()
        self.assertEqual(self.report.read_bytes(), b'original')

    def test_bad_backup_does_not_run(self):
        with (self.backup / 'flash-pass2.bin').open('r+b') as f:
            f.write(b'bad')
        with patch.object(mode.subprocess, 'run') as runner:
            self.assertEqual(self.silent('--run'), 1)
            runner.assert_not_called()
        self.assertFalse(self.report.exists())

    def test_bad_frequency_refused(self):
        for frequency in (-1, 0, 10001):
            with self.assertRaises(ValueError):
                mode.commands(self.loader, frequency, self.root / 'tmp')

    def test_timeout_is_failure(self):
        from subprocess import TimeoutExpired
        with patch.object(mode.subprocess, 'run', side_effect=TimeoutExpired('openFPGALoader', 120)):
            result = mode.execute(['fake', '--detect'])
        self.assertFalse(result['ok'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
