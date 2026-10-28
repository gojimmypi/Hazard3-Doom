#!/usr/bin/env python3
"""Offline regression for v73 full SERV bitstream packing and read-only gates."""
import importlib.util
from pathlib import Path
import unittest

HERE = Path(__file__).resolve().parent


def load(filename, name):
    spec = importlib.util.spec_from_file_location(name, HERE / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


audit = load('audit-ulx5m-v70-tinydfu-compat.py', 'v73e_audit')
generator = load('mk-ulx5m-v72-cmd.py', 'v73e_generator')
qualifier = load('qualify-ulx5m-v73-integrated.py', 'v73e_qualifier')


class V73ePackTests(unittest.TestCase):
    def setUp(self):
        # Intermediate status uses a reserved zero CRC, as observed in
        # real full SERV gmpack images. Terminal packets are CRC-valid.
        interim = bytes.fromhex('DB 09 00 00 00 00 00 10 9F 20 00 01 00 00 00 00 00')
        status = bytes.fromhex('1F 10 08 20 04 01 00 00 00 00 00 00')
        tail = (audit.packet(audit.CMD_CHG_STATUS, status)
                + audit.packet(audit.CMD_CFGRST, b'\x00')
                + audit.packet(audit.CMD_JUMP, (0x201000).to_bytes(4, 'little')))
        self.image = interim + tail
        self.tail = tail

    def test_intermediate_status_crc_is_not_a_false_failure(self):
        derived = generator.derive(self.image)
        self.assertEqual(len(derived), 27)
        self.assertEqual(derived, generator.derive(self.tail))

    def test_terminal_status_header_crc_remains_checked(self):
        bad = bytearray(self.image)
        bad[len(self.image) - len(self.tail) + 2] ^= 1
        with self.assertRaisesRegex(ValueError, 'Header CRC mismatch'):
            generator.derive(bytes(bad))

    def test_terminal_status_data_crc_remains_checked(self):
        bad = bytearray(self.image)
        bad[len(self.image) - len(self.tail) + 4 + 12] ^= 1
        with self.assertRaisesRegex(ValueError, 'CRC mismatch'):
            generator.derive(bytes(bad))

    def test_wrong_boot_address_remains_rejected(self):
        bad = self.image[:-10] + audit.packet(
            audit.CMD_JUMP, (0x100000).to_bytes(4, 'little'))
        with self.assertRaisesRegex(ValueError, 'bootaddr'):
            generator.derive(bad)

    def test_full_serv_size_is_accepted_read_only(self):
        for size in (65536, 446729, 512 * 1024):
            qualifier.verify_size(bytes(size))
        for size in (9999, 512 * 1024 + 1):
            with self.assertRaisesRegex(ValueError, 'pack-only limit'):
                qualifier.verify_size(bytes(size))

    def test_six_actual_serv_flash_pad_names(self):
        lines = ''.join("Info:     Constraining '%s' to pad '%s'.\n" % item
                        for item in qualifier.PINMAP.items())
        qualifier.verify_pins(lines)
        for key, val in qualifier.PINMAP.items():
            with self.subTest(key=key):
                with self.assertRaisesRegex(ValueError, 'missing physical flash pad'):
                    qualifier.verify_pins(lines.replace(
                        "'%s' to pad '%s'" % (key, val),
                        "'%s' to pad 'IO_INVALID'" % key))

    def test_no_hardware_write_in_qualifier(self):
        src = (HERE / 'qualify-ulx5m-v73-integrated.py').read_text()
        for forbidden in ('subprocess.run(', 'openFPGALoader.exe', 'dfu-util ', '--install'):
            self.assertNotIn(forbidden, src)


if __name__ == '__main__':
    unittest.main(verbosity=2)
