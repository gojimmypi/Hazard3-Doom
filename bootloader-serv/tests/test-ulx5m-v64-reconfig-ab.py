#!/usr/bin/env python3
"""v64 offline regressions; fake programmer never accesses USB/JTAG/flash."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
NAME = 'qualify-ulx5m-v64-reconfig-ab.py'
spec = importlib.util.spec_from_file_location('v64_reconfig_ab', HERE / NAME)
v64 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(v64)


class FakeJtag:
    def __init__(self, initial):
        self.flash = bytearray(initial)
        self.writes = []
        self.reads = []
        self.fail_after_write = False

    def check_loader(self, _):
        return True

    def detect(self, *_):
        return True

    def windows_file_argument(self, _):
        return 'C:\\mock\\path'

    def jtag_cmd(self, *_):
        return ['MOCK-JTAG']

    def call(self, cmd, timeout=None):
        if cmd[:1] != ['MOCK-JTAG'] or cmd[1:5] != ['-f', '--verify', '--offset', str(v64.BLOCK_BASE)]:
            raise ValueError('Mock refuses out-of-region operation: %r' % cmd)
        part = Path(cmd[-1]).read_bytes()
        if len(part) != v64.BLOCK_SIZE:
            raise ValueError('Invalid block size')
        self.flash[v64.BLOCK_BASE:v64.BLOCK_BASE + v64.BLOCK_SIZE] = part
        self.writes.append((v64.BLOCK_BASE, bytes(part)))
        return ''

    def read_region(self, _, freq, offset, length):
        if freq != 100 or offset % 0x1000 or length % 0x1000:
            raise ValueError('Invalid read')
        self.reads.append((offset, length))
        if self.fail_after_write and self.writes and len(self.writes) == 1 and offset == v64.BLOCK_BASE:
            self.fail_after_write = False
            raise ValueError('Injected independent readback failure')
        return bytes(self.flash[offset:offset + length])


class V64(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        project = HERE.parents[1]
        build = project / 'bootloader-serv' / 'build-ulx5m-gs'
        cls.primary = (build / 'normal-boot-dfu-hw-native' /
                       'spi-secondary-spi-primary-seed302.bit').read_bytes()
        cls.region = (build / 'v62-spi-update-20261027T034513196538Z-1776' /
                      'v60-candidate-region-000000-06ffff.bin').read_bytes()
        # Independently predicted output; the real gmpack result has already
        # been matched byte-for-byte by the v63c qualification.
        v63c = v64.load_module('test_v63c_generator', HERE / 'qualify-ulx5m-v63c-reconfig-primary.py')
        cls.candidate = v63c.predict_variant(cls.primary)
        cls.old, cls.new = v64.inspect_candidate(cls.primary, cls.candidate, cls.region)
        # Synthetic whole flash: no need to distribute a factory backup.
        cls.flash = bytearray(b'\xff' * v64.FLASH_SIZE)
        cls.flash[:v64.REGION_SIZE] = cls.region
        app = (build / 'fwtn-jtag-201000-tailfix-4096.bin').read_bytes()
        v64.check_bytes('v41 app', app, v64.APP_LEN, v64.APP_SHA)
        cls.flash[v64.APP_BASE:v64.APP_BASE + v64.APP_LEN] = app
        cls.flash = bytes(cls.flash)

    def test_pinned_candidate(self):
        self.assertEqual(self.candidate[v64.EDIT_OFFSETS[0]], 0x1f)
        self.assertEqual(tuple(i for i in range(len(self.primary)) if self.primary[i] != self.candidate[i]), v64.EDIT_OFFSETS)

    def test_candidate_mutation_rejected(self):
        bad = bytearray(self.candidate)
        bad[100] ^= 1
        with self.assertRaisesRegex(ValueError, 'candidate'):
            v64.inspect_candidate(self.primary, bytes(bad), self.region)

    def test_primary_mutation_rejected(self):
        bad = bytearray(self.primary)
        bad[100] ^= 1
        with self.assertRaises(ValueError):
            v64.inspect_candidate(bytes(bad), self.candidate, self.region)

    def test_region_mutation_rejected(self):
        bad = bytearray(self.region)
        bad[-1] ^= 1
        with self.assertRaises(ValueError):
            v64.inspect_candidate(self.primary, self.candidate, bytes(bad))

    def test_block_and_protection(self):
        with patch.object(v64, 'BEFORE_FLASH_SHA', v64.sha(self.flash)):
            proposed = v64.qualify_live(self.flash, self.region, self.old, self.new)
        self.assertEqual(proposed[:v64.BLOCK_BASE], self.flash[:v64.BLOCK_BASE])
        self.assertEqual(proposed[v64.BLOCK_BASE + v64.BLOCK_SIZE:], self.flash[v64.BLOCK_BASE + v64.BLOCK_SIZE:])
        self.assertEqual(proposed[v64.APP_BASE:v64.APP_BASE+v64.APP_LEN], self.flash[v64.APP_BASE:v64.APP_BASE+v64.APP_LEN])
        self.assertEqual(tuple(i for i in range(v64.FLASH_SIZE) if self.flash[i] != proposed[i]), v64.EDIT_OFFSETS)

    def test_session_corruption_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            with patch.object(v64, 'BEFORE_FLASH_SHA', v64.sha(self.flash)):
                proposed = v64.qualify_live(self.flash, self.region, self.old, self.new)
                d = Path(tmp) / 's'
                v64.save_session(d, self.flash, proposed, self.old, self.new)
                v64.verify_session(d)
                (d / 'v60-rollback-block-060000.bin').write_bytes(self.new)
                with self.assertRaises(ValueError):
                    v64.verify_session(d)

    def test_protected_flash_modified_reject_restore(self):
        bad = bytearray(self.flash)
        bad[0x40000] ^= 1
        with self.assertRaisesRegex(ValueError, 'Protected flash'):
            v64.verify_outside_block(bytes(bad), self.flash)

    def test_hardware_write_is_one_block_and_rollback(self):
        with tempfile.TemporaryDirectory() as tmp:
            with patch.object(v64, 'BEFORE_FLASH_SHA', v64.sha(self.flash)):
                proposed = v64.qualify_live(self.flash, self.region, self.old, self.new)
                d = Path(tmp) / 's'
                v64.save_session(d, self.flash, proposed, self.old, self.new)
                hw = FakeJtag(self.flash)
                v64.write_one_block(hw, Path('mock.exe'), d / 'v63c-candidate-block-060000.bin')
                self.assertEqual(bytes(hw.flash), proposed)
                self.assertEqual(len(hw.writes), 1)
                self.assertEqual(hw.writes[0][0], v64.BLOCK_BASE)
                v64.restore(hw, Path('mock.exe'), d)
                self.assertEqual(bytes(hw.flash), self.flash)
                self.assertEqual(len(hw.writes), 2)

    def test_no_write_without_ack(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / 'variant.bit'
            p.write_bytes(self.candidate)
            with patch.object(v64, 'hw_adapter', side_effect=AssertionError('hardware must not be reached')):
                self.assertEqual(v64.main(['--install', '--candidate', str(p)]), 1)

    def test_cli_read_only_and_full_install_mock(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            p = root / 'candidate.bit'
            b = root / 'primary.bit'
            r = root / 'region.bin'
            p.write_bytes(self.candidate)
            b.write_bytes(self.primary)
            r.write_bytes(self.region)
            hw = FakeJtag(self.flash)
            with patch.object(v64, 'BUILD', root), \
                 patch.object(v64, 'BEFORE_FLASH_SHA', v64.sha(self.flash)), \
                 patch.object(v64, 'hw_adapter', return_value=hw):
                common = ['--candidate', str(p), '--v60-primary', str(b),
                          '--v60-region', str(r)]
                self.assertEqual(v64.main(common + ['--read-only']), 0)
                self.assertEqual(hw.writes, [])
                self.assertEqual(v64.main(common + ['--install', '--confirm', v64.INSTALL_ACK]), 0)
                self.assertEqual(len(hw.writes), 1)
                self.assertEqual(v64.main(common + ['--read-only']), 0)
                sessions = list(root.glob('v64-reconfig-ab-*'))
                self.assertEqual(len(sessions), 1)
                self.assertEqual(v64.main(common + ['--restore-session', str(sessions[0]),
                                                  '--confirm', v64.RESTORE_ACK]), 0)
                self.assertEqual(bytes(hw.flash), self.flash)
                self.assertEqual(len(hw.writes), 2)

    def test_cli_failed_readback_restores_v60_mock(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            p = root / 'candidate.bit'
            b = root / 'primary.bit'
            r = root / 'region.bin'
            p.write_bytes(self.candidate)
            b.write_bytes(self.primary)
            r.write_bytes(self.region)
            hw = FakeJtag(self.flash)
            hw.fail_after_write = True
            with patch.object(v64, 'BUILD', root), \
                 patch.object(v64, 'BEFORE_FLASH_SHA', v64.sha(self.flash)), \
                 patch.object(v64, 'hw_adapter', return_value=hw):
                args = ['--candidate', str(p), '--v60-primary', str(b),
                        '--v60-region', str(r), '--install', '--confirm', v64.INSTALL_ACK]
                self.assertEqual(v64.main(args), 1)
                self.assertEqual(bytes(hw.flash), self.flash)
                self.assertEqual(len(hw.writes), 2)
                sessions = list(root.glob('v64-reconfig-ab-*'))
                self.assertEqual(len(sessions), 1)
                self.assertIn('V60_RESTORED_FULL_FLASH_VERIFIED',
                              (sessions[0] / 'state.json').read_text())

    def test_offline_default_never_touches_hardware(self):
        with tempfile.TemporaryDirectory() as tmp:
            a, b, c = [Path(tmp) / v for v in ('primary.bit', 'variant.bit', 'region.bin')]
            a.write_bytes(self.primary)
            b.write_bytes(self.candidate)
            c.write_bytes(self.region)
            with patch.object(v64, 'hw_adapter', side_effect=AssertionError('hardware must not be reached')):
                self.assertEqual(v64.main(['--candidate', str(b), '--v60-primary', str(a), '--v60-region', str(c)]), 0)


if __name__ == '__main__':
    unittest.main(verbosity=2)
