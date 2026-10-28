#!/usr/bin/env python3
"""No-hardware tests of pinned v75 seed-228 512KiB primary migration."""
from contextlib import ExitStack
import hashlib
import importlib.util
import json
from pathlib import Path
from unittest.mock import patch
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('v75_512k_guarded_ab', HERE / 'qualify-ulx5m-v75-512k-guarded-ab.py')
ab = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ab)


class MockJtag:
    def __init__(self, original):
        self.flash = bytearray(original)
        self.writes = []
        self.fail_next_write_readback = False
        self.corrupt_suffix = False

    def check_loader(self, loader):
        assert loader == ab.LOADER

    def detect(self, loader, freq):
        assert loader == ab.LOADER and freq == 100

    def jtag_cmd(self, loader, freq):
        assert loader == ab.LOADER and freq == 100
        return ['fake-loader', '--jtag']

    def call(self, cmd, timeout=900):
        assert cmd[:2] == ['fake-loader', '--jtag']
        assert cmd[2:6] == ['-f', '--verify', '--offset', '0']
        data = Path(cmd[6]).read_bytes()
        assert len(data) == ab.PRIMARY_BYTES and timeout == 900
        self.flash[:ab.PRIMARY_BYTES] = data
        self.writes.append(bytes(data))

    def read_region(self, loader, freq, offset, length):
        assert loader == ab.LOADER and freq == 100
        assert offset == 0 and length == ab.FLASH_BYTES
        if self.fail_next_write_readback and self.writes:
            self.fail_next_write_readback = False
            raise ValueError('injected post-write readback error')
        if self.corrupt_suffix and self.writes:
            self.flash[ab.PRIMARY_BYTES] ^= 1
            self.corrupt_suffix = False
        return bytes(self.flash)


class V75512KGuardedAB(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.v73 = ab.baseline_v73()
        cls.fake_bit = b'v75-locally-qualified' * 20000
        assert len(cls.fake_bit) <= ab.PRIMARY_BYTES
        cls.fake_sha = ab.sha(cls.fake_bit)
        cls.primary = cls.fake_bit + bytes([255]) * (ab.PRIMARY_BYTES - len(cls.fake_bit))
        cls.after = ab.proposed(cls.v73, cls.primary)

    def test_archived_v73_baseline_and_512k_boundary_are_real(self):
        self.assertEqual(len(self.v73), ab.FLASH_BYTES)
        self.assertEqual(ab.sha(self.v73), ab.V73_FULL_SHA)
        self.assertEqual(ab.sha(self.v73[:0x70000]), ab.V73_PRIMARY_448K_SHA)
        self.assertEqual(ab.PRIMARY_BYTES, 0x80000)
        self.assertNotEqual(self.v73[0x70000:0x80000], bytes([255]) * 65536)
        self.assertEqual(self.v73[ab.APP_OFFSET:ab.APP_OFFSET + 4096],
                         self.after[ab.APP_OFFSET:ab.APP_OFFSET + 4096])

    def test_unapproved_seed_is_blocked_before_hw_access(self):
        with patch.object(ab, 'hw_adapter', side_effect=AssertionError('hardware access forbidden')):
            self.assertEqual(ab.main(['--seed', '19']), 1)
            self.assertEqual(ab.main(['--seed', '19', '--read-only']), 1)
            self.assertEqual(ab.main(['--seed', '19', '--install',
                                      '--candidate-sha256',
                                      ab.APPROVED_BIT_SHA,
                                      '--confirm', ab.INSTALL_ACK]), 1)

    def mocked(self, hw, directory):
        return [patch.object(ab, 'BUILD', directory),
                patch.object(ab, 'hw_adapter', return_value=hw),
                patch.object(ab, 'check_candidate',
                             return_value=(self.primary, self.fake_sha, len(self.fake_bit)))]

    def test_wrong_live_baseline_blocks_write(self):
        with tempfile.TemporaryDirectory() as path:
            hw = MockJtag(self.v73)
            hw.flash[0x70010] ^= 1
            with ExitStack() as stack:
                for mocked in self.mocked(hw, Path(path)):
                    stack.enter_context(mocked)
                self.assertEqual(ab.main(['--install', '--candidate-sha256', self.fake_sha,
                                          '--confirm', ab.INSTALL_ACK]), 1)
                self.assertFalse(hw.writes)

    def test_oversized_candidate_blocks_before_hardware_access(self):
        with tempfile.TemporaryDirectory() as path:
            oversize = Path(path) / 'oversize.bit'
            oversize.write_bytes(bytes([255]) * (ab.PRIMARY_BYTES + 1))
            with patch.object(ab, 'hw_adapter', side_effect=AssertionError('hardware access forbidden')):
                with patch.object(ab, 'candidate_paths', return_value=(
                        oversize, Path('missing'), Path('missing'),
                        Path('missing'), Path('missing'))):
                    self.assertEqual(ab.main(['--seed', '228', '--read-only']), 1)

    def test_offline_readonly_install_restore(self):
        with tempfile.TemporaryDirectory() as path:
            directory = Path(path)
            hw = MockJtag(self.v73)
            with ExitStack() as stack:
                for mocked in self.mocked(hw, directory):
                    stack.enter_context(mocked)
                self.assertEqual(ab.main([]), 0)
                self.assertFalse(hw.writes)
                self.assertEqual(ab.main(['--read-only']), 0)
                self.assertFalse(hw.writes)
                self.assertEqual(ab.main(['--install']), 1)
                self.assertFalse(hw.writes)
                self.assertEqual(ab.main(['--install', '--candidate-sha256', self.fake_sha,
                                          '--confirm', ab.INSTALL_ACK]), 0)
                self.assertEqual(bytes(hw.flash), self.after)
                self.assertEqual(hw.flash[ab.PRIMARY_BYTES:], self.v73[ab.PRIMARY_BYTES:])
                self.assertNotEqual(hw.flash[0x70000:0x80000], self.v73[0x70000:0x80000])
                self.assertEqual(hw.flash[ab.APP_OFFSET:ab.APP_OFFSET + 4096],
                                 self.v73[ab.APP_OFFSET:ab.APP_OFFSET + 4096])
                sessions = list(directory.glob('v75-512k-guarded-ab-*'))
                self.assertEqual(len(sessions), 1)
                saved = sessions[0]
                self.assertEqual((saved / 'v73-full-flash-before.bin').read_bytes(), self.v73)
                self.assertEqual((saved / 'v73-primary-512k-rollback.bin').read_bytes(),
                                 self.v73[:ab.PRIMARY_BYTES])
                self.assertEqual(ab.main(['--restore-session', str(saved)]), 1)
                self.assertEqual(ab.main(['--restore-session', str(saved),
                                          '--confirm', ab.RESTORE_ACK]), 0)
                self.assertEqual(bytes(hw.flash), self.v73)
                self.assertEqual(len(hw.writes), 2)

    def test_automatic_rollback_when_post_write_check_fails(self):
        with tempfile.TemporaryDirectory() as path:
            directory = Path(path)
            hw = MockJtag(self.v73)
            hw.fail_next_write_readback = True
            with ExitStack() as stack:
                for mocked in self.mocked(hw, directory):
                    stack.enter_context(mocked)
                self.assertEqual(ab.main(['--install', '--candidate-sha256', self.fake_sha,
                                          '--confirm', ab.INSTALL_ACK]), 1)
                self.assertEqual(bytes(hw.flash), self.v73)
                self.assertEqual(len(hw.writes), 2)
                session = next(directory.glob('v75-512k-guarded-ab-*'))
                status = json.loads((session / 'state.json').read_text())
                self.assertEqual(status['phase'], 'EXACT_V73_4M_RESTORED')

    def test_protected_corruption_prohibits_automatic_restore(self):
        with tempfile.TemporaryDirectory() as path:
            directory = Path(path)
            hw = MockJtag(self.v73)
            hw.corrupt_suffix = True
            with ExitStack() as stack:
                for mocked in self.mocked(hw, directory):
                    stack.enter_context(mocked)
                self.assertEqual(ab.main(['--install', '--candidate-sha256', self.fake_sha,
                                          '--confirm', ab.INSTALL_ACK]), 1)
                self.assertEqual(len(hw.writes), 1)
                session = next(directory.glob('v75-512k-guarded-ab-*'))
                status = json.loads((session / 'state.json').read_text())
                self.assertEqual(status['phase'], 'CRITICAL_RESTORE_UNVERIFIED')

    def test_corrupted_session_is_not_usable_for_restore(self):
        with tempfile.TemporaryDirectory() as path:
            directory = Path(path) / 'v75-512k-guarded-ab-test'
            ab.create_session(directory, self.v73, self.primary,
                              self.fake_sha, len(self.fake_bit))
            ab.verify_session(directory)
            rollback = directory / 'v73-primary-512k-rollback.bin'
            data = bytearray(rollback.read_bytes())
            data[0] ^= 1
            rollback.write_bytes(data)
            with self.assertRaisesRegex(ValueError, 'Session backup'):
                ab.verify_session(directory)


if __name__ == '__main__':
    unittest.main(verbosity=2)
