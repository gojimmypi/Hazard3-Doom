#!/usr/bin/env python3
"""Offline and injected-failure tests for bounded v60 seed-302 primary update."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).with_name('qualify-ulx5m-v62-primary-update.py')
spec = importlib.util.spec_from_file_location('ulx5m_v62', SCRIPT)
v = importlib.util.module_from_spec(spec)
spec.loader.exec_module(v)
MOCK_LOADER = Path('TEST_ONLY_no_executable_is_launched.exe')


def fake_evidence():
    # Synthetic 4MiB flash; no native executable is launched in the tests.
    old = bytearray(b'F' * v.hw.FLASH_BYTES)
    old[v.SECONDARY:v.SECONDARY + 4096] = b'A' * 4096
    current = bytes(old)
    candidate = bytearray(old)
    candidate[:v.REGION] = b'N' * v.REGION
    return {
        'primary': b'N' * v.REGION,
        'rollback_region': b'F' * v.REGION,
        'current_flash_expected': current,
        'candidate_flash_expected': bytes(candidate),
        'backup_sha': v.sha(old),
        'primary_sha': 'sha256-test-only',
        'app_sector': b'A' * 4096,
    }


class V62Tests(unittest.TestCase):
    def test_acknowledgement_required_before_evidence_or_hardware(self):
        with patch.object(v.hw, 'discover_backup', side_effect=AssertionError('evidence used')):
            self.assertEqual(v.main(['--install']), 1)
            self.assertEqual(v.main(['--restore-session', 'bad']), 1)
            self.assertEqual(v.main(['--confirm', v.ACK]), 1)

    def test_primary_extent_and_preservation(self):
        self.assertEqual(v.PRIMARY_BYTES, 0x6d109)
        self.assertEqual(v.PADDING_END, 0x6e000)
        self.assertEqual(v.REGION, 0x70000)
        self.assertEqual(v.PADDING_END - v.PRIMARY_BYTES, 3831)
        self.assertEqual(v.REGION - v.PADDING_END, 8192)
        # Factory tail contains non-FF information to catch accidental erasure.
        factory = bytearray(b'F' * v.hw.FLASH_BYTES)
        factory[v.PADDING_END:v.REGION] = bytes(range(256)) * 32
        bit = bytes.fromhex('d901ed96') + b'B' * (v.PRIMARY_BYTES - 4)
        image = bit + b'\xff' * (v.PADDING_END - len(bit)) + factory[v.PADDING_END:v.REGION]
        self.assertEqual(len(image), v.REGION)
        self.assertEqual(image[:len(bit)], bit)
        self.assertEqual(image[len(bit):v.PADDING_END], b'\xff' * 3831)
        self.assertEqual(image[v.PADDING_END:], factory[v.PADDING_END:v.REGION])

    def test_pinned_evidence_from_offline_fake_files(self):
        with tempfile.TemporaryDirectory() as td:
            temp = Path(td)
            factory = bytearray(b'F' * v.hw.FLASH_BYTES)
            sector = bytes.fromhex('d901ed96') + b'A' * 4092
            v55 = bytearray(b'V' * v.REGION)
            v55[0x64000:] = factory[0x64000:v.REGION]
            bit = bytes.fromhex('d901ed96') + b'B' * (v.PRIMARY_BYTES - 4)
            candidate_p = temp / 'new.bit'
            old_p = temp / 'old.bin'
            sector_p = temp / 'sector.bin'
            candidate_p.write_bytes(bit)
            old_p.write_bytes(v55)
            sector_p.write_bytes(sector)
            oldflash = bytearray(factory)
            oldflash[v.SECONDARY:v.SECONDARY + 4096] = sector
            oldflash[:v.REGION] = v55
            with (patch.object(v.hw, 'verified_backup', return_value=(bytes(factory), 'factory-test')),
                  patch.object(v.hw, 'verified_app_sector', return_value=sector),
                  patch.object(v.hw, 'check_loader'),
                  patch.object(v.inspector, 'inspect', return_value=(len(bit), v.sha(bit))),
                  patch.object(v, 'PRIMARY_SHA', v.sha(bit)),
                  patch.object(v, 'V55_REGION_SHA', v.sha(v55)),
                  patch.object(v, 'V55_FLASH_SHA', v.sha(oldflash))):
                evidence = v.prepare_evidence(candidate_p, old_p, temp, sector_p, MOCK_LOADER)
            self.assertEqual(evidence['current_flash_expected'], bytes(oldflash))
            self.assertEqual(evidence['primary'][:v.PRIMARY_BYTES], bit)
            self.assertEqual(evidence['primary'][v.PRIMARY_BYTES:v.PADDING_END], b'\xff'*3831)
            self.assertEqual(evidence['primary'][v.PADDING_END:], factory[v.PADDING_END:v.REGION])
            self.assertEqual(evidence['candidate_flash_expected'][v.REGION:], oldflash[v.REGION:])
            self.assertEqual(evidence['candidate_flash_expected'][v.SECONDARY:v.SECONDARY + 4096], sector)

    def test_refuse_unapproved_region_writes(self):
        with tempfile.TemporaryDirectory() as td:
            p = Path(td) / 'block.bin'
            p.write_bytes(b'X' * v.BLOCK)
            cmd = v.block_write_cmd(MOCK_LOADER, 0x60000, p)
            self.assertEqual(cmd[:5], [str(MOCK_LOADER), '-c', 'tigard', '--freq', '100k'])
            self.assertEqual(cmd[-5:], ['-f', '--verify', '--offset', str(0x60000), str(p)])
            self.assertNotIn('--bulk-erase', cmd)
            for offset in (-v.BLOCK, v.REGION, 1, 0x65000):
                with self.assertRaises(ValueError):
                    v.block_write_cmd(MOCK_LOADER, offset, p)
            p.write_bytes(b'X' * (v.BLOCK - 1))
            with self.assertRaises(ValueError):
                v.block_write_cmd(MOCK_LOADER, 0, p)

    def test_successful_install_preserves_rest_of_flash(self):
        evidence = fake_evidence()
        flash = bytearray(evidence['current_flash_expected'])
        writes = []
        with tempfile.TemporaryDirectory() as td:
            session = Path(td) / 'session'
            def read(_loader, _freq, offset, size):
                return bytes(flash[offset:offset + size])
            def write(cmd, timeout=0):
                del timeout
                offset = int(cmd[cmd.index('--offset') + 1])
                data = Path(cmd[-1]).read_bytes()
                self.assertEqual(len(data), v.BLOCK)
                flash[offset:offset + v.BLOCK] = data
                writes.append(offset)
                return 'ok'
            with patch.object(v, 'unique_session_dir', return_value=session), \
                 patch.object(v.hw, 'windows_file_argument'), \
                 patch.object(v.hw, 'detect'), \
                 patch.object(v.hw, 'read_region', side_effect=read), \
                 patch.object(v.hw, 'call', side_effect=write):
                self.assertEqual(v.install(MOCK_LOADER, evidence), 0)
            self.assertEqual(writes, list(range(0, v.REGION, v.BLOCK)))
            self.assertEqual(bytes(flash), evidence['candidate_flash_expected'])
            self.assertIn('V60_INSTALLED_AND_FULL_FLASH_VERIFIED', (session / 'state.json').read_text())

    def test_failure_restores_v55_not_factory(self):
        evidence = fake_evidence()
        flash = bytearray(evidence['current_flash_expected'])
        writes = []
        with tempfile.TemporaryDirectory() as td:
            session = Path(td) / 'session'
            def read(_loader, _freq, offset, size):
                return bytes(flash[offset:offset + size])
            def write(cmd, timeout=0):
                del timeout
                offset = int(cmd[cmd.index('--offset') + 1])
                flash[offset:offset + v.BLOCK] = b'\xff' * v.BLOCK
                writes.append(offset)
                if len(writes) == 3:
                    raise ValueError('Injected failure after erase')
                flash[offset:offset + v.BLOCK] = Path(cmd[-1]).read_bytes()
                return 'ok'
            with patch.object(v, 'unique_session_dir', return_value=session), \
                 patch.object(v.hw, 'windows_file_argument'), \
                 patch.object(v.hw, 'detect'), \
                 patch.object(v.hw, 'read_region', side_effect=read), \
                 patch.object(v.hw, 'call', side_effect=write):
                self.assertEqual(v.install(MOCK_LOADER, evidence), 1)
            self.assertEqual(bytes(flash), evidence['current_flash_expected'])
            self.assertGreater(len(writes), 3)
            self.assertEqual((session / 'v55-rollback-region-000000-06ffff.bin').read_bytes(),
                             evidence['rollback_region'])
            self.assertIn('V55_PRIMARY_RESTORED', (session / 'state.json').read_text())

    def test_wrong_baseline_blocks_all_writes(self):
        evidence = fake_evidence()
        flash = bytearray(evidence['current_flash_expected'])
        flash[0] ^= 1
        with tempfile.TemporaryDirectory() as td:
            session = Path(td) / 'session'
            def read(_loader, _freq, offset, size):
                return bytes(flash[offset:offset + size])
            with patch.object(v, 'unique_session_dir', return_value=session), \
                 patch.object(v.hw, 'windows_file_argument'), \
                 patch.object(v.hw, 'detect'), \
                 patch.object(v.hw, 'read_region', side_effect=read), \
                 patch.object(v.hw, 'call', side_effect=AssertionError('FLASH WRITE WOULD BE UNSAFE')):
                with self.assertRaises(ValueError):
                    v.install(MOCK_LOADER, evidence)

    def test_corrupted_rollback_rejected(self):
        evidence = fake_evidence()
        with tempfile.TemporaryDirectory() as td:
            session = Path(td) / 'session'
            v.save_session(session, evidence)
            v.verify_session(session, evidence)
            rollback = session / 'v55-rollback-region-000000-06ffff.bin'
            rollback.write_bytes(b'X' + rollback.read_bytes()[1:])
            with self.assertRaises(ValueError):
                v.verify_session(session, evidence)

    def test_restore_rejects_changed_protected_flash(self):
        evidence = fake_evidence()
        with tempfile.TemporaryDirectory() as td:
            session = Path(td) / 'v62-spi-update-test'
            v.save_session(session, evidence)
            saved_build = v.BUILD
            # Inject the prepared evidence, detect and flash read; never call a writer.
            corrupted = bytearray(evidence['candidate_flash_expected'])
            corrupted[v.SECONDARY] ^= 1
            with (patch.object(v, 'BUILD', Path(td)),
                  patch.object(v, 'prepare_evidence', return_value=evidence),
                  patch.object(v.hw, 'discover_backup', return_value=Path(td)),
                  patch.object(v.hw, 'windows_file_argument'),
                  patch.object(v.hw, 'detect'),
                  patch.object(v.hw, 'read_region', return_value=bytes(corrupted)),
                  patch.object(v.hw, 'call', side_effect=AssertionError('UNSAFE WRITE'))):
                self.assertEqual(v.main(['--restore-session', str(session), '--confirm', v.RESTORE_ACK]), 1)
            del saved_build

    def test_pinned_local_candidate_if_present(self):
        if not v.PRIMARY.is_file():
            self.skipTest('Locally built v60 seed-302 .bit is on user WSL filesystem')
        size, digest = v.inspector.inspect(v.PRIMARY)
        self.assertEqual(size, v.PRIMARY_BYTES)
        self.assertEqual(digest, v.PRIMARY_SHA)


if __name__ == '__main__':
    unittest.main(verbosity=2)
