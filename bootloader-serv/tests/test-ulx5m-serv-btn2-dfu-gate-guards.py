#!/usr/bin/env python3
# Used by .github/workflows/ulx5m-serv-tests.yml
"""Static guard for the isolated BTN2-gated ULX5M FWT3 build."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
TOP = (ROOT / "rtl/top-ulx5m-gs-flash-read.v").read_text(encoding="ascii")
MAKE = (ROOT / "Makefile.ulx5m-gs").read_text(encoding="ascii")
GATE = (ROOT / "rtl/ulx5m_btn2_dfu_gate.v").read_text(encoding="ascii")
CCF = (ROOT / "data/top-ulx5m-gs-flash-read.ccf").read_text(encoding="ascii")


class Btn2DfuIsolation(unittest.TestCase):
    def test_middle_button_and_selection(self):
        self.assertIn(".btn2_n(btn_n[1])", TOP)
        self.assertIn('"btn_n[1]"    Loc = "IO_EA_A4"', CCF)
        self.assertIn("mode_valid && dfu_selected && !rst", GATE)
        self.assertIn("assign fw_reset = !dfu_enable;", GATE)

    def test_peripheral_resets_and_attach_guard(self):
        self.assertIn("`ifdef ULX5M_SERV_BTN2_DFU_GATE", TOP)
        self.assertIn("assign fw_reset = reset;", TOP)
        self.assertIn(".resetn(~fw_reset)", TOP)
        self.assertGreaterEqual(TOP.count(".rst(fw_reset)"), 8)
        # Legacy BTN2-only builds still use fw_reset for USB and pullup.
        # The normal-boot experiment additionally disconnects USB in normal mode.
        self.assertRegex(
            TOP,
            r"`ifdef ULX5M_SERV_NORMAL_BOOT_EXPERIMENT\s+"
            r"wire usb_core_reset = fw_reset \| ~dfu_enable;\s+"
            r"`else\s+wire usb_core_reset = fw_reset;\s+`endif",
        )
        self.assertIn(".rst(usb_core_reset)", TOP)
        self.assertIn(".T(~usb_attach | usb_core_reset)", TOP)
        self.assertIn("assign dfu_enable = mode_valid && dfu_selected && !reset;", TOP)
        self.assertIn("if (fw_reset)\n            wb_ack_ep", TOP)
        self.assertIn(".led_n(fw_led_n)", TOP)

    def test_isolated_trace_read_experiment(self):
        usb = (ROOT / "cores/usb/rtl/usb.v").read_text(encoding="ascii")
        raw = (ROOT / "cores/usb/rtl/usb_ep0_raw_capture.v").read_text(encoding="ascii")
        self.assertIn(".EP0_RAW_FREE_READ(1)", TOP)
        self.assertIn("`ifdef ULX5M_SERV_BTN2_DFU_GATE\n           .EP0_RAW_FREE_READ(1)", TOP)
        self.assertIn("parameter integer EP0_RAW_FREE_READ = 0", usb)
        self.assertIn(".FREE_RUNNING_READ(EP0_RAW_FREE_READ)", usb)
        self.assertIn("parameter integer FREE_RUNNING_READ = 0", raw)
        self.assertIn("generate if (FREE_RUNNING_READ)", raw)
        self.assertIn("if (rd_en)", raw)
        self.assertIn("test-btn2-raw-read:", MAKE)

    def test_isolated_build_and_firmware(self):
        self.assertIn("btn2-dfu-quad-serv: $(BTN2_DFU_QUAD_BIT)", MAKE)
        self.assertIn("BTN2_DFU_QUAD_SRC := $(SERV_SRC) rtl/ulx5m_btn2_boot_select.v rtl/ulx5m_btn2_dfu_gate.v", MAKE)
        self.assertIn("$(BTN2_DFU_QUAD_JSON): $(DFU_HW_QUAD_FW)", MAKE)
        self.assertIn("-DULX5M_SERV_BTN2_DFU_GATE", MAKE)
        self.assertIn("-DULX5M_SERV_DFU_HW_QUAD_TEST", MAKE)
        # Do not accidentally add the selector to the known-good 16 KiB profile.
        quad_line = next(l for l in MAKE.splitlines() if l.startswith("$(DFU_HW_QUAD_JSON):"))
        self.assertNotIn("BTN2", quad_line)
        quad_synth = next(l for l in MAKE.splitlines() if "dfu-hw-quad-serv-synth.log" in l)
        self.assertNotIn("BTN2", quad_synth)


if __name__ == "__main__":
    unittest.main(verbosity=2)
