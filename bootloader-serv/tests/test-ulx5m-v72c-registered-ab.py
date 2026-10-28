#!/usr/bin/env python3
"""v72c offline regression tests: mocks only; never touches real JTAG/flash."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from contextlib import ExitStack
from unittest.mock import patch

HERE = Path(__file__).resolve().parent


def load(name, file):
    spec = importlib.util.spec_from_file_location(name, HERE / file)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


installer = load('v72c_installer', 'qualify-ulx5m-v72c-registered-ab.py')


class MockHardware:
    def __init__(self, data):
        self.flash = bytearray(data)
        self.writes = []
        self.fail_once = False
        self.corrupt_suffix = False

    def check_loader(self, *_args): pass
    def detect(self, *_args): pass
    def windows_file_argument(self, *_args): return r'C:\mock'

    def jtag_cmd(self, _loader, freq):
        assert freq == 100
        return ['MOCK']

    def call(self, cmd, timeout=0):
        assert cmd[:5] == ['MOCK', '-f', '--verify', '--offset', '0'], cmd
        block = Path(cmd[-1]).read_bytes()
        assert len(block) == installer.BLOCK_BYTES
        self.flash[:installer.BLOCK_BYTES] = block
        self.writes.append(block)

    def read_region(self, _loader, freq, offset, size):
        assert freq == 100
        if self.fail_once and self.writes:
            self.fail_once = False
            raise ValueError('injected JTAG readback failure')
        if self.corrupt_suffix and self.writes:
            self.flash[0x100000] ^= 1
            self.corrupt_suffix = False
        return bytes(self.flash[offset:offset + size])


class V72c(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.pinned = installer.pinned_v63c_state()
        cls.v64, cls.region, _, cls.old, cls.new = cls.pinned
        app = (installer.BUILD / 'fwtn-jtag-201000-tailfix-4096.bin').read_bytes()
        before = bytearray(b'\xff' * installer.FLASH_BYTES)
        before[:len(cls.region)] = cls.region
        before[installer.APP_OFFSET:installer.APP_OFFSET + len(app)] = app
        cls.v60 = bytes(before)
        cls.v63c = cls.v60[:cls.v64.BLOCK_BASE] + cls.new + cls.v60[cls.v64.BLOCK_BASE + cls.v64.BLOCK_SIZE:]
        cls.synthetic_bit = bytes.fromhex('deadbeef') * 3746 + b'xyz'
        assert len(cls.synthetic_bit) == installer.EXPECTED_V72_BYTES
        cls.synthetic_sha = installer.sha(cls.synthetic_bit)
        cls.firstblock = cls.synthetic_bit + b'\xff' * (installer.BLOCK_BYTES - len(cls.synthetic_bit))
        cls.after = installer.proposed_image(cls.v63c, cls.firstblock)

    def harness(self, fake, directory):
        bit = directory / 'candidate.bit'
        bit.write_bytes(self.synthetic_bit)
        return [
            patch.object(installer, 'V72_BIT', bit),
            patch.object(installer, 'BUILD', directory),
            patch.object(installer, 'EXPECTED_PHYSICAL_V63C_SHA', installer.sha(self.v63c)),
            patch.object(self.v64, 'BEFORE_FLASH_SHA', installer.sha(self.v60)),
            patch.object(installer, 'pinned_v63c_state', return_value=self.pinned),
            patch.object(installer, 'check_candidate', return_value=(self.firstblock, self.synthetic_sha)),
            patch.object(installer, 'hw_adapter', return_value=fake),
        ]

    def test_exact_qualified_digest_and_source_pins(self):
        self.assertEqual(installer.EXPECTED_V72_SHA,
            '839696d7c8a4ecdf63dff904c01ce85aea280bd885eda4309c7e5d25800e3aa0')
        self.assertEqual(installer.EXPECTED_V72_BYTES, 14987)
        self.assertEqual(installer.EXPECTED_PHYSICAL_V63C_SHA,
            '644c7c1b26e4cc2ba419a59a53ca8ffbbc02e808920d68336e84ac886d81cb02')
        installer.check_source()
        self.assertEqual(len(installer.SOURCE_SHA), 13)

    def test_source_drift_rejected(self):
        with patch.dict(installer.SOURCE_SHA, {'rtl/top-ulx5m-gs-v72-cfg-registered-probe.v': '0' * 64}):
            with self.assertRaisesRegex(ValueError, 'Changed pinned v72'):
                installer.check_source()

    def test_real_candidate_verifier_rejects_stale_and_wrong_sha(self):
        with tempfile.TemporaryDirectory() as temp:
            d = Path(temp)
            bit, pnr = d / 'candidate.bit', d / 'route.log'
            bit.write_bytes(self.synthetic_bit)
            pnr.write_text('test only')
            class MockQualifier:
                @staticmethod
                def qualify(candidate, *_args):
                    data = candidate.read_bytes()
                    return ({'sha256': installer.sha(data), 'bytes': len(data)}, '79.26',
                            '8fbec9715a209dac2dc35dc6b517972b9d64dcdc5a7b4437fac7731a0d2849e4')
            real_load = installer.load_py
            def mocked_load(name, path):
                return MockQualifier if name == 'v72_qualifier' else real_load(name, path)
            with patch.object(installer, 'V72_BIT', bit), \
                 patch.object(installer, 'V72_PNR_LOG', pnr), \
                 patch.object(installer, 'EXPECTED_V72_SHA', self.synthetic_sha), \
                 patch.object(installer, 'load_py', side_effect=mocked_load):
                block, digest = installer.check_candidate(bit, pnr, self.synthetic_sha)
                self.assertEqual(block, self.firstblock)
                self.assertEqual(digest, self.synthetic_sha)
                with self.assertRaisesRegex(ValueError, 'acknowledgement'):
                    installer.check_candidate(bit, pnr, '0' * 64)
                bit.write_bytes(b'wrong')
                with self.assertRaisesRegex(ValueError, 'qualified v72b'):
                    installer.check_candidate(bit, pnr, self.synthetic_sha)
                with self.assertRaisesRegex(ValueError, 'alternate candidate'):
                    installer.check_candidate(d / 'unrelated.bit', pnr, self.synthetic_sha)

    def test_offline_and_missing_ack_never_access_hardware(self):
        with patch.object(installer, 'hw_adapter', side_effect=AssertionError('hardware access forbidden')):
            self.assertEqual(installer.main(['--install']), 1)
            self.assertEqual(installer.main(['--restore-session', '/tmp/invalid']), 1)

    def test_flash_protection_and_mock_install_rollback(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            fake = MockHardware(self.v63c)
            with ExitStack() as stack:
                for mock in self.harness(fake, directory):
                    stack.enter_context(mock)
                self.assertEqual(installer.main(['--read-only']), 0)
                self.assertFalse(fake.writes)
                self.assertEqual(installer.main(['--install', '--candidate-sha256', self.synthetic_sha,
                                                 '--confirm', installer.INSTALL_ACK]), 0)
                self.assertEqual(bytes(fake.flash), self.after)
                self.assertEqual(fake.flash[installer.BLOCK_BYTES:], self.v63c[installer.BLOCK_BYTES:])
                sessions = list(directory.glob('v72c-registered-ab-*'))
                self.assertEqual(len(sessions), 1)
                self.assertEqual(installer.main(['--restore-session', str(sessions[0]),
                                                 '--confirm', installer.RESTORE_ACK]), 0)
                self.assertEqual(bytes(fake.flash), self.v63c)
                self.assertEqual(len(fake.writes), 2)

    def test_automatic_rollback_after_read_failure(self):
        with tempfile.TemporaryDirectory() as temp:
            fake = MockHardware(self.v63c)
            fake.fail_once = True
            with ExitStack() as stack:
                for mock in self.harness(fake, Path(temp)):
                    stack.enter_context(mock)
                self.assertEqual(installer.main(['--install', '--candidate-sha256', self.synthetic_sha,
                                                 '--confirm', installer.INSTALL_ACK]), 1)
                self.assertEqual(bytes(fake.flash), self.v63c)
                sessions = list(Path(temp).glob('v72c-registered-ab-*'))
                self.assertEqual(len(sessions), 1)
                state = json.loads((sessions[0] / 'state.json').read_text())
                self.assertEqual(state['phase'], 'EXACT_V63C_FULL_FLASH_RESTORED')

    def test_corrupt_protected_suffix_blocks_automatic_restore(self):
        with tempfile.TemporaryDirectory() as temp:
            fake = MockHardware(self.v63c)
            fake.fail_once = True
            fake.corrupt_suffix = True
            with ExitStack() as stack:
                for mock in self.harness(fake, Path(temp)):
                    stack.enter_context(mock)
                self.assertEqual(installer.main(['--install', '--candidate-sha256', self.synthetic_sha,
                                                 '--confirm', installer.INSTALL_ACK]), 1)
                sessions = list(Path(temp).glob('v72c-registered-ab-*'))
                self.assertEqual(len(sessions), 1)
                state = json.loads((sessions[0] / 'state.json').read_text())
                self.assertEqual(state['phase'], 'CRITICAL_RESTORE_UNVERIFIED')

    def test_saved_backup_corruption_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            with patch.object(installer, 'EXPECTED_PHYSICAL_V63C_SHA', installer.sha(self.v63c)), \
                 patch.object(self.v64, 'BEFORE_FLASH_SHA', installer.sha(self.v60)), \
                 patch.object(installer, 'pinned_v63c_state', return_value=self.pinned):
                directory = Path(temp) / 'v72c-registered-ab-test'
                installer.save_session(directory, self.v63c, self.after,
                                       self.synthetic_sha, len(self.synthetic_bit))
                installer.verify_session(directory)
                first = directory / 'v63c-first-64k-rollback.bin'
                altered = bytearray(first.read_bytes())
                altered[0] ^= 1
                first.write_bytes(altered)
                with self.assertRaises(ValueError):
                    installer.verify_session(directory)


if __name__ == '__main__':
    unittest.main(verbosity=2)
