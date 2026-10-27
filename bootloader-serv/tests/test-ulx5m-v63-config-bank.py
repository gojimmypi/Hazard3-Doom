#!/usr/bin/env python3
"""No-hardware regression for the frozen ULX5M-GS v63 config-bank audit."""
import importlib.util
from pathlib import Path
import unittest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location(
    'ulx5m_v63_bank_audit', HERE / 'audit-ulx5m-v63-config-bank.py')
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


class V63BankAudit(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.primary = audit.PRIMARY.read_bytes()
        cls.region = audit.REGION_FILE.read_bytes()
        cls.rollback = audit.ROLLBACK_FILE.read_bytes()
        cls.sector = audit.SECONDARY_FILE.read_bytes()
        import json
        cls.manifest = json.loads(audit.MANIFEST.read_text(encoding='ascii'))
        cls.rtl = audit.RTL.read_text(encoding='ascii')
        cls.makefile = audit.MAKEFILE.read_text(encoding='ascii')

    def check(self, **overrides):
        values = dict(primary=self.primary, region=self.region,
                      rollback=self.rollback, secondary=self.sector,
                      manifest=self.manifest, rtl=self.rtl,
                      makefile=self.makefile)
        values.update(overrides)
        return audit.audit(**values)

    def test_unmodified_frozen_evidence(self):
        result = self.check()
        self.assertEqual(result['status'], 0x17)
        self.assertEqual(result['jump_address'], 0x201000)
        self.assertFalse(result['reconfig_flag_observed'])
        self.assertFalse(result['bank_command_verified'])
        self.assertFalse(result['normal_mode_secondary_takeover_verified'])

    def test_primary_mutation_rejected(self):
        altered = bytearray(self.primary)
        altered[-40] ^= 0x08
        with self.assertRaises(ValueError):
            self.check(primary=bytes(altered))

    def test_jump_mutation_rejected(self):
        altered = bytearray(self.primary)
        altered[-8] ^= 0x01
        with self.assertRaises(ValueError):
            self.check(primary=bytes(altered))

    def test_primary_region_mutation_rejected(self):
        altered = bytearray(self.region)
        altered[0x120] ^= 1
        with self.assertRaises(ValueError):
            self.check(region=bytes(altered))

    def test_secondary_sector_mutation_rejected(self):
        altered = bytearray(self.sector)
        altered[-1] ^= 1
        with self.assertRaises(ValueError):
            self.check(secondary=bytes(altered))

    def test_rollback_mutation_rejected(self):
        altered = bytearray(self.rollback)
        altered[-1] ^= 1
        with self.assertRaises(ValueError):
            self.check(rollback=bytes(altered))

    def test_manifest_drift_rejected(self):
        manifest = dict(self.manifest, secondary_offset=0x200000)
        with self.assertRaises(ValueError):
            self.check(manifest=manifest)

    def test_rtl_wiring_drift_rejected(self):
        with self.assertRaises(ValueError):
            self.check(rtl=self.rtl.replace(".EN(1'b0)", ".EN(1'b1)"))

    def test_makefile_drift_rejected(self):
        with self.assertRaises(ValueError):
            self.check(makefile=self.makefile + '\ngmpack --reconfig\n')

    def test_wrong_flash_dump_rejected(self):
        with self.assertRaises(ValueError):
            self.check(current_flash=bytes(audit.FLASH_BYTES))

    def test_terminal_block_crcs(self):
        cmd = self.primary[-46:]
        self.assertEqual(audit.crc16_x25(cmd[:2]), int.from_bytes(cmd[2:4], 'little'))
        self.assertEqual(audit.crc16_x25(cmd[0:16]), int.from_bytes(cmd[16:18], 'little'))
        self.assertEqual(audit.crc16_x25(cmd[27:29]),
                         int.from_bytes(cmd[29:31], 'little'))
        self.assertEqual(audit.crc16_x25(cmd[34:36]),
                         int.from_bytes(cmd[36:38], 'little'))


if __name__ == '__main__':
    unittest.main(verbosity=2)
