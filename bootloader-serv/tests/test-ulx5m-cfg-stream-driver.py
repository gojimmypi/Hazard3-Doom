#!/usr/bin/env python3
"""Host tests for offline HDL-stream replay driver, without invoking Icarus."""

import hashlib
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location(
    'ulx5m_cfg_stream_driver', HERE / 'test-ulx5m-cfg-stream-payload.py')
DRIVER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(DRIVER)


class StreamDriverTests(unittest.TestCase):
    def setUp(self):
        self.work = tempfile.TemporaryDirectory(prefix='ulx5m-stream-driver-')
        self.addCleanup(self.work.cleanup)
        self.bit = Path(self.work.name) / 'fixture.bit'
        self.data = bytes.fromhex('d901ed96') + bytes(range(20))
        self.bit.write_bytes(self.data)
        self.sha = hashlib.sha256(self.data).hexdigest()

    def test_sha_guard(self):
        with self.assertRaisesRegex(ValueError, 'SHA-256 mismatch'):
            DRIVER.check_fixture(self.bit, '0' * 64)

    def test_invalid_magic(self):
        self.bit.write_bytes(b'XXXX' + self.data[4:])
        actual_sha = hashlib.sha256(self.bit.read_bytes()).hexdigest()
        with self.assertRaisesRegex(ValueError, 'Not a bounded raw GateMate'):
            DRIVER.check_fixture(self.bit, actual_sha)

    def test_no_icarus_is_hard_failure(self):
        with patch.object(DRIVER.shutil, 'which', return_value=None):
            with self.assertRaisesRegex(RuntimeError, 'Icarus Verilog'):
                DRIVER.run_offline(self.bit, self.sha)

    def test_exact_bytes_and_abort_argument_forwarded(self):
        calls = []

        def fake_run(cmd, **kwargs):
            calls.append(cmd)
            if cmd[0] == 'vvp':
                hex_path = next(x[5:] for x in cmd if x.startswith('+HEX='))
                actual = bytes(int(x, 16) for x in Path(hex_path).read_text().splitlines())
                self.assertEqual(actual, self.data)
                self.assertIn(f'+SIZE={len(self.data)}', cmd)
                self.assertIn('+ABORT_AFTER=12', cmd)
            return subprocess.CompletedProcess(cmd, 0)

        with patch.object(DRIVER.shutil, 'which', return_value='/mock/iverilog'):
            with patch.object(DRIVER.subprocess, 'run', side_effect=fake_run):
                DRIVER.run_offline(self.bit, self.sha, abort_after=12)
        self.assertEqual([cmd[0] for cmd in calls], ['iverilog', 'vvp'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
