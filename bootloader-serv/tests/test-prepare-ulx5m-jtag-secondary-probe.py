#!/usr/bin/env python3
"""Offline regressions for create-only JTAG secondary-boot candidate gate."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
path = HERE / 'prepare-ulx5m-jtag-secondary-probe.py'
spec = importlib.util.spec_from_file_location('v43_prepare_probe', path)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class ProbeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Small synthetic fixtures; hashes are re-pinned only in each test.
        cls.reference_bytes = b'X' * 256 + b'\0\0'
        cls.implementation_bytes = b'implementation fixture'

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.ref = self.root / 'source.bit'
        self.impl = self.root / 'source.txt'
        self.out = self.root / 'candidate.bit'
        self.ref.write_bytes(self.reference_bytes)
        self.impl.write_bytes(self.implementation_bytes)
        self.originals = (mod.EXPECTED_SOURCE_BIT_SIZE,
                          mod.EXPECTED_SOURCE_BIT_SHA,
                          mod.EXPECTED_SOURCE_IMPL_SIZE,
                          mod.EXPECTED_SOURCE_IMPL_SHA)
        mod.EXPECTED_SOURCE_BIT_SIZE = len(self.reference_bytes)
        mod.EXPECTED_SOURCE_BIT_SHA = mod.sha(self.reference_bytes)
        mod.EXPECTED_SOURCE_IMPL_SIZE = len(self.implementation_bytes)
        mod.EXPECTED_SOURCE_IMPL_SHA = mod.sha(self.implementation_bytes)
        self.addCleanup(self.restore)

    def restore(self):
        (mod.EXPECTED_SOURCE_BIT_SIZE, mod.EXPECTED_SOURCE_BIT_SHA,
         mod.EXPECTED_SOURCE_IMPL_SIZE, mod.EXPECTED_SOURCE_IMPL_SHA) = self.originals

    def runner(self, cmd, **kwargs):
        if '--reconfig' not in cmd:
            raise AssertionError("pinned source requires gmpack --reconfig")
        if '--bootaddr' in cmd:
            data = self.reference_bytes[:-2] + b'\0\0' + mod.EXPECTED_COMMAND_PAIR + b'\0\0'
        else:
            data = self.reference_bytes
        Path(cmd[-1]).write_bytes(data)
        return subprocess.CompletedProcess(cmd, 0, '', '')

    def fake_parser(self, candidate, offset):
        if candidate[offset:offset+7] == mod.EXPECTED_COMMAND_PAIR[:7]:
            return {'command': 'CMD_CFGRST', 'payload_hex': '00'}
        if candidate[offset:offset+10] == mod.EXPECTED_COMMAND_PAIR[7:]:
            return {'command': 'CMD_JUMP', 'target_le': '0x00201000'}
        return None

    def run_create(self, runner=None):
        original = mod.parse_gatemate_command
        mod.parse_gatemate_command = self.fake_parser
        try:
            return mod.create(self.ref, self.impl, self.out, runner=runner or self.runner)
        finally:
            mod.parse_gatemate_command = original

    def test_reconfig_flags_used_for_both_packer_runs(self):
        commands = []

        def recording_runner(cmd, **kwargs):
            commands.append(cmd)
            return self.runner(cmd, **kwargs)

        self.run_create(recording_runner)
        self.assertEqual(len(commands), 2)
        self.assertEqual(commands[0][1:2], ['--reconfig'])
        self.assertEqual(commands[1][1:4],
                         ['--reconfig', '--bootaddr', str(mod.TARGET)])

    def test_valid_create_only(self):
        result = self.run_create()
        self.assertEqual(result['target'], '0x201000')
        self.assertEqual(self.out.stat().st_size, len(self.reference_bytes) + 19)

    def test_reject_existing_destination(self):
        self.out.write_bytes(b'preserve')
        with self.assertRaises(FileExistsError):
            self.run_create()
        self.assertEqual(self.out.read_bytes(), b'preserve')

    def test_bad_reference_rejected(self):
        self.ref.write_bytes(b'bad')
        with self.assertRaises(ValueError):
            self.run_create()
        self.assertFalse(self.out.exists())

    def test_bad_implementation_rejected(self):
        self.impl.write_bytes(b'bad')
        with self.assertRaises(ValueError):
            self.run_create()
        self.assertFalse(self.out.exists())

    def test_default_must_match_pinned(self):
        def invalid(cmd, **kwargs):
            result = self.runner(cmd, **kwargs)
            if '--bootaddr' not in cmd:
                Path(cmd[-1]).write_bytes(b'invalid')
            return result
        with self.assertRaises(ValueError):
            self.run_create(invalid)
        self.assertFalse(self.out.exists())

    def test_bad_tail_rejected(self):
        def invalid(cmd, **kwargs):
            result = self.runner(cmd, **kwargs)
            if '--bootaddr' in cmd:
                data = Path(cmd[-1]).read_bytes()
                Path(cmd[-1]).write_bytes(data[:-5] + b'BAD!!')
            return result
        with self.assertRaises(ValueError):
            self.run_create(invalid)
        self.assertFalse(self.out.exists())

    def test_missing_parent_rejected(self):
        self.out = self.root / 'missing' / 'candidate.bit'
        with self.assertRaises(ValueError):
            self.run_create()

    def test_reject_body_modification(self):
        large = b'A' * 200 + b'\0\0'
        with self.assertRaises(ValueError):
            mod.check_candidate(large, b'Z' + large[1:-2] + mod.EXPECTED_COMMAND_PAIR + b'\0\0')

    def test_reject_wrong_target(self):
        # Disturb CRC-protected target field without repacking CRC.
        modified = bytearray(mod.EXPECTED_COMMAND_PAIR)
        modified[13] ^= 1
        with self.assertRaises(ValueError):
            mod.check_candidate(self.reference_bytes,
                                self.reference_bytes[:-2] + b'\0\0' + bytes(modified) + b'\0\0')


if __name__ == '__main__':
    unittest.main(verbosity=2)
