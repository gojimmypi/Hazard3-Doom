#!/usr/bin/env python3
"""Fail-closed v68 RTL/frame/CRC checks and optional local Icarus simulation."""
import hashlib
import importlib.util
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
MODULE = HERE / 'qualify-ulx5m-v68-cfg-runtime-clear.py'
spec = importlib.util.spec_from_file_location('v68_probe', MODULE)
v68 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(v68)


class V68(unittest.TestCase):
    def test_real_command_frame_crc(self):
        parser = v68.validate_frame()
        self.assertEqual(parser.command_end(v68.FRAME, 0, 0xdb, 12), 18)
        self.assertEqual(v68.FRAME[4:16], v68.STATUS)
        self.assertEqual(v68.FRAME[22], 0x33)
        self.assertEqual(v68.FRAME[6], 0x00)

    def test_only_expected_pack_status(self):
        v68.check_source()
        self.assertEqual(len(v68.FRAME), 27)
        self.assertEqual(v68.FRAME[:4], bytes.fromhex('db0cb87e'))
        self.assertEqual(v68.FRAME[16:18], bytes.fromhex('b13b'))

    def test_makefile_never_programs_flash(self):
        make = v68.MAKEFILE.read_text()
        self.assertIn('v68-build:', make)
        self.assertIn('V68_SEED ?= 302', make)
        self.assertNotIn('openFPGALoader', make)
        self.assertNotIn('--install', make)

    def test_qualifier_rejects_missing_candidate(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(OSError):
                v68.check_candidate(Path(tmp) / 'none.bit', Path(tmp) / 'none.log')

    def test_input_gpio_not_driven(self):
        rtl = v68.RTL.read_text()
        self.assertIn('input  wire [3:0] flash_io', rtl)
        self.assertIn('input  wire flash_cs_n', rtl)
        self.assertIn('input  wire flash_sck', rtl)
        for net in ('flash_io', 'flash_sck', 'flash_cs_n'):
            self.assertNotRegex(rtl, r'assign\s+' + net + r'\s*=')
        self.assertIn('if (stream_done && !recfg)', rtl)

    def test_vendor_timing_simulation(self):
        if not shutil.which('iverilog') or not shutil.which('vvp'):
            self.skipTest('Icarus not installed in this environment; run in WSL')
        with tempfile.TemporaryDirectory() as tmp:
            exe = str(Path(tmp) / 'sim.vvp')
            subprocess.run(['iverilog', '-g2012', '-s', 'tb_ulx5m_v68_cfg_runtime_clear',
                '-o', exe,
                str(ROOT/'rtl'/'ulx5m_cfg_bank_command_stream.v'),
                str(ROOT/'rtl'/'top-ulx5m-gs-v68-cfg-runtime-clear-probe.v'),
                str(HERE/'tb_ulx5m_v68_cfg_runtime_clear.v')],check=True)
            result=subprocess.run(['vvp',exe],capture_output=True,text=True,check=True)
            self.assertIn('[PASS] v68 synthetic 27-byte',result.stdout)


if __name__ == '__main__':
    unittest.main(verbosity=2)
