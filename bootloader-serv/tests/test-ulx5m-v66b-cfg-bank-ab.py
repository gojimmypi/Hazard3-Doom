#!/usr/bin/env python3
"""v66b offline-only flash A/B guard regressions, no hardware access."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('v66b', HERE / 'qualify-ulx5m-v66b-cfg-bank-ab.py')
v66b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(v66b)
spec2 = importlib.util.spec_from_file_location('v65a_test', HERE / 'test-ulx5m-v65-multiboot-probe.py')
v65at = importlib.util.module_from_spec(spec2)
spec2.loader.exec_module(v65at)


class FakeHardware:
    def __init__(self, flash):
        self.flash = bytearray(flash)
        self.writes = []
        self.fail_next_after_write = False

    def check_loader(self, _): return None
    def detect(self, *_): return None
    def windows_file_argument(self, _): return 'C:\\mock\\path'
    def jtag_cmd(self, _, freq):
        assert freq == 100
        return ['MOCK-JTAG']

    def call(self, cmd, timeout=0):
        assert cmd[:5] == ['MOCK-JTAG', '-f', '--verify', '--offset', '0'], cmd
        payload = Path(cmd[-1]).read_bytes()
        assert len(payload) == v66b.BLOCK_BYTES
        self.flash[:v66b.BLOCK_BYTES] = payload
        self.writes.append((0, payload))
        return 'MOCKED write (never a physical GateMate)'

    def read_region(self, _, freq, offset, size):
        assert freq == 100 and offset >= 0 and offset % 4096 == 0
        assert size % 4096 == 0 and offset + size <= v66b.FLASH_BYTES
        if self.fail_next_after_write and len(self.writes) == 1 and offset == 0:
            self.fail_next_after_write = False
            raise ValueError('injected readback failure')
        return bytes(self.flash[offset:offset + size])


class V66b(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        v64, region, expected_region, old, new = v66b.pinned_v63c_state()
        cls.pinned = (v64, region, expected_region, old, new)
        cls.region = region
        cls.v64 = v64
        app_path = v66b.BUILD / 'fwtn-jtag-201000-tailfix-4096.bin'
        app = app_path.read_bytes()
        v64.check_bytes('v41 sector', app, v64.APP_LEN, v64.APP_SHA)
        before = bytearray(b'\xff' * v66b.FLASH_BYTES)
        before[:len(region)] = region
        before[v66b.APP_OFFSET:v66b.APP_OFFSET + len(app)] = app
        cls.v60 = bytes(before)
        cls.v63c = cls.v60[:v64.BLOCK_BASE] + v66b.pinned_v63c_state()[4] + cls.v60[v64.BLOCK_BASE + v64.BLOCK_SIZE:]
        cls.benefit = v65at.sample()
        cls.first = cls.benefit + b'\xff' * (v66b.BLOCK_BYTES - len(cls.benefit))
        cls.after = v66b.proposed_image(cls.v63c, cls.first)
        cls.test_root = v66b.BUILD
        cls.test_file = v66b.V66_BIT
        cls.log_file = v66b.V66_PNR_LOG

    def test_exact_source_is_pinned(self):
        v66b.check_source()
        with patch.dict(v66b.SOURCE_SHA, {'rtl/top-ulx5m-gs-v66-cfg-pin-sense-probe.v': '0'*64}):
            with self.assertRaisesRegex(ValueError, 'Changed v66 source'):
                v66b.check_source()

    def test_candidate_and_crc_and_six_flash_inputs(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            p = root / 'candidate.bit'
            log = root / 'pnr.log'
            p.write_bytes(self.benefit)
            lines = ["Info:     Constraining '$iopadmap$top_ulx5m_gs_v66_cfg_pin_sense_probe.%s' to pad '%s'." % (port.replace('[','_').replace(']',''), pad)
                     for port, pad in v66b.load_py('v66b_q', HERE / 'qualify-ulx5m-v66-cfg-pin-sense-probe.py').PINMAP.items()]
            log.write_text('\n'.join(lines) + "\nInfo: Max frequency for clock 'clk25': 110.58 MHz (PASS at 25.00 MHz)\n")
            with patch.object(v66b, 'V66_BIT', p), patch.object(v66b, 'V66_PNR_LOG', log):
                block, digest = v66b.check_candidate(p, log, v66b.sha(self.benefit))
                self.assertEqual(block, self.first)
                self.assertEqual(digest, v66b.sha(self.benefit))
                with self.assertRaisesRegex(ValueError, 'SHA256'):
                    v66b.check_candidate(p, log, 'f'*64)
                p.write_bytes(self.benefit[:-1])
                with self.assertRaises(ValueError):
                    v66b.check_candidate(p, log)

    def test_v63c_full_footprint_and_secondary(self):
        with patch.object(self.v64, 'BEFORE_FLASH_SHA', v66b.sha(self.v60)):
            v66b.verify_physical_v63c(self.v63c, self.pinned)
            bad = bytearray(self.v63c)
            bad[v66b.APP_OFFSET] ^= 1
            with self.assertRaises(ValueError):
                v66b.verify_physical_v63c(bytes(bad), self.pinned)
            bad = bytearray(self.v63c)
            bad[0x100000] ^= 1
            with self.assertRaises(ValueError):
                v66b.verify_physical_v63c(bytes(bad), self.pinned)

    def test_only_first_64k_changes(self):
        self.assertEqual(self.v63c[v66b.BLOCK_BYTES:], self.after[v66b.BLOCK_BYTES:])
        self.assertEqual(self.v63c[v66b.APP_OFFSET:v66b.APP_OFFSET+v66b.APP_LENGTH],
                         self.after[v66b.APP_OFFSET:v66b.APP_OFFSET+v66b.APP_LENGTH])
        self.assertNotEqual(self.v63c[:v66b.BLOCK_BYTES], self.after[:v66b.BLOCK_BYTES])

    def test_session_corruption_and_protected_region(self):
        with tempfile.TemporaryDirectory() as d:
            session = Path(d) / 'v66b-cfg-bank-ab-synthetic'
            with patch.object(self.v64, 'BEFORE_FLASH_SHA', v66b.sha(self.v60)), \
                 patch.object(v66b, 'pinned_v63c_state', return_value=self.pinned):
                v66b.save_session(session, self.v63c, self.after, v66b.sha(self.benefit))
                v66b.verify_session(session)
                before = bytearray(self.v63c)
                before[0x70000] ^= 1
                with self.assertRaises(ValueError):
                    v66b.check_protected_suffix(bytes(before), self.v63c)
                (session / 'v63c-first-64k-rollback.bin').write_bytes(self.first)
                with self.assertRaises(ValueError):
                    v66b.verify_session(session)

    def test_mock_jtag_write_readback_and_restore(self):
        with tempfile.TemporaryDirectory() as d:
            session = Path(d) / 'v66b-cfg-bank-ab-synthetic'
            with patch.object(self.v64, 'BEFORE_FLASH_SHA', v66b.sha(self.v60)), \
                 patch.object(v66b, 'pinned_v63c_state', return_value=self.pinned):
                v66b.save_session(session, self.v63c, self.after, v66b.sha(self.benefit))
                fake = FakeHardware(self.v63c)
                v66b.write_block(fake, Path('mock.exe'), session / 'v66-first-64k-candidate.bin')
                self.assertEqual(bytes(fake.flash), self.after)
                v66b.restore(fake, Path('mock.exe'), session)
                self.assertEqual(bytes(fake.flash), self.v63c)
                self.assertEqual(len(fake.writes), 2)

    def test_no_ack_no_hardware(self):
        with patch.object(v66b, 'hw_adapter', side_effect=AssertionError('HW forbidden')):
            self.assertEqual(v66b.main(['--install']), 1)
            self.assertEqual(v66b.main(['--restore-session', '/tmp/imaginary']), 1)

    def test_mock_read_only_full_install_and_explicit_restore(self):
        with tempfile.TemporaryDirectory() as d:
            build = Path(d) / 'build'
            build.mkdir()
            bit = build / 'candidate.bit'
            log = build / 'pnr.log'
            bit.write_bytes(self.benefit)
            lines = ["Info:     Constraining '$iopadmap$top_ulx5m_gs_v66_cfg_pin_sense_probe.%s' to pad '%s'." % (port.replace('[','_').replace(']',''), pad)
                     for port, pad in v66b.load_py('v66b_q', HERE / 'qualify-ulx5m-v66-cfg-pin-sense-probe.py').PINMAP.items()]
            log.write_text('\n'.join(lines) + "\nInfo: Max frequency for clock 'clk25': 110.58 MHz (PASS at 25.00 MHz)\n")
            fake = FakeHardware(self.v63c)
            with patch.object(self.v64, 'BEFORE_FLASH_SHA', v66b.sha(self.v60)), \
                 patch.object(v66b, 'pinned_v63c_state', return_value=self.pinned), \
                 patch.object(v66b, 'BUILD', build), patch.object(v66b, 'V66_BIT', bit), \
                 patch.object(v66b, 'V66_PNR_LOG', log), \
                 patch.object(v66b, 'hw_adapter', return_value=fake), \
                 patch.object(v66b, 'check_candidate', return_value=(self.first, v66b.sha(self.benefit))):
                self.assertEqual(v66b.main(['--read-only']), 0)
                self.assertEqual(len(fake.writes), 0)
                self.assertEqual(v66b.main(['--install', '--candidate-sha256', v66b.sha(self.benefit),
                                           '--confirm', v66b.INSTALL_ACK]), 0)
                self.assertEqual(bytes(fake.flash), self.after)
                sessions = list(build.glob('v66b-cfg-bank-ab-*'))
                self.assertEqual(len(sessions), 1)
                self.assertEqual(v66b.main(['--restore-session', str(sessions[0]),
                                           '--confirm', v66b.RESTORE_ACK]), 0)
                self.assertEqual(bytes(fake.flash), self.v63c)
                self.assertEqual([at for at, _ in fake.writes], [0, 0])

    def test_mock_complete_install_fail_and_rollback(self):
        with tempfile.TemporaryDirectory() as d:
            build = Path(d) / 'build'
            build.mkdir()
            bit = build / 'real.bit'
            log = build / 'pnr.log'
            bit.write_bytes(self.benefit)
            lines = ["Info:     Constraining '$iopadmap$top_ulx5m_gs_v66_cfg_pin_sense_probe.%s' to pad '%s'." % (port.replace('[','_').replace(']',''), pad)
                     for port, pad in v66b.load_py('v66b_q', HERE / 'qualify-ulx5m-v66-cfg-pin-sense-probe.py').PINMAP.items()]
            log.write_text('\n'.join(lines) + "\nInfo: Max frequency for clock 'clk25': 110.58 MHz (PASS at 25.00 MHz)\n")
            fake = FakeHardware(self.v63c)
            fake.fail_next_after_write = True
            with patch.object(self.v64, 'BEFORE_FLASH_SHA', v66b.sha(self.v60)), \
                 patch.object(v66b, 'pinned_v63c_state', return_value=self.pinned), \
                 patch.object(v66b, 'BUILD', build), patch.object(v66b, 'V66_BIT', bit), \
                 patch.object(v66b, 'V66_PNR_LOG', log), \
                 patch.object(v66b, 'hw_adapter', return_value=fake), \
                 patch.object(v66b, 'check_candidate', return_value=(self.first, v66b.sha(self.benefit))):
                self.assertEqual(v66b.main(['--install', '--candidate-sha256', v66b.sha(self.benefit),
                                           '--confirm', v66b.INSTALL_ACK]), 1)
                self.assertEqual(bytes(fake.flash), self.v63c)
                self.assertEqual(len(fake.writes), 2)
                sessions = list(build.glob('v66b-cfg-bank-ab-*'))
                self.assertEqual(len(sessions), 1)
                self.assertEqual(json.loads((sessions[0] / 'state.json').read_text())['phase'],
                                 'EXACT_V63C_FULL_FLASH_RESTORED')


if __name__ == '__main__':
    unittest.main(verbosity=2)
