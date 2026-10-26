#!/usr/bin/env python3
"""Offline and injected-failure tests for the bounded v55 SPI-primary installer."""
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).with_name('qualify-ulx5m-v55-primary-install.py')
spec = importlib.util.spec_from_file_location('ulx5m_v55', SCRIPT)
v = importlib.util.module_from_spec(spec)
spec.loader.exec_module(v)


# This symbol is deliberately never executed; actual hardware uses the SHA-pinned
# upstream openFPGALoader-v1.2.0.exe through the WSL/Tigard toolchain.
MOCK_LOADER = Path('TEST_ONLY_no_executable_is_launched.exe')


def fake_evidence():
    # Tiny synthetic patterned primary, real 4 MiB address geometry.
    factory = bytes([0xff]) * v.hw.FLASH_BYTES
    current = bytearray(factory)
    current[v.SECONDARY:v.SECONDARY + 4096] = b'A' * 4096
    primary = b'P' * v.REGION
    installed = bytearray(current)
    installed[:v.REGION] = primary
    return dict(primary=primary, factory_region=factory[:v.REGION],
                factory_flash_expected=bytes(current), installed_flash_expected=bytes(installed),
                backup_sha=v.sha(factory), primary_sha=v.sha(primary), app_sector=b'A' * 4096)


class V55Tests(unittest.TestCase):
    def test_acknowledgement_required_before_files_or_jtag(self):
        with patch.object(v.hw, 'discover_backup', side_effect=AssertionError('hardware/prep accessed')):
            self.assertEqual(v.main(['--install']), 1)
            self.assertEqual(v.main(['--restore-session', 'bad']), 1)
            self.assertEqual(v.main(['--confirm', v.ACK]), 1)

    def test_fixed_region_exactly_seven_blocks(self):
        with tempfile.TemporaryDirectory() as temp:
            p = Path(temp) / 'block.bin'
            p.write_bytes(b'x' * v.BLOCK)
            cmd = v.block_write_cmd(MOCK_LOADER, 0x60000, p)
            self.assertEqual(cmd[-5:], ['-f', '--verify', '--offset', str(0x60000), str(p)])
            self.assertEqual(cmd[:5], [str(MOCK_LOADER), '-c', 'tigard', '--freq', '100k'])
            self.assertEqual(cmd.count('-f'), 1)
            self.assertEqual(cmd[-1], str(p))  # POSIX path; converted only at Windows subprocess boundary
            for forbidden in ('--bulk-erase', '--unprotect-flash', '--dfu', '-m'):
                self.assertNotIn(forbidden, cmd)
            for offset in (-0x10000, 0x70000, 1, 0x65000):
                with self.assertRaises(ValueError):
                    v.block_write_cmd(MOCK_LOADER, offset, p)
            p.write_bytes(b'x' * (v.BLOCK - 1))
            with self.assertRaises(ValueError):
                v.block_write_cmd(MOCK_LOADER, 0, p)

    def test_successful_install_preserves_app_and_rest_of_flash(self):
        evidence = fake_evidence()
        flash = bytearray(evidence['factory_flash_expected'])
        writes = []
        with tempfile.TemporaryDirectory() as temp:
            session = Path(temp) / 'session'
            def read(_loader, _freq, offset, size):
                return bytes(flash[offset:offset + size])
            def write(cmd, timeout=0):
                del timeout
                offset = int(cmd[cmd.index('--offset') + 1])
                data = Path(cmd[-1]).read_bytes()
                self.assertEqual(len(data), v.BLOCK)
                # Model upstream's 64 KiB erase before programming.
                flash[offset:offset+v.BLOCK] = b'\xff' * v.BLOCK
                flash[offset:offset+v.BLOCK] = data
                writes.append(offset)
                return 'ok'
            with patch.object(v, 'unique_session_dir', return_value=session), \
                 patch.object(v.hw, 'windows_file_argument'), \
                 patch.object(v.hw, 'detect'), patch.object(v.hw, 'read_region', side_effect=read), \
                 patch.object(v.hw, 'call', side_effect=write):
                self.assertEqual(v.install(MOCK_LOADER, evidence), 0)
            self.assertEqual(writes, list(range(0, v.REGION, v.BLOCK)))
            self.assertEqual(flash, evidence['installed_flash_expected'])
            self.assertEqual((session / 'state.json').read_text().count('PRIMARY_INSTALLED_AND_FULL_FLASH_VERIFIED'), 1)
            self.assertEqual(flash[v.SECONDARY:v.SECONDARY+4096], b'A' * 4096)

    def test_write_failure_restores_entire_region_and_full_flash(self):
        evidence = fake_evidence()
        flash = bytearray(evidence['factory_flash_expected'])
        mutations = []
        with tempfile.TemporaryDirectory() as temp:
            session = Path(temp) / 'session'
            def read(_loader, _freq, offset, size):
                return bytes(flash[offset:offset + size])
            def write(cmd, timeout=0):
                del timeout
                offset = int(cmd[cmd.index('--offset') + 1])
                data = Path(cmd[-1]).read_bytes()
                mutations.append(offset)
                flash[offset:offset+v.BLOCK] = b'\xff' * v.BLOCK
                if len(mutations) == 3:
                    raise ValueError('Injected failure after destructive erase')
                flash[offset:offset+v.BLOCK] = data
                return 'ok'
            with patch.object(v, 'unique_session_dir', return_value=session), \
                 patch.object(v.hw, 'windows_file_argument'), \
                 patch.object(v.hw, 'detect'), patch.object(v.hw, 'read_region', side_effect=read), \
                 patch.object(v.hw, 'call', side_effect=write):
                self.assertEqual(v.install(MOCK_LOADER, evidence), 1)
            self.assertEqual(flash, evidence['factory_flash_expected'])
            self.assertGreater(len(mutations), 3)
            self.assertIn('FACTORY_PRIMARY_RESTORED_VERIFIED', (session / 'state.json').read_text())

    def test_restoration_failure_retains_recovery_files(self):
        evidence = fake_evidence()
        flash = bytearray(evidence['factory_flash_expected'])
        with tempfile.TemporaryDirectory() as temp:
            session = Path(temp) / 'session'
            def read(_loader, _freq, offset, size):
                return bytes(flash[offset:offset+size])
            def write(cmd, timeout=0):
                del timeout
                offset = int(cmd[cmd.index('--offset') + 1])
                flash[offset:offset+v.BLOCK] = b'\xff' * v.BLOCK
                raise ValueError('Injected permanent hardware failure after block erase')
            with patch.object(v, 'unique_session_dir', return_value=session), \
                 patch.object(v.hw, 'windows_file_argument'), \
                 patch.object(v.hw, 'detect'), patch.object(v.hw, 'read_region', side_effect=read), \
                 patch.object(v.hw, 'call', side_effect=write):
                self.assertEqual(v.install(MOCK_LOADER, evidence), 1)
            self.assertEqual((session / 'factory-region-000000-06ffff.bin').read_bytes(), evidence['factory_region'])
            self.assertIn('CRITICAL_RESTORE_UNVERIFIED', (session / 'state.json').read_text())

    def test_verification_of_session_rejects_corruption(self):
        e = fake_evidence()
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp) / 'saved'
            v.save_session(directory, e)
            v.verify_session(directory, e)
            path = directory / 'factory-region-000000-06ffff.bin'
            path.write_bytes(b'X' + path.read_bytes()[1:])
            with self.assertRaises(ValueError):
                v.verify_session(directory, e)

    def test_local_pinned_bit_hash_and_trailer(self):
        primary = v.PRIMARY
        if not primary.is_file():
            self.skipTest('Locally built v50 seed-7 .bit not available')
        raw = primary.read_bytes()
        self.assertEqual(len(raw), v.prep.PRIMARY_BYTES)
        self.assertEqual(v.sha(raw), v.prep.PRIMARY_SHA)
        self.assertTrue(raw.endswith(v.inspector.EXPECTED_TRAILER))


if __name__ == '__main__':
    unittest.main(verbosity=2)
