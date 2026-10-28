#!/usr/bin/env python3
"""Offline regression of v73 registered engine and isolated native DFU build."""
import hashlib
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
RTL = ROOT / 'rtl/ulx5m_spi_active_reboot_wb.v'
TOP = ROOT / 'rtl/top-ulx5m-gs-flash-read.v'
MK = ROOT / 'Makefile.ulx5m-v73-integrated'
BIT = ROOT / 'build-ulx5m-gs/v72-registered-probe/top_ulx5m_gs_v72_cfg_registered_probe-seed302-PACK-ONLY.bit'


class V73Integrated(unittest.TestCase):
    def test_proven_v72_bootstrap(self):
        self.assertTrue(BIT.exists(), 'missing exact v72 hardware-proven .bit')
        self.assertEqual(hashlib.sha256(BIT.read_bytes()).hexdigest(),
                         '839696d7c8a4ecdf63dff904c01ce85aea280bd885eda4309c7e5d25800e3aa0')

    def test_guarded_build_and_isolated_hex(self):
        mk = MK.read_text(encoding='ascii')
        top = TOP.read_text(encoding='ascii')
        self.assertIn('V73_DIR := build-ulx5m-gs/v73-normal-boot-dfu-hw-native', mk)
        self.assertIn('NATIVE_SPI_SECONDARY=1', mk)
        self.assertIn('DFU_HW_NATIVE_TEST_ONLY=1', mk)
        self.assertIn('ULX5M_V73_REGISTERED_REBOOT', mk)
        self.assertIn('ULX5M_SERV_BTN2_DFU_GATE', mk)
        self.assertIn('localparam FW_IMAGE = "build-ulx5m-gs/v73-normal-boot-dfu-hw-native/fw_ulx5m_flash_read.hex";', top)
        self.assertIn('wire usb_core_reset = fw_reset | ~dfu_enable;', top)
        self.assertIn('assign wb_rdata[0] = wb_cyc[0] ? misc_rdata : 32\'h00000000;', top)
        self.assertNotIn('openFPGALoader', mk)
        self.assertNotIn('dfu-util', mk)

    def test_boot_wishbone_and_registered_fsm_present(self):
        src = RTL.read_text(encoding='ascii')
        for required in ('ARM_KEY', 'BOOT_KEY', 'qualified && !error',
                         'release_spi <= 1\'b1;', 'S_RELEASE', 'S_EN',
                         'S_SEND', 'S_NEXT', 'S_TAIL', 'S_WAIT', 'S_RECFG',
                         '.CLK(clk), .EN(cfg_en), .DATA(cfg_data)',
                         'if (rst || !normal_mode)',
                         'cfg_state != S_RECFG && !spi_idle',
                         "cfg_count == 6'd63",
                         "cfg_count == 6'd7",
                         "cfg_count == 6'd2",
                         "cfg_count == 6'd15",
                         "cfg_count == 6'd31"):
            self.assertIn(required, src)

    def test_v76_hw_normal_boot(self):
        src = RTL.read_text(encoding='ascii')
        top = TOP.read_text(encoding='ascii')
        mk = MK.read_text(encoding='ascii')
        self.assertIn('-DULX5M_V76_HW_NORMAL_BOOT', mk)
        self.assertIn('if (!fired && cfg_state == S_IDLE && (&spi_idle_cycles)', src)
        self.assertIn('.release_to_config(release_spi_for_config | v76_hardware_boot)', top)
        self.assertIn('.rst(fw_reset)', top)
        self.assertNotIn('.rst(fw_reset | v76_hardware_boot)', top)
        self.assertIn(".spi_idle(1'b1)", top)
        if not (shutil.which('iverilog') and shutil.which('vvp')):
            self.skipTest('Icarus unavailable here; v73-test target MUST fail closed in WSL')
        with tempfile.TemporaryDirectory(prefix='ulx5m-v76-') as work:
            vvp = Path(work) / 'test.vvp'
            subprocess.run(['iverilog', '-g2012',
                            '-DULX5M_V73_REGISTERED_REBOOT',
                            '-DULX5M_V76_HW_NORMAL_BOOT',
                            '-s', 'tb_ulx5m_v76_hw_normal_boot', '-o', str(vvp),
                            str(RTL), str(ROOT / 'tests/tb_ulx5m_v76_hw_normal_boot.v')],
                           cwd=ROOT, check=True)
            test = subprocess.run(['vvp', str(vvp)], cwd=ROOT,
                                  capture_output=True, text=True, check=True)
            self.assertIn('[PASS] v76 autonomous normal handoff', test.stdout)
            print(test.stdout, end='')

    def test_v78_v72_startup_hold(self):
        src = RTL.read_text(encoding='ascii')
        mk = MK.read_text(encoding='ascii')
        self.assertIn('-DULX5M_V78_V72_STARTUP_DELAY', mk)
        self.assertIn('parameter integer V78_BOOT_DELAY_CYCLES = 128849019', src)
        self.assertIn('&& v78_boot_ready', src)
        self.assertIn('&& 1\'b0', src)
        if not (shutil.which('iverilog') and shutil.which('vvp')):
            self.skipTest('Icarus unavailable here; v73-test target MUST fail closed in WSL')
        with tempfile.TemporaryDirectory(prefix='ulx5m-v78-') as work:
            vvp = Path(work) / 'test.vvp'
            subprocess.run(['iverilog', '-g2012',
                            '-DULX5M_V73_REGISTERED_REBOOT',
                            '-DULX5M_V76_HW_NORMAL_BOOT',
                            '-DULX5M_V78_V72_STARTUP_DELAY',
                            '-s', 'tb_ulx5m_v78_v72_startup_hold', '-o', str(vvp),
                            str(RTL), str(ROOT / 'tests/tb_ulx5m_v78_v72_startup_hold.v')],
                           cwd=ROOT, check=True)
            result = subprocess.run(['vvp', str(vvp)], cwd=ROOT,
                                    capture_output=True, text=True, check=True)
            self.assertIn('[PASS] v78 v72-equivalent startup hold', result.stdout)
            print(result.stdout, end='')

    def test_real_registered_waveform(self):
        if not (shutil.which('iverilog') and shutil.which('vvp')):
            self.skipTest('Icarus unavailable here; v73-test target MUST fail closed in WSL')
        with tempfile.TemporaryDirectory(prefix='ulx5m-v73-') as work:
            vvp = Path(work) / 'test.vvp'
            subprocess.run(['iverilog', '-g2012',
                            '-DULX5M_V73_REGISTERED_REBOOT',
                            '-s', 'tb_ulx5m_v73_integrated', '-o', str(vvp),
                            str(RTL), str(ROOT / 'tests/tb_ulx5m_v73_integrated.v')],
                           cwd=ROOT, check=True)
            test = subprocess.run(['vvp', str(vvp)], cwd=ROOT,
                                  capture_output=True, text=True, check=True)
            self.assertIn('[PASS] v73 DFU gate, ARM/BOOT, 27 bytes', test.stdout)
            print(test.stdout, end='')


if __name__ == '__main__':
    unittest.main(verbosity=2)
