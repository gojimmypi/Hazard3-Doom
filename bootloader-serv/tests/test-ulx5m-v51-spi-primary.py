#!/usr/bin/env python3
"""Host-only regression tests for v51 flash-zero preflight. No hardware calls."""

import contextlib
import hashlib
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

MODULE = Path(__file__).with_name('qualify-ulx5m-v51-spi-primary.py')
spec = importlib.util.spec_from_file_location('v51_spi_primary', MODULE)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


def sha(data):
    return hashlib.sha256(data).hexdigest()


class Qualification(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='v51-offline-')
        self.addCleanup(self.tmp.cleanup)
        p = Path(self.tmp.name)
        self.paths = [p / x for x in ('primary.bit', 'factory-a.bin', 'factory-b.bin',
                                     'app.bit', 'sector.bin', 'snapshot.bin')]
        self.primary = mod.MAGIC + bytes([0x4A]) * (mod.PRIMARY_SIZE - len(mod.MAGIC) - len(mod.TRAILER)) + mod.TRAILER
        self.factory = mod.MAGIC + bytes([0x32]) * (0x13A0C0 - 4) + bytes([0xff]) * (mod.FLASH_BYTES - 0x13A0C0)
        self.app = mod.MAGIC + bytes([0x51]) * (mod.APP_SIZE - 4)
        self.sector = self.app + b'\xff' * (mod.SECTOR_BYTES - len(self.app))
        self.snapshot = (self.factory[:mod.SECONDARY] + self.sector +
                         self.factory[mod.SECONDARY + mod.SECTOR_BYTES:])
        for dest, data in zip(self.paths,
                              (self.primary, self.factory, self.factory,
                               self.app, self.sector, self.snapshot)):
            dest.write_bytes(data)
        self.pins = patch.multiple(mod, PRIMARY_SHA256=sha(self.primary),
                                   FACTORY_SHA256=sha(self.factory),
                                   APP_SHA256=sha(self.app),
                                   SECTOR_SHA256=sha(self.sector))
        self.pins.start()
        self.addCleanup(self.pins.stop)

    def check(self, snapshot=False):
        return mod.evaluate(*self.paths[:5], self.paths[5] if snapshot else None)

    def test_complete_file_evidence_still_blocks_flash(self):
        r = self.check(True)
        self.assertEqual([], r['errors'])
        self.assertEqual('PINNED_FILE_EVIDENCE_PASS_DEPLOYMENT_BLOCKED', r['result'])
        self.assertFalse(any(r['recovery_gates'].values()))
        self.assertEqual(100, r['primary']['sector_count'])
        self.assertEqual('0x064000', r['primary']['erase_end_exclusive'])
        self.assertEqual(409600, r['primary']['factory_bytes_at_risk'])

    def test_no_snapshot_is_not_claimed_current(self):
        self.assertEqual('NOT_SUPPLIED', self.check()['current_snapshot'])

    def test_bad_primary_hash(self):
        raw = bytearray(self.primary)
        raw[1234] ^= 1
        self.paths[0].write_bytes(raw)
        self.assertIn('primary: SHA256 mismatch', '\n'.join(self.check()['errors']))

    def test_missing_primary_trailer(self):
        raw = bytearray(self.primary)
        raw[-1] ^= 1
        self.paths[0].write_bytes(raw)
        self.assertIn('trailer mismatch', '\n'.join(self.check()['errors']))

    def test_primary_must_begin_with_gatemate_magic(self):
        raw = bytearray(self.primary)
        raw[0] ^= 1
        self.paths[0].write_bytes(raw)
        self.assertIn('GateMate magic', '\n'.join(self.check()['errors']))

    def test_factory_backups_must_match_sha_and_each_other(self):
        raw = bytearray(self.factory)
        raw[0x1010] ^= 1
        self.paths[2].write_bytes(raw)
        result = '\n'.join(self.check()['errors'])
        self.assertIn('factory_pass2: SHA256 mismatch', result)
        self.assertIn('two backups differ', result)

    def test_short_factory_rejected(self):
        self.paths[1].write_bytes(self.factory[:-1])
        self.assertIn('size 4194303', '\n'.join(self.check()['errors']))

    def test_corrupt_app_rejected(self):
        raw = bytearray(self.app)
        raw[-1] ^= 1
        self.paths[3].write_bytes(raw)
        self.assertIn('secondary_app: SHA256 mismatch', '\n'.join(self.check()['errors']))
        self.assertIn('payload differs', '\n'.join(self.check()['errors']))

    def test_erased_tail_corruption_rejected(self):
        raw = bytearray(self.sector)
        raw[-1] = 0
        self.paths[4].write_bytes(raw)
        result = '\n'.join(self.check()['errors'])
        self.assertIn('independent_sector: SHA256 mismatch', result)
        self.assertIn('erased tail changed', result)

    def test_protected_metadata_snapshot_change_rejected(self):
        raw = bytearray(self.snapshot)
        raw[mod.METADATA] ^= 1
        self.paths[5].write_bytes(raw)
        self.assertIn('metadata/other pre-app bytes changed',
                      '\n'.join(self.check(True)['errors']))

    def test_flash_zero_snapshot_change_rejected(self):
        raw = bytearray(self.snapshot)
        raw[1] ^= 1
        self.paths[5].write_bytes(raw)
        self.assertIn('flash zero', '\n'.join(self.check(True)['errors']))

    def test_flash_beyond_app_change_rejected(self):
        raw = bytearray(self.snapshot)
        raw[mod.SECONDARY + mod.SECTOR_BYTES + 1] ^= 1
        self.paths[5].write_bytes(raw)
        self.assertIn('bytes beyond app sector changed',
                      '\n'.join(self.check(True)['errors']))

    def test_wrong_current_app_sector_rejected(self):
        raw = bytearray(self.snapshot)
        raw[mod.SECONDARY + 100] ^= 1
        self.paths[5].write_bytes(raw)
        self.assertIn('secondary sector does not match',
                      '\n'.join(self.check(True)['errors']))

    def test_missing_file_fail_closed(self):
        self.paths[4].unlink()
        self.assertIn('independent_sector:', '\n'.join(self.check()['errors']))

    def test_cli_create_only_report(self):
        args = ['v51', '--primary', str(self.paths[0]),
                '--factory-pass1', str(self.paths[1]), '--factory-pass2', str(self.paths[2]),
                '--app-bit', str(self.paths[3]), '--sector-dump', str(self.paths[4]),
                '--report', str(Path(self.tmp.name) / 'report.json')]
        with patch('sys.argv', args), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(0, mod.main())
        with patch('sys.argv', args), contextlib.redirect_stderr(io.StringIO()), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(2, mod.main())

    def test_never_imports_hardware_or_flash_write_module(self):
        source = MODULE.read_text(encoding='ascii')
        for unsafe in ('pyusb', 'openFPGALoader', 'subprocess', 'import serial', 'spi_write('):
            self.assertNotIn(unsafe, source)


if __name__ == '__main__':
    unittest.main(verbosity=2)
