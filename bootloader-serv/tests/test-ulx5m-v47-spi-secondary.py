#!/usr/bin/env python3
"""Read-only v47 regression gates; never invoke a programmer or flash writer."""
import hashlib
import pathlib
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
APP_DIGEST = "68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd"
SECTOR_DIGEST = "28b1e5cbfa45a319600ec38c81207a36d9889c3179e8055f5a663c616ef97bee"


def text(path):
    return (ROOT / path).read_text(encoding="ascii")


class V47(unittest.TestCase):
    def test_native_slot_and_independent_sector(self):
        app = ROOT / "build-ulx5m-gs/top_ulx5m_gs_normal_led.bit"
        sector = ROOT / "build-ulx5m-gs/fwtn-jtag-201000-tailfix-4096.bin"
        if not app.is_file() or not sector.is_file():
            self.skipTest("archived v41 files are not in working tree")
        a, s = app.read_bytes(), sector.read_bytes()
        self.assertEqual(len(a), 3026)
        self.assertEqual(len(s), 4096)
        self.assertEqual(hashlib.sha256(a).hexdigest(), APP_DIGEST)
        self.assertEqual(hashlib.sha256(s).hexdigest(), SECTOR_DIGEST)
        self.assertEqual(s[:len(a)], a)
        self.assertEqual(s[len(a):], b"\xff" * 1070)

    def test_vendor_recfg_only(self):
        rtl = text("rtl/ulx5m_spi_active_reboot_wb.v")
        self.assertIn(".RECFG(recfg)", rtl)
        self.assertIn(".CLK(1'b0)", rtl)
        self.assertIn(".VALID(1'b0)", rtl)
        self.assertIn(".EN(1'b0)", rtl)
        self.assertNotIn(".VALID(valid)", rtl)

    def test_gate_requires_two_keys_and_idle(self):
        rtl = text("rtl/ulx5m_spi_active_reboot_wb.v")
        for frag in ("32'h41524d31", "32'h424f4f54",
                     "normal_mode && spi_idle", "if (armed)",
                     "!fired", "recfg <= 1'b1", "if (rst || !normal_mode)"):
            self.assertIn(frag, rtl)

    def test_normal_mode_uses_hardware_not_old_streamer(self):
        rtl = text("rtl/top-ulx5m-gs-flash-read.v")
        self.assertIn("`ifdef ULX5M_SERV_SPI_ACTIVE_SECONDARY", rtl)
        self.assertRegex(rtl, r"ulx5m_spi_active_reboot_wb\s*(?:#\s*\([^;]*\))?\s*cfg_stream_i\s*\(")
        self.assertIn("ulx5m_cfg_stream_wb cfg_stream_i", rtl)
        self.assertIn("usb_core_reset = fw_reset | ~dfu_selected", rtl)

    def test_firmware_reader_and_dfu_precedence(self):
        firmware = text("fw/fw_ulx5m_flash_read.c")
        driver = text("fw/ulx5m_spi_active_boot.c")
        self.assertIn("ulx5m_spi_active_boot_run(&image_reader, &gate, 0)", firmware)
        self.assertLess(driver.index("ulx5m_v41_native_probe"), driver.index("gate->arm(gate->ctx,"))
        self.assertLess(driver.index("gate->release_flash(gate->ctx)"), driver.index("gate->arm(gate->ctx,"))
        self.assertLess(driver.index("gate->arm(gate->ctx,"), driver.index("gate->execute(gate->ctx,"))
        self.assertIn("if ((MISC_MODE & 3u) == 1u)", firmware)
        self.assertIn("if (dfu_selected_latched)", driver)

    def test_native_c_boot_driver_fault_injection(self):
        gcc = shutil.which("gcc")
        if gcc is None:
            self.skipTest("host gcc not installed")
        sector = ROOT / "build-ulx5m-gs/fwtn-jtag-201000-tailfix-4096.bin"
        if not sector.is_file():
            self.skipTest("archived sector unavailable")
        with tempfile.TemporaryDirectory() as tmp:
            exe = pathlib.Path(tmp) / "v47_boot_test"
            subprocess.run([gcc, "-std=c11", "-Wall", "-Wextra", "-Werror", "-O2",
                            "-Ifw", "-o", str(exe),
                            "fw/ulx5m_native_v41_image.c", "fw/ulx5m_spi_active_boot.c",
                            "tests/test-ulx5m-v47-spi-active-boot.c"],
                           cwd=ROOT, check=True)
            subprocess.run([str(exe), str(sector)], cwd=ROOT, check=True)

    def test_build_uses_bootaddr_not_stream(self):
        make = text("Makefile.ulx5m-spi-secondary")
        self.assertIn("SPI_SECONDARY_ADDR := 2101248", make)
        self.assertIn("$(GMPACK) --bootaddr $(SPI_SECONDARY_ADDR)", make)
        self.assertNotIn("--reconfig", make)
        self.assertNotIn("-f $(SPI_SECONDARY_BIT)", make)
        self.assertIn("ULX5M_SERV_SPI_ACTIVE_SECONDARY", make)

    def test_fw_profile_separate_from_golden(self):
        make = text("Makefile.ulx5m-spi-secondary")
        fwmake = text("fw/Makefile.ulx5m-flash-read")
        self.assertIn("normal-boot-dfu-hw-native", make)
        self.assertIn("NATIVE_SPI_SECONDARY=1", make)
        self.assertIn("DFU_HW_NATIVE_TEST_ONLY=1", make)
        self.assertIn("SRCS += ulx5m_native_v41_image.c ulx5m_spi_active_boot.c", fwmake)
        self.assertIn("$(error NATIVE_SPI_SECONDARY", fwmake)

    def test_pinned_bootaddr_trailer_and_mutation(self):
        import importlib.util
        parser = ROOT / "tests/inspect-ulx5m-v47-primary.py"
        spec = importlib.util.spec_from_file_location("inspect_v47", parser)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        candidate = ROOT / "build-ulx5m-gs/cfg-probe/top_ulx5m_gs_cfg_probe-bootaddr-201000-v43.bit"
        if not candidate.is_file():
            self.skipTest("archived v43 packed candidate unavailable")
        raw = candidate.read_bytes()
        size, digest = mod.inspect(candidate)
        self.assertEqual(size, len(raw))
        self.assertEqual(digest, hashlib.sha256(raw).hexdigest())
        with tempfile.TemporaryDirectory() as d:
            path = pathlib.Path(d) / "bad.bit"
            path.write_bytes(raw[:-1] + bytes([raw[-1] ^ 1]))
            with self.assertRaises(ValueError):
                mod.inspect(path)
            path.write_bytes(raw[:-19])
            with self.assertRaises(ValueError):
                mod.inspect(path)

    def test_non_authorization_diagnostic(self):
        firmware = text("fw/fw_ulx5m_flash_read.c")
        self.assertIn("REQUESTED is not hardware takeover", firmware)
        self.assertIn("A SPI-active primary may reset here", text("fw/ulx5m_spi_active_boot.c"))
        self.assertIn("NOT that a", text("fw/ulx5m_spi_active_boot.h"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
