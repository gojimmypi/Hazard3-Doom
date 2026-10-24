#!/usr/bin/env python3
"""Check isolation and reset structure of the BTN2 async-reset experiment."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
GATE = (ROOT / "rtl/ulx5m_btn2_dfu_gate.v").read_text(encoding="ascii")
TOP = (ROOT / "rtl/top-ulx5m-gs-flash-read.v").read_text(encoding="ascii")
MAKE = (ROOT / "Makefile.ulx5m-gs").read_text(encoding="ascii")
SWEEP = (ROOT / "scripts/sweep-ulx5m-btn2-dfu-quad-asyncreset-serv.sh").read_text(encoding="ascii")

class Btn2AsyncResetIsolation(unittest.TestCase):
    def test_async_assert_sync_release(self):
        block = GATE.split('begin : g_async_registered_release')[1].split('end else if')[0]
        self.assertIn('always @(posedge clk or posedge rst)', block)
        self.assertIn("fw_reset_q <= 1'b1;", block)
        self.assertIn('fw_reset_q <= !(mode_valid && dfu_selected);', block)
        self.assertIn('assign fw_reset = fw_reset_q;', block)
        self.assertIn('assign dfu_enable = !fw_reset_q;', block)
        self.assertNotIn('rst | fw_reset_q', block)
        self.assertIn('REGISTERED_RELEASE == 2', GATE)

    def test_existing_variants_and_usb_guard_preserved(self):
        self.assertIn('assign fw_reset = rst | fw_reset_q;', GATE)
        self.assertIn('assign dfu_enable = mode_valid && dfu_selected && !rst;', GATE)
        self.assertIn('assign fw_reset = !dfu_enable;', GATE)
        self.assertIn('`ifdef ULX5M_SERV_BTN2_ASYNC_REGRESET', TOP)
        self.assertIn('localparam integer BTN2_REGISTERED_RELEASE = 2;', TOP)
        self.assertIn('`ifdef ULX5M_SERV_BTN2_REGRESET', TOP)
        self.assertIn('.T(~usb_attach | fw_reset)', TOP)

    def test_unique_build_outputs_and_firmware(self):
        self.assertIn('-btn2-asyncreset.json', MAKE)
        self.assertIn('btn2-dfu-quad-asyncreset-serv: $(BTN2_DFU_ASYNCRESET_BIT)', MAKE)
        rule = next(x for x in MAKE.splitlines()
                    if x.startswith('$(BTN2_DFU_ASYNCRESET_JSON):'))
        self.assertIn('$(DFU_HW_QUAD_FW)', rule)
        synth = next(x for x in MAKE.splitlines()
                     if 'btn2-dfu-asyncreset-serv-synth.log' in x)
        self.assertIn('-DULX5M_SERV_BTN2_ASYNC_REGRESET', synth)
        base = next(x for x in MAKE.splitlines()
                    if 'btn2-dfu-quad-serv-synth.log' in x)
        self.assertNotIn('-DULX5M_SERV_BTN2_ASYNC_REGRESET', base)
        old = next(x for x in MAKE.splitlines()
                   if 'btn2-dfu-regreset-serv-synth.log' in x)
        self.assertNotIn('-DULX5M_SERV_BTN2_ASYNC_REGRESET', old)
        self.assertIn('top_ulx5m_gs_flash_read-serv-dfu-hw-quad-btn2-asyncreset.json', SWEEP)
        self.assertNotIn('btn2-regreset.json', SWEEP)
        self.assertNotIn('flash-read-serv.json', SWEEP)

if __name__ == '__main__':
    unittest.main(verbosity=2)
