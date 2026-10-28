#!/usr/bin/env python3
"""Read-only tests for TinyDFU v70 command audit (no hardware)."""
import importlib.util
import pathlib
import unittest

SCRIPT = pathlib.Path(__file__).with_name('audit-ulx5m-v70-tinydfu-compat.py')
spec = importlib.util.spec_from_file_location('v70_audit', SCRIPT)
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


class CommandAuditTests(unittest.TestCase):
    def setUp(self):
        self.original = bytes.fromhex('1f 10 08 20 04 01 00 00 00 00 00 00')
        self.fake_bit = (
            audit.packet(audit.CMD_CHG_STATUS, self.original)
            + audit.packet(audit.CMD_CFGRST, bytes([1, 12, 254]))
            + audit.packet(audit.CMD_JUMP, bytes.fromhex('00 10 20 00'))
        )

    def test_derived_status_and_frame(self):
        status, frame, tail = audit.derived_tinydfu_frame(self.fake_bit)
        self.assertEqual(bytes(status), bytes.fromhex('17 10 00 20 04 01 00 00 00 00 00 00'))
        self.assertEqual(len(frame), 27)
        self.assertEqual(frame[-9:], b'\x00'*4 + b'\x33' + b'\x00'*4)
        self.assertEqual([x[1] for x in tail], [0xdb, 0xc3, 0xda])

    def test_rom_matches_expected_frame(self):
        src = (pathlib.Path(__file__).parents[1] / 'rtl/top-ulx5m-gs-v70-cfg-runtime-clear-probe.v').read_text()
        _, expected, _ = audit.derived_tinydfu_frame(self.fake_bit)
        self.assertEqual(audit.extract_rom(src), expected)

    def test_crc_mutation_rejected(self):
        damaged = bytearray(self.fake_bit)
        damaged[13] ^= 1
        with self.assertRaisesRegex(ValueError, 'CRC mismatch'):
            audit.derived_tinydfu_frame(bytes(damaged))

    def test_user_mode_guard(self):
        modified = audit.packet(audit.CMD_CHG_STATUS, bytes.fromhex('17 10 08 20 04 01 00 00 00 00 00 00'))
        fake = modified + self.fake_bit[len(audit.packet(audit.CMD_CHG_STATUS, self.original)):]
        with self.assertRaisesRegex(ValueError, 'Unexpected initial status'):
            audit.derived_tinydfu_frame(fake)

    def test_no_flash_actions_in_audit(self):
        code = SCRIPT.read_text()
        for forbidden in ('openFPGALoader', ' --install', ' --restore-session', 'subprocess.run(', 'os.system('):
            self.assertNotIn(forbidden, code)


if __name__ == '__main__':
    unittest.main(verbosity=2)
