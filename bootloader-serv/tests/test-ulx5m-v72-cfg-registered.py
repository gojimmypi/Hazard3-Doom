#!/usr/bin/env python3
"""Read-only v72 command, protocol structure, and optional RTL simulation."""
import importlib.util
from pathlib import Path
import shutil
import sys
import subprocess
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent


def module(name, file):
    spec = importlib.util.spec_from_file_location(name, HERE / file)
    obj = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(obj)
    return obj


generator = module('v72_cmd', 'mk-ulx5m-v72-cmd.py')
audit = module('v71a_audit', 'audit-ulx5m-v70-tinydfu-compat.py')


class V72CommandTests(unittest.TestCase):
    def setUp(self):
        original = bytes.fromhex('1f 10 08 20 04 01 00 00 00 00 00 00')
        self.packed = (audit.packet(audit.CMD_CHG_STATUS, original) +
                       audit.packet(audit.CMD_CFGRST, b'\x00') +
                       audit.packet(audit.CMD_JUMP, (0x201000).to_bytes(4, 'little')))

    def test_tinydfu_image_derived_exact_bytes(self):
        self.assertEqual(generator.derive(self.packed), bytes.fromhex(
            'db 0c b8 7e 17 10 00 20 04 01 00 00 00 00 00 00 '
            '5d 31 00 00 00 00 33 00 00 00 00'))

    def test_bad_image_crc_rejected(self):
        bad = bytearray(self.packed)
        bad[11] ^= 1
        with self.assertRaisesRegex(ValueError, 'CRC mismatch'):
            generator.derive(bytes(bad))

    def test_wrong_bootaddr_rejected(self):
        wrong = self.packed[:-10] + audit.packet(audit.CMD_JUMP, (0x100000).to_bytes(4, 'little'))
        with self.assertRaisesRegex(ValueError, 'bootaddr'):
            generator.derive(wrong)

    def test_rom_check_rejects_stale_bytes(self):
        with tempfile.TemporaryDirectory() as temp:
            bit, hexfile = Path(temp) / 'test.bit', Path(temp) / 'cmd.hex'
            bit.write_bytes(self.packed)
            expected = generator.derive(self.packed)
            hexfile.write_text(''.join('%02X\n' % x for x in expected))
            self.assertEqual(len(hexfile.read_text().splitlines()), 27)
            check = [sys.executable, str(HERE / 'mk-ulx5m-v72-cmd.py'),
                     '--bit', str(bit), '--hex', str(hexfile), '--check']
            passed = subprocess.run(check, capture_output=True, text=True)
            self.assertEqual(passed.returncode, 0, passed.stderr)
            hexfile.write_text('00\n' * 27)
            failed = subprocess.run(check, capture_output=True, text=True)
            self.assertNotEqual(failed.returncode, 0)
            self.assertIn('ROM does not match', failed.stderr)

    def test_no_flash_provisioning_and_pin_drivers(self):
        make = (ROOT / 'Makefile.ulx5m-v72-cfg-registered-probe').read_text()
        src = (ROOT / 'rtl/top-ulx5m-gs-v72-cfg-registered-probe.v').read_text()
        for forbidden in ('openFPGALoader', 'dfu-util', 'flash-write', 'prog_flash'):
            self.assertNotIn(forbidden, make)
        for pin in ('flash_cs_n', 'flash_sck', 'flash_io'):
            self.assertNotIn('assign ' + pin + ' =', src)
        self.assertIn('S_TAIL:', src)
        self.assertIn('S_WAIT:', src)
        self.assertIn('reg cfg_en = 1\'b0', src)
        self.assertIn('--reconfig --bootaddr 2101248', make)

    def test_actual_v70_bootstrap_if_available(self):
        bit = ROOT / 'build-ulx5m-gs/v70-runtime-clear/top_ulx5m_gs_v70_cfg_runtime_clear_probe-seed302-PACK-ONLY.bit'
        if not bit.exists():
            self.fail('pinned original v70 PACK-ONLY bitstream required for v72 qualification')
        self.assertEqual(generator.derive(bit.read_bytes(), bootstrap=True),
                         generator.derive(self.packed))

    def test_registered_iverilog_waveform(self):
        if not shutil.which('iverilog') or not shutil.which('vvp'):
            self.fail('Icarus required: install iverilog/vvp in WSL; an RTL skip must not count as a v72 PASS')
        cmd = ROOT / 'build-ulx5m-gs/v72-registered-probe/cmd.hex'
        if not cmd.exists():
            self.fail('run v72-prepare to create the ROM before RTL simulation')
        with tempfile.TemporaryDirectory() as tmp:
            exe = str(Path(tmp) / 'sim.vvp')
            subprocess.run(['iverilog', '-g2012', '-s', 'tb_ulx5m_v72_cfg_registered',
                '-o', exe,
                str(ROOT/'rtl/top-ulx5m-gs-v72-cfg-registered-probe.v'),
                str(HERE/'tb_ulx5m_v72_cfg_registered.v')], cwd=ROOT, check=True)
            result = subprocess.run(['vvp', exe], cwd=ROOT,
                                    capture_output=True, text=True, check=True)
            self.assertIn('[PASS] v72 registered 27 bytes', result.stdout)


if __name__ == '__main__':
    unittest.main(verbosity=2)
