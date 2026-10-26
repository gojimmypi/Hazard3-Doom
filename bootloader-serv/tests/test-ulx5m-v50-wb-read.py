#!/usr/bin/env python3
"""v50: verify the actual stale-Wishbone-data failure and the isolated fix."""
import pathlib
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class UsbWishboneRegression(unittest.TestCase):
    def test_spi_secondary_uses_existing_read_decoder(self):
        source = (ROOT / "rtl/top-ulx5m-gs-flash-read.v").read_text(encoding="ascii")
        self.assertRegex(source, re.compile(
            r"\.WB_REG\(4\), \.BRAM_REG\(1\)\s*"
            r"`ifdef ULX5M_SERV_SPI_ACTIVE_SECONDARY\s*"
            r"(?://[^\n]*\n\s*)*"
            r", \.WB_DECODE_RDATA\(1\)\s*`endif"
        ))
        self.assertEqual(source.count(".WB_DECODE_RDATA(1)"), 1)
        bridge = (ROOT / "rtl/soc_bridge.v").read_text(encoding="ascii")
        self.assertIn("if (!WB_DECODE_RDATA || wb_cyc[i])", bridge)
        self.assertIn(".bus_rdata(wb_rdata[0])", source)
        self.assertIn(".bus_dout(wb_rdata[2][15:0])", source)

    def test_no_usb_protocol_or_flash_writer_changes(self):
        # This v50 fix is only the existing bridge option, not new USB logic.
        source = (ROOT / "rtl/top-ulx5m-gs-flash-read.v").read_text(encoding="ascii")
        self.assertIn("usb_core_reset = fw_reset | ~dfu_selected", source)
        self.assertIn(".T(~usb_attach | usb_core_reset)", source)

    def test_real_bridge_failure_and_fix(self):
        if not (shutil.which("iverilog") and shutil.which("vvp")):
            self.skipTest("Icarus unavailable here; run under WSL before building")
        with tempfile.TemporaryDirectory(prefix="ulx5m-v50-") as d:
            for selected, expected in [(0, "v47 bug reproduced"), (1, "v50 fix")]:
                binary = pathlib.Path(d) / ("masked" if selected else "unmasked")
                subprocess.run([
                    "iverilog", "-g2012", "-DULX5M_SERV_NORMAL_BOOT_EXPERIMENT",
                    "-P", "tb_ulx5m_v50_usb_wb_read.SELECTED=" + str(selected),
                    "-s", "tb_ulx5m_v50_usb_wb_read", "-o", str(binary),
                    "rtl/soc_bridge.v", "rtl/soc_ulx5m_misc.v",
                    "tests/tb_ulx5m_v50_usb_wb_read.v",
                ], cwd=ROOT, check=True)
                result = subprocess.run(["vvp", str(binary)], cwd=ROOT,
                                        capture_output=True, text=True, check=True)
                self.assertIn(expected, result.stdout)
                print(result.stdout.strip())


if __name__ == "__main__":
    unittest.main(verbosity=2)
