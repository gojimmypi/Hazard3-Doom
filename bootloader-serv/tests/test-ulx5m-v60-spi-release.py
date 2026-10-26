#!/usr/bin/env python3
"""Read-only v60 SPI-bus handoff tests. Does not access FPGA or flash."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class V60(unittest.TestCase):
    def source(self, path):
        return (ROOT / path).read_text(encoding="ascii")

    def test_release_precedes_recfg(self):
        code = self.source("rtl/ulx5m_spi_active_reboot_wb.v")
        self.assertIn("release_spi <= 1'b1;", code)
        self.assertIn("handoff_pending <= 1'b1;", code)
        self.assertIn("if (handoff_pending) begin", code)
        self.assertIn("recfg <= 1'b1;", code)
        self.assertIn("release_spi <= 0;", code)
        self.assertIn("if (rst || !normal_mode)", code)

    def test_no_usb_or_firmware_edits(self):
        top = self.source("rtl/top-ulx5m-gs-flash-read.v")
        self.assertIn(".release_spi(release_spi_for_config)", top)
        self.assertIn(".release_to_config(release_spi_for_config)", top)
        self.assertIn("assign release_spi_for_config = 1'b0;", top)
        self.assertIn("`ifndef ULX5M_SERV_SPI_ACTIVE_SECONDARY", top)

    def test_physically_releases_all_flash_pins(self):
        phy = self.source("rtl/qspi_phy_gatemate.v")
        self.assertIn(".T(io_tristate[i] | release_to_config)", phy)
        self.assertIn(".T(release_to_config), .O(spi_cs[j])", phy)
        self.assertIn(".T(release_to_config), .O(spi_sck)", phy)
        self.assertIn('CC_TOBUF #(.V_IO("1.8"))', phy)

    def sim(self, tb, sources, top, defines=()):
        tool = shutil.which("iverilog")
        runner = shutil.which("vvp")
        if tool is None or runner is None:
            self.skipTest("iverilog/vvp not present; run in WSL")
        with tempfile.TemporaryDirectory() as dirname:
            exe = Path(dirname) / "test.vvp"
            subprocess.run([tool, "-g2012", *("-D" + name for name in defines),
                            "-s", top, "-o", str(exe),
                            str(ROOT / "tests" / tb),
                            *(str(ROOT / "rtl" / src) for src in sources)],
                           check=True)
            subprocess.run([runner, str(exe)], check=True)

    def test_recfg_controller_sim(self):
        self.sim("tb_ulx5m_spi_active_reboot.v",
                 ["ulx5m_spi_active_reboot_wb.v"],
                 "tb_ulx5m_spi_active_reboot")

    def test_spi_pin_tristate_sim(self):
        # The installed SPI-primary build selects CC_TOBUF with this define.
        # Without it, the legacy PHY drives CS/SCK and this test fails.
        self.sim("tb_ulx5m_v60_spi_release.v",
                 ["qspi_phy_gatemate.v"],
                 "tb_ulx5m_v60_spi_release",
                 defines=("ULX5M_SERV_SPI_ACTIVE_SECONDARY",))


if __name__ == "__main__":
    unittest.main(verbosity=2)
