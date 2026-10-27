#!/usr/bin/env python3
"""Offline v65 source, pin, command and (when available) Icarus tests."""
import importlib.util
import hashlib
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
RTL = ROOT / 'rtl/top-ulx5m-gs-v65-multiboot-probe.v'
CCF = ROOT / 'data/top-ulx5m-gs-v65-multiboot-probe.ccf'
SDC = ROOT / 'data/top-ulx5m-gs-v65-multiboot-probe.sdc'
MAKE = ROOT / 'Makefile.ulx5m-v65-multiboot-probe'
SOURCE = Path(__file__).with_name('qualify-ulx5m-v65-multiboot-probe.py')
spec = importlib.util.spec_from_file_location('ulx5m_v65_probe_qual', SOURCE)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


def sample(status=None):
    """Synthetic frame, not a hardware-verified gmpack primary."""
    status = (bytes.fromhex('17 10 00 20 00 00 00 00 00 00 00 00')
              if status is None else status)
    if len(status) != 12:
        raise ValueError('status must be 12 bytes')
    header = b'\xdb\x0c'
    c1 = mod.crc16_x25(header).to_bytes(2, 'little')
    c2 = mod.crc16_x25(header + c1 + status).to_bytes(2, 'little')
    return bytes.fromhex('d9 01 ed 96') + bytes(range(4, 100)) + \
        header + c1 + status + c2 + mod.EXEC + mod.TRAILER


class V65(unittest.TestCase):
    def test_no_flash_pin_users(self):
        source = RTL.read_text(encoding='ascii')
        for needle in ('flash_io', 'spi_cs', 'flash_sck', 'usb_', 'qspi_', 'serv_', 'btn_n', 'CC_IOBUF', 'CC_TOBUF'):
            self.assertNotIn(needle, source)
        self.assertEqual(source.count('CC_CFG_CTRL cfg_i ('), 1)
        self.assertIn(".CLK(1'b0), .EN(1'b0), .DATA(8'b0)", source)
        self.assertIn(".VALID(1'b0), .RECFG(recfg)", source)
        self.assertIn('wire recfg = &start_count;', source)

    def test_constraints_only_clock_and_led(self):
        ccf = CCF.read_text(encoding='ascii')
        actual = [line.split('"')[1] for line in ccf.splitlines() if line.startswith('Pin_')]
        self.assertEqual(actual, ['clk25'] + [f'led_n[{i}]' for i in range(8)])
        self.assertTrue(all('IO_SB_' in line for line in ccf.splitlines() if line.startswith('Pin_')))
        self.assertIn('create_clock -name clk25 -period 40.000', SDC.read_text(encoding='ascii'))

    def test_build_target_never_programs_and_no_reconfig_flag(self):
        make = MAKE.read_text(encoding='ascii')
        self.assertFalse(any(line.startswith('include ') for line in make.splitlines()))
        self.assertIn('$(GMPACK) --bootaddr $(V65_BOOTADDR)', make)
        self.assertIn('V65_BOOTADDR := 2101248', make)
        self.assertNotIn('--reconfig', make)
        for line in make.splitlines():
            if line.startswith('\t'):
                self.assertNotIn('openFPGALoader', line)
        self.assertNotIn('-f --verify --offset', make)

    def test_valid_mock_command_rejected_on_status_corruption(self):
        good = sample()
        self.assertEqual(mod.inspect(good)['jump_address'], 0x201000)
        # The old v65 validator incorrectly required SERV-only 08 21 C3.
        self.assertEqual(mod.inspect(good)['status'],
                         '171000200000000000000000')
        # The actual v60 SERV-style status is also valid when <=64 KiB.
        serv = sample(bytes.fromhex('17 10 08 21 c3 00 00 00 00 00 00 00'))
        self.assertEqual(mod.inspect(serv)['jump_address'], 0x201000)
        for which in (len(good)-19+11, 100+4, 100+4+12):
            bad = bytearray(good)
            bad[which] ^= 1
            with self.assertRaises(ValueError):
                mod.inspect(bad)

    def test_status_flag_checks_and_crc_protection(self):
        # Both 0x17 and 0x1f appear in CRC-valid --bootaddr images.
        # The reconfig bit 0x08 is not unconditionally zero.
        self.assertEqual(mod.inspect(sample(bytes.fromhex('1f 10') + bytes(10)))['jump_address'], 0x201000)
        for first_byte in (0x13, 0x1b, 0x03, 0x07, 0x0f, 0x37, 0x97):
            with self.assertRaises(ValueError):
                mod.inspect(sample(bytes([first_byte, 0x10]) + bytes(10)))
        # A mode different from --bootaddr is not accepted even if CRCs match.
        with self.assertRaises(ValueError):
            mod.inspect(sample(bytes.fromhex('17 1f 00 20 00 00 00 00 00 00 00 00')))
        good = bytearray(sample())
        good[-4] ^= 1  # corrupt jump CRC
        with self.assertRaises(ValueError):
            mod.inspect(good)
        good = bytearray(sample())
        good[0] ^= 1  # corrupt GateMate prefix
        with self.assertRaises(ValueError):
            mod.inspect(good)

    def test_real_jtag_proven_led_source_has_distinct_status_bytes(self):
        # Ground this regression in a genuine gmpack output supplied with
        # the project, not a synthetic payload copied from the SERV primary.
        ref = ROOT / 'build-ulx5m-gs/top_ulx5m_gs_normal_led.bit'
        data = ref.read_bytes()
        self.assertEqual(len(data), 3026)
        self.assertEqual(hashlib.sha256(data).hexdigest(),
                         '68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd')
        pos = len(data) - 27
        self.assertEqual(mod.command_end(data, pos, 0xdb, 12), len(data) - 9)
        self.assertEqual(data[pos + 4:pos + 16],
                         bytes.fromhex('13 1f 00 20 00 00 00 00 00 00 00 00'))
        # Fabric-specific status differs from the SERV `08 21 c3` sequence.
        self.assertNotEqual(data[pos + 6:pos + 9], bytes.fromhex('08 21 c3'))
        # Known original is NOT a bootaddr candidate; must be rejected.
        with self.assertRaises(ValueError):
            mod.inspect(data)

    def test_v65c_qualifier_version(self):
        self.assertEqual(mod.QUALIFIER_REVISION, 'v65c-20261027-accept-17-or-1f')

    def test_real_v43_bootaddr_reconfiguration_status(self):
        # Genuine gmpack output previously built locally on ULX5M. This
        # regression is the exact format that broke the v65a validator.
        ref = ROOT / 'build-ulx5m-gs/cfg-probe/top_ulx5m_gs_cfg_probe-bootaddr-201000-v43.bit'
        if not ref.is_file():
            self.skipTest('v43 bootaddr reference missing; synthetic 0x1f test still runs')
        data = ref.read_bytes()
        self.assertEqual(len(data), 31430)
        self.assertEqual(hashlib.sha256(data).hexdigest(),
                         '2195166eb2035d9fb0ca22d99b37fd4ea8ba49488e808cf864eee0df127dddc0')
        info = mod.inspect(data)
        self.assertEqual(info['jump_address'], 0x201000)
        self.assertEqual(info['status'][:4], '1f10')
        altered = bytearray(data)
        altered[info['status_offset'] + 4] &= ~0x04  # Lose bootaddr bit
        with self.assertRaises(ValueError):
            mod.inspect(bytes(altered))
        altered = bytearray(data)
        altered[-5] ^= 1  # Corrupt jump trailer
        with self.assertRaises(ValueError):
            mod.inspect(bytes(altered))

    def test_invalid_overlap_or_truncated(self):
        with self.assertRaises(ValueError):
            mod.inspect(sample()[:100])
        with self.assertRaises(ValueError):
            mod.inspect(sample() + b'\x00')
        with self.assertRaises(ValueError):
            mod.inspect(sample() + b'\xff' * 65536)

    def test_timing_last_result_wins(self):
        self.assertEqual(mod.check_timing("Info: Max frequency for clock 'clk25': 34.25 MHz (PASS at 25.00 MHz)"), '34.25')
        with self.assertRaises(ValueError):
            mod.check_timing("Info: Max frequency for clock 'clk25': 34.25 MHz (PASS at 25.00 MHz)\nERROR: Max frequency for clock 'clk25': 23.00 MHz (FAIL at 25.00 MHz)")
        with self.assertRaises(ValueError):
            mod.check_timing('no timing evidence')

    def test_simulation(self):
        if not shutil.which('iverilog') or not shutil.which('vvp'):
            self.skipTest('Icarus missing here; must run on WSL')
        with tempfile.TemporaryDirectory() as d:
            out = Path(d) / 'tb.vvp'
            subprocess.run(['iverilog', '-g2012', '-s', 'tb_ulx5m_v65_multiboot_probe',
                            '-o', str(out), str(RTL),
                            str(ROOT / 'tests/tb_ulx5m_v65_multiboot_probe.v')],
                           check=True, timeout=30)
            subprocess.run(['vvp', str(out)], check=True, timeout=30)


if __name__ == '__main__':
    unittest.main(verbosity=2)
