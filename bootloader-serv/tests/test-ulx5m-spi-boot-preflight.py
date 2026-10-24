#!/usr/bin/env python3
"""Compile and run real-C native SPI boot preflight against pinned LED image.

Reads an existing .bit. Compiler and test executable run in a temp directory.
Never invokes gmpack, FPGA programming, a configuration transport, or flash IO.
"""
import argparse
import hashlib
from pathlib import Path
import subprocess
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
EXPECTED_SHA = "68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd"
DEFAULT_BIT = ROOT / "build-ulx5m-gs/top_ulx5m_gs_normal_led.bit"


def validated_image(path):
    raw = Path(path).read_bytes()
    if len(raw) != 3026 or hashlib.sha256(raw).hexdigest() != EXPECTED_SHA:
        raise ValueError("unexpected walking-LED image; refusing C preflight")
    return raw


def compile_and_run(image, compiler="cc"):
    validated_image(image)
    with tempfile.TemporaryDirectory(prefix="ulx5m-v37-host-only-") as tmp:
        executable = Path(tmp) / "preflight"
        sources = [
            HERE / "test-ulx5m-spi-boot-preflight.c",
            ROOT / "fw/ulx5m_spi_boot_preflight.c",
            ROOT / "fw/ulx5m_normal_image.c",
            ROOT / "fw/ulx5m_flash_layout.c",
        ]
        command = [compiler, "-std=c11", "-Wall", "-Wextra", "-Werror", "-O2",
                   "-I", str(ROOT / "fw"), *map(str, sources), "-o", str(executable)]
        subprocess.run(command, check=True)
        return subprocess.run([str(executable), str(image)], check=True,
                              capture_output=True, text=True).stdout


class PreflightTests(unittest.TestCase):
    def test_known_image(self):
        self.assertEqual(len(validated_image(DEFAULT_BIT)), 3026)

    def test_changed_image_is_rejected(self):
        raw = bytearray(validated_image(DEFAULT_BIT))
        raw[-1] ^= 1
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "mutated.bit"
            path.write_bytes(raw)
            with self.assertRaises(ValueError):
                validated_image(path)

    def test_truncated_image_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "short.bit"
            path.write_bytes(b"\xd9\x01\xed\x96")
            with self.assertRaises(ValueError):
                validated_image(path)

    def test_c_parser_and_preflight(self):
        output = compile_and_run(DEFAULT_BIT)
        self.assertEqual(output.count("[PASS]"), 10)
        self.assertIn("[BLOCK] No jump", output)
        print(output, end="")


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--bit", type=Path, default=DEFAULT_BIT)
    args = ap.parse_args()
    # unittest cannot accept unrelated CLI options, so use the validated path
    # through a temporary override of the test module default.
    DEFAULT_BIT = args.bit
    unittest.main(argv=[__file__], verbosity=2)
