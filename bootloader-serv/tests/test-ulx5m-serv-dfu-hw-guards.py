#!/usr/bin/env python3
"""Compile-time guards for the separately armed physical flash test profile."""
import subprocess
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
FILES = ["fw/ulx5m_at25ql321.c", "fw/ulx5m_flash_program.c",
         "fw/ulx5m_dfu_stream.c", "fw/ulx5m_flash_hw_test.c"]

class GuardTests(unittest.TestCase):
    def check_compile(self, defines, should_pass):
        cmd = ["gcc", "-std=c11", "-Wall", "-Wextra", "-Werror", "-Wno-main",
               "-ffreestanding", "-Ifw", "-fsyntax-only"] + defines + FILES
        result = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(result.returncode == 0, should_pass,
                         "Command: {}\n{}".format(cmd, result.stderr))

    def test_production_hw_module_denied(self):
        self.check_compile([], False)

    def test_firmware_hw_profile_compiles(self):
        self.check_compile(["-D__riscv=1", "-DULX5M_FLASH_HW_TEST=1",
                            "-DULX5M_DFU_HW_TEST_ONLY=1"], True)

    def test_missing_experiment_flag_denied(self):
        self.check_compile(["-D__riscv=1", "-DULX5M_FLASH_HW_TEST=1"], False)

    def test_host_mocks_forbidden_on_riscv(self):
        self.check_compile(["-D__riscv=1", "-DULX5M_FLASH_HW_TEST=1",
                            "-DULX5M_DFU_HW_TEST_ONLY=1",
                            "-DULX5M_FLASH_HW_HOST_TEST=1"], False)

    def test_emulator_flags_forbidden_on_riscv(self):
        self.check_compile(["-D__riscv=1", "-DULX5M_FLASH_HW_TEST=1",
                            "-DULX5M_DFU_HW_TEST_ONLY=1",
                            "-DULX5M_AT25QL321_EMULATOR_TEST=1",
                            "-DULX5M_FLASH_PROGRAM_EMULATOR_TEST=1"], False)

if __name__ == "__main__":
    unittest.main(verbosity=2)
