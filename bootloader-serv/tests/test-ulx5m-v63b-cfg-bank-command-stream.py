#!/usr/bin/env python3
"""v63b fail-closed offline checks. Never programs or reads hardware."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
RTL = ROOT / "rtl/ulx5m_cfg_bank_command_stream.v"
TB = ROOT / "tests/tb_ulx5m_v63b_cfg_bank_command_stream.v"
PRIMARY = ROOT / "rtl/ulx5m_spi_active_reboot_wb.v"
MAKE = ROOT / "Makefile.ulx5m-spi-secondary"


class V63bBankStream(unittest.TestCase):
    def test_explicit_default_off_and_no_recfg_output(self):
        src = RTL.read_text(encoding="ascii")
        self.assertIn("parameter integer COMMAND_LEN = 0", src)
        self.assertIn("COMMAND_LEN < 1", src)
        self.assertIn("COMMAND_LEN > 64", src)
        self.assertIn("normal_mode", src)
        self.assertIn("spi_released", src)
        self.assertNotIn("CC_CFG_CTRL cfg_i", src)
        self.assertNotIn("output wire cfg_recfg", src)

    def test_working_v60_recfg_controller_untouched(self):
        src = PRIMARY.read_text(encoding="ascii")
        self.assertIn(".CLK(1'b0), .EN(1'b0), .DATA(8'b0)", src)
        self.assertIn(".VALID(1'b0), .RECFG(recfg)", src)
        self.assertIn("if (handoff_pending) begin", src)
        self.assertIn("release_spi <= 1'b1;", src)

    def test_no_production_integration(self):
        src = MAKE.read_text(encoding="ascii")
        self.assertNotIn("ulx5m_cfg_bank_command_stream.v", src)
        self.assertIn("--bootaddr $(SPI_SECONDARY_ADDR)", src)
        self.assertNotIn("--reconfig", src)
        for rel in ("rtl/top-ulx5m-gs-flash-read.v",):
            self.assertNotIn("ulx5m_cfg_bank_command_stream", (ROOT / rel).read_text(encoding="ascii"))

    def test_iverilog_synthetic_timing(self):
        iv = shutil.which("iverilog")
        vv = shutil.which("vvp")
        if iv is None or vv is None:
            self.skipTest("Icarus Verilog not installed; run this test in WSL")
        with tempfile.TemporaryDirectory(prefix="ulx5m-v63b-") as d:
            target = str(Path(d) / "sim.vvp")
            subprocess.run([iv, "-g2012", "-s", "tb_ulx5m_v63b_cfg_bank_command_stream",
                            "-o", target, str(TB), str(RTL)], check=True)
            subprocess.run([vv, target], check=True)


if __name__ == "__main__":
    unittest.main(verbosity=2)
