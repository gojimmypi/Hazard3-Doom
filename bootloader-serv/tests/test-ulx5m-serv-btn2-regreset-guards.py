#!/usr/bin/env python3
"""Guard the separate registered-reset FWT3 experiment and seed-38 build."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
TOP = (ROOT / "rtl/top-ulx5m-gs-flash-read.v").read_text(encoding="ascii")
GATE = (ROOT / "rtl/ulx5m_btn2_dfu_gate.v").read_text(encoding="ascii")
MAKE = (ROOT / "Makefile.ulx5m-gs").read_text(encoding="ascii")
SWEEP = (ROOT / "scripts/sweep-ulx5m-btn2-dfu-quad-regreset-serv.sh").read_text(encoding="ascii")


class Btn2RegisteredResetIsolation(unittest.TestCase):
    def test_default_is_unmodified_combinational_gate(self):
        self.assertIn("parameter integer REGISTERED_RELEASE = 0", GATE)
        self.assertIn("assign dfu_enable = mode_valid && dfu_selected && !rst;", GATE)
        self.assertIn("assign fw_reset = !dfu_enable;", GATE)
        self.assertIn(".REGISTERED_RELEASE(BTN2_REGISTERED_RELEASE)", TOP)
        self.assertIn("`ifdef ULX5M_SERV_BTN2_REGRESET", TOP)
        self.assertIn("localparam integer BTN2_REGISTERED_RELEASE = 0;", TOP)
        self.assertIn("localparam integer BTN2_REGISTERED_RELEASE = 1;", TOP)

    def test_reset_assertion_and_registered_deassertion(self):
        self.assertIn("reg fw_reset_q = 1'b1;", GATE)
        self.assertIn("fw_reset_q <= !(mode_valid && dfu_selected);", GATE)
        self.assertIn("assign fw_reset = rst | fw_reset_q;", GATE)
        self.assertIn("assign dfu_enable = !fw_reset;", GATE)
        self.assertIn(".T(~usb_attach | fw_reset)", TOP)

    def test_unique_build_outputs_and_firmware(self):
        base = "top_ulx5m_gs_flash_read-serv-dfu-hw-quad-btn2"
        self.assertIn("-btn2-regreset.json", MAKE)
        self.assertIn("btn2-dfu-quad-regreset-serv: $(BTN2_DFU_REGRESET_BIT)", MAKE)
        reg_line = next(line for line in MAKE.splitlines()
                        if line.startswith("$(BTN2_DFU_REGRESET_JSON):"))
        self.assertIn("$(DFU_HW_QUAD_FW)", reg_line)
        synth = next(line for line in MAKE.splitlines()
                     if "btn2-dfu-regreset-serv-synth.log" in line)
        self.assertIn("-DULX5M_SERV_BTN2_REGRESET", synth)
        original = next(line for line in MAKE.splitlines()
                        if "btn2-dfu-quad-serv-synth.log" in line)
        self.assertNotIn("-DULX5M_SERV_BTN2_REGRESET", original)
        self.assertIn(base + "-regreset.json", SWEEP)
        self.assertNotIn("flash-read-serv.json", SWEEP)


if __name__ == "__main__":
    unittest.main(verbosity=2)
