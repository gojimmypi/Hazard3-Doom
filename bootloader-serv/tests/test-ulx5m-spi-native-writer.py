#!/usr/bin/env python3
"""Compile/run the native-app-slot writer in denied and HOST ONLY modes."""
import hashlib
import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
BIT = ROOT / "build-ulx5m-gs/top_ulx5m_gs_normal_led.bit"
SHA256 = "68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd"
FILES = [ROOT / "fw/ulx5m_flash_program.c",
         ROOT / "fw/ulx5m_spi_native_writer.c",
         ROOT / "tests/test-ulx5m-spi-native-writer.c"]


class NativeWriterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not BIT.is_file():
            raise FileNotFoundError("Missing pinned walking LED image: " + str(BIT))
        data = BIT.read_bytes()
        if len(data) != 3026 or hashlib.sha256(data).hexdigest() != SHA256:
            raise ValueError("Known JTAG-working walking LED image mismatch")

    def compile_and_run(self, host):
        with tempfile.TemporaryDirectory(prefix="ulx5m-native-writer-") as d:
            exe = pathlib.Path(d) / "test"
            flags = (["-DULX5M_SPI_NATIVE_WRITER_HOST_TEST",
                      "-DULX5M_FLASH_PROGRAM_EMULATOR_TEST"] if host else [])
            cmd = ["cc", "-std=c11", "-O2", "-Wall", "-Wextra", "-Werror",
                   "-I", str(ROOT / "fw"), *flags,
                   *(str(x) for x in FILES), "-o", str(exe)]
            subprocess.run(cmd, check=True)
            result = subprocess.run([str(exe), str(BIT)], check=True,
                                    capture_output=True, text=True)
            return result.stdout

    def test_production_default_denies(self):
        output = self.compile_and_run(False)
        self.assertIn("Production default denies programming", output)
        self.assertIn("[BLOCK]", output)
        print(output, end="")

    def test_host_only_end_to_end(self):
        output = self.compile_and_run(True)
        self.assertIn("Exact 3026-byte GateMate image at 0x201000", output)
        self.assertIn("Exact native-slot upper boundary", output)
        self.assertIn("[BLOCK]", output)
        print(output, end="")

    def test_riscv_cannot_enable_host_mode(self):
        text = (ROOT / "fw/ulx5m_spi_native_writer.c").read_text()
        self.assertIn("defined(__riscv)", text)
        self.assertIn("#error \"Host-only SPI native writer", text)
        self.assertIn("ULX5M_SPI_NATIVE_ENTRY +", text)
        result = subprocess.run(
            ["cc", "-std=c11", "-D__riscv",
             "-DULX5M_SPI_NATIVE_WRITER_HOST_TEST",
             "-DULX5M_FLASH_PROGRAM_EMULATOR_TEST",
             "-I", str(ROOT / "fw"), "-fsyntax-only",
             str(ROOT / "fw/ulx5m_spi_native_writer.c")],
            capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Host-only SPI native writer", result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
