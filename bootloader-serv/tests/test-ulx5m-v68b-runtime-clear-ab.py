#!/usr/bin/env python3
"""ULX5M-GS v68b offline and mocked-JTAG checks. Never accesses hardware."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent


def load(file, name):
    spec = importlib.util.spec_from_file_location(name, HERE / file)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


installer = load('qualify-ulx5m-v68b-runtime-clear-ab.py', 'v68b_install')
qualifier = load('qualify-ulx5m-v68-cfg-runtime-clear.py', 'v68_validator')


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
        assert len(block) == 65536
        self.flash[:65536] = block
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


class V68b(unittest.TestCase):
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
        # Synthetic candidate is allowed only inside MockHardware tests.
        cls.synthetic_bit = bytes.fromhex('deadbeef') * 200
        cls.synthetic_sha = installer.sha(cls.synthetic_bit)
        cls.firstblock = cls.synthetic_bit + b'\xff' * (installer.BLOCK_BYTES - len(cls.synthetic_bit))
        cls.after = installer.proposed_image(cls.v63c, cls.firstblock)

    def harness(self, fake, path):
        # Patches only for offline tests. Production script requires real SHA.
        return (
            patch.object(installer, 'BUILD', path),
            patch.object(installer, 'EXPECTED_PHYSICAL_V63C_SHA', installer.sha(self.v63c)),
            patch.object(installer, 'EXPECTED_V68_SHA', self.synthetic_sha),
            patch.object(self.v64, 'BEFORE_FLASH_SHA', installer.sha(self.v60)),
            patch.object(installer, 'pinned_v63c_state', return_value=self.pinned),
            patch.object(installer, 'check_candidate', return_value=(self.firstblock, self.synthetic_sha)),
            patch.object(installer, 'hw_adapter', return_value=fake),
        )

    def test_pinned_real_sources_and_runtime_frame(self):
        installer.check_source()
        qualifier.check_source()
        self.assertEqual(len(qualifier.FRAME), 27)
        self.assertEqual(qualifier.FINGERPRINT,
                         '3911f8b0ffe2b49efa0480160674aff6f89ae23c3c24bc84099deb2e35ffa110')
        self.assertEqual(qualifier.STATUS.hex(), '1f1000200401000000000000')
        self.assertEqual(installer.EXPECTED_V68_SHA,
                         'b1801ff866a1eb8fe8b96983299cb97910294763af97b90d655d4d23dfc4d8a6')
        self.assertEqual(installer.EXPECTED_PHYSICAL_V63C_SHA,
                         '644c7c1b26e4cc2ba419a59a53ca8ffbbc02e808920d68336e84ac886d81cb02')

    def test_qualifier_drift_is_rejected(self):
        with patch.dict(installer.SOURCE_SHA, {'tests/qualify-ulx5m-v68-cfg-runtime-clear.py': '0' * 64}):
            with self.assertRaisesRegex(ValueError, 'Changed pinned v68'):
                installer.check_source()

    def test_pack_only_does_not_write_flash(self):
        source = (installer.ROOT / 'Makefile.ulx5m-v68-cfg-runtime-clear-probe').read_text()
        self.assertNotIn('openFPGALoader', source)
        self.assertNotIn('--install', source)
        self.assertIn('$(GMPACK) --reconfig --bootaddr', source)

    def test_wrong_candidate_or_sha_rejected_before_hardware(self):
        with tempfile.TemporaryDirectory() as d:
            bit = Path(d) / 'candidate.bit'
            pnr = Path(d) / 'route.log'
            bit.write_bytes(self.synthetic_bit)
            pnr.write_text('mock route')
            class Validated:
                @staticmethod
                def check_candidate(_b, _l):
                    return {'sha256': installer.sha(bit.read_bytes()), 'bytes': len(bit.read_bytes())}, '87.71'
            real_load = installer.load_py
            def module_for(name, path):
                return Validated() if name == 'v68_packer' else real_load(name, path)
            with patch.object(installer, 'V68_BIT', bit), patch.object(installer, 'V68_PNR_LOG', pnr), \
                 patch.object(installer, 'EXPECTED_V68_SHA', self.synthetic_sha), patch.object(installer, 'load_py', side_effect=module_for):
                block, digest = installer.check_candidate(bit, pnr, self.synthetic_sha)
                self.assertEqual(block, self.firstblock)
                self.assertEqual(digest, self.synthetic_sha)
                with self.assertRaisesRegex(ValueError, 'acknowledgement'):
                    installer.check_candidate(bit, pnr, '0' * 64)
                bit.write_bytes(b'wrong')
                with self.assertRaisesRegex(ValueError, 'exact locally-qualified v68'):
                    installer.check_candidate(bit, pnr)

    def test_protect_suffix_and_app(self):
        self.assertEqual(self.v63c[installer.BLOCK_BYTES:], self.after[installer.BLOCK_BYTES:])
        self.assertEqual(self.v63c[installer.APP_OFFSET:installer.APP_OFFSET + 4096],
                         self.after[installer.APP_OFFSET:installer.APP_OFFSET + 4096])
        corrupted = bytearray(self.after)
        corrupted[0x100000] ^= 1
        with self.assertRaisesRegex(ValueError, 'Protected flash'):
            installer.check_protected_suffix(bytes(corrupted), self.v63c)

    def test_readonly_install_and_restore(self):
        with tempfile.TemporaryDirectory() as d:
            fake = MockHardware(self.v63c)
            from contextlib import ExitStack
            with ExitStack() as ctx:
                for p in self.harness(fake, Path(d)):
                    ctx.enter_context(p)
                self.assertEqual(installer.main(['--read-only']), 0)
                self.assertFalse(fake.writes)
                self.assertEqual(installer.main(['--install', '--candidate-sha256', self.synthetic_sha,
                                                 '--confirm', installer.INSTALL_ACK]), 0)
                self.assertEqual(bytes(fake.flash), self.after)
                dirs = list(Path(d).glob('v68b-runtime-clear-ab-*'))
                self.assertEqual(len(dirs), 1)
                self.assertEqual(installer.main(['--restore-session', str(dirs[0]),
                                                 '--confirm', installer.RESTORE_ACK]), 0)
                self.assertEqual(bytes(fake.flash), self.v63c)
                self.assertEqual(len(fake.writes), 2)

    def test_automatic_rollback_on_read_failure(self):
        with tempfile.TemporaryDirectory() as d:
            fake = MockHardware(self.v63c)
            fake.fail_once = True
            from contextlib import ExitStack
            with ExitStack() as ctx:
                for p in self.harness(fake, Path(d)):
                    ctx.enter_context(p)
                self.assertEqual(installer.main(['--install', '--candidate-sha256', self.synthetic_sha,
                                                 '--confirm', installer.INSTALL_ACK]), 1)
                self.assertEqual(bytes(fake.flash), self.v63c)
                dirs = list(Path(d).glob('v68b-runtime-clear-ab-*'))
                self.assertEqual(len(dirs), 1)
                meta = json.loads((dirs[0] / 'state.json').read_text())
                self.assertEqual(meta['phase'], 'EXACT_V63C_FULL_FLASH_RESTORED')

    def test_automatic_restore_refuses_protected_suffix_change(self):
        with tempfile.TemporaryDirectory() as d:
            fake = MockHardware(self.v63c)
            fake.fail_once = True
            fake.corrupt_suffix = True
            from contextlib import ExitStack
            with ExitStack() as ctx:
                for p in self.harness(fake, Path(d)):
                    ctx.enter_context(p)
                self.assertEqual(installer.main(['--install', '--candidate-sha256', self.synthetic_sha,
                                                 '--confirm', installer.INSTALL_ACK]), 1)
                dirs = list(Path(d).glob('v68b-runtime-clear-ab-*'))
                self.assertEqual(len(dirs), 1)
                meta = json.loads((dirs[0] / 'state.json').read_text())
                self.assertEqual(meta['phase'], 'CRITICAL_RESTORE_UNVERIFIED')

    def test_session_corruption_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            directory = Path(d) / 'v68b-runtime-clear-ab-synthetic'
            with patch.object(installer, 'EXPECTED_PHYSICAL_V63C_SHA', installer.sha(self.v63c)), \
                 patch.object(installer, 'EXPECTED_V68_SHA', self.synthetic_sha), \
                 patch.object(self.v64, 'BEFORE_FLASH_SHA', installer.sha(self.v60)), \
                 patch.object(installer, 'pinned_v63c_state', return_value=self.pinned):
                installer.save_session(directory, self.v63c, self.after, self.synthetic_sha)
                installer.verify_session(directory)
                rollback = directory / 'v63c-first-64k-rollback.bin'
                bad = bytearray(rollback.read_bytes()); bad[0] ^= 1
                rollback.write_bytes(bad)
                with self.assertRaises(ValueError):
                    installer.verify_session(directory)

    def test_requires_explicit_ack_before_hardware(self):
        with patch.object(installer, 'hw_adapter', side_effect=AssertionError('Hardware forbidden')):
            self.assertEqual(installer.main(['--install']), 1)
            self.assertEqual(installer.main(['--restore-session', '/tmp/not-a-session']), 1)


if __name__ == '__main__':
    unittest.main(verbosity=2)
