#!/usr/bin/env python3
"""Check the isolated normal-boot Wishbone read fix and its HDL regression."""
import pathlib
import re
import shutil
import subprocess
import tempfile
import unittest

BASE = pathlib.Path(__file__).resolve().parents[1]
TOP = BASE / "rtl/top-ulx5m-gs-flash-read.v"


class MiscReadIsolationTest(unittest.TestCase):
    def test_normal_boot_masks_inactive_misc_read(self):
        source = TOP.read_text(encoding="ascii")
        self.assertIn("assign wb_rdata[0] = wb_cyc[0] ? misc_rdata : 32'h00000000;", source)
        self.assertIn(".bus_rdata(misc_rdata)", source)
        self.assertEqual(source.count(".bus_rdata(wb_rdata[0])"), 1)
        # Restrict the new mask to the combined normal-boot build.
        self.assertRegex(source, re.compile(
            r"`ifdef ULX5M_SERV_NORMAL_BOOT_EXPERIMENT\n"
            r"    wire \[31:0\] misc_rdata;\n"
            r"    assign wb_rdata\[0\] = wb_cyc\[0\] \? misc_rdata : 32'h00000000;\n"
            r"`endif", re.M))

    def test_previous_usb_gate_restored(self):
        source = TOP.read_text(encoding="ascii")
        self.assertIn("wire usb_core_reset = fw_reset | ~dfu_enable;", source)
        self.assertNotIn("wire usb_core_reset = fw_reset | ~dfu_selected;", source)
        self.assertIn(".T(~usb_attach | usb_core_reset)", source)

    def test_actual_misc_rtl_simulation(self):
        if not (shutil.which("iverilog") and shutil.which("vvp")):
            self.skipTest("Icarus not available here; MUST run in WSL before synthesis")
        with tempfile.TemporaryDirectory(prefix="ulx5m-wb-") as tmp:
            out = pathlib.Path(tmp) / "wb.vvp"
            subprocess.run([
                "iverilog", "-g2012", "-DULX5M_SERV_NORMAL_BOOT_EXPERIMENT",
                "-s", "tb_ulx5m_normal_boot_wb_isolation",
                "-o", str(out), str(BASE / "rtl/soc_ulx5m_misc.v"),
                str(BASE / "tests/tb_ulx5m_normal_boot_wb_isolation.v")
            ], check=True)
            result = subprocess.run(["vvp", str(out)], check=True,
                                    capture_output=True, text=True)
            self.assertIn("[PASS] Active DFU mode register read preserved", result.stdout)
            self.assertIn("[PASS] Inactive misc readback cannot corrupt USB CSR", result.stdout)
            print(result.stdout, end="")


if __name__ == "__main__":
    unittest.main(verbosity=2)
