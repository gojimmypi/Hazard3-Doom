#!/usr/bin/env python3
"""Verify emulator-MMIO authorization cannot compile into RISC-V firmware."""
import pathlib
import subprocess
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "fw" / "ulx5m_at25ql321_hw.c"
DRIVER = ROOT / "fw" / "ulx5m_at25ql321.c"


def compiles(source, defines=()):
    proc = subprocess.run(
        ["gcc", "-std=c11", "-Wall", "-Wextra", "-Werror", "-fsyntax-only",
         *["-D" + define for define in defines], "-Ifw", str(source)],
        cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    return proc.returncode == 0


class Guards(unittest.TestCase):
    def test_production_driver_and_adapter_compile(self):
        self.assertTrue(compiles(SRC))
        self.assertTrue(compiles(DRIVER))

    def test_mmio_emulator_is_host_only(self):
        args = ("ULX5M_AT25QL321_EMULATOR_TEST=1",
                "ULX5M_AT25QL321_MMIO_HOST_TEST=1")
        self.assertTrue(compiles(SRC, args))
        self.assertFalse(compiles(SRC, args + ("__riscv=1",)))
        self.assertFalse(compiles(DRIVER, args + ("__riscv=1",)))

    def test_both_defines_required(self):
        self.assertFalse(compiles(SRC, ("ULX5M_AT25QL321_EMULATOR_TEST=1",)))
        self.assertFalse(compiles(SRC, ("ULX5M_AT25QL321_MMIO_HOST_TEST=1",)))


if __name__ == "__main__":
    unittest.main(verbosity=2)
