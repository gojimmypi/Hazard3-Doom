#!/usr/bin/env python3
"""Run the actual C native-slot validator using pinned independent v41 data.

No USB, JTAG, configuration-stream, reset, flash write or build output in repo.
"""
import argparse
import hashlib
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
APP_SHA = "68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd"
SECTOR_SHA = "28b1e5cbfa45a319600ec38c81207a36d9889c3179e8055f5a663c616ef97bee"
DEFAULT_APP = ROOT / "build-ulx5m-gs/top_ulx5m_gs_normal_led.bit"
DEFAULT_SECTOR = ROOT / "build-ulx5m-gs/fwtn-jtag-201000-tailfix-4096.bin"
APP = DEFAULT_APP
SECTOR = DEFAULT_SECTOR


def pinned(path, n, checksum):
    data = Path(path).read_bytes()
    if len(data) != n or hashlib.sha256(data).hexdigest() != checksum:
        raise ValueError("Pinned image mismatch: %s" % path)
    return data


def c_probe(sector, compiler="cc"):
    with tempfile.TemporaryDirectory(prefix="ulx5m-native-v41-") as tmp:
        exe = Path(tmp) / "native-v41-test"
        subprocess.run([compiler, "-std=c11", "-Wall", "-Wextra", "-Werror",
                        "-O2", "-I", str(ROOT / "fw"),
                        str(ROOT / "fw/ulx5m_native_v41_image.c"),
                        str(ROOT / "tests/test-ulx5m-native-v41-image.c"),
                        "-o", str(exe)], check=True)
        completed = subprocess.run([str(exe), str(sector)], check=True,
                                   capture_output=True, text=True)
        return completed.stdout


class NativeImageTests(unittest.TestCase):
    def test_reference_is_exact(self):
        self.assertEqual(len(pinned(APP, 3026, APP_SHA)), 3026)

    def test_independent_sector_is_exact(self):
        app = pinned(APP, 3026, APP_SHA)
        sector = pinned(SECTOR, 4096, SECTOR_SHA)
        self.assertEqual(sector, app + b"\xff" * 1070)

    def test_c_reader_and_fault_injections(self):
        pinned(SECTOR, 4096, SECTOR_SHA)
        output = c_probe(SECTOR)
        self.assertEqual(output.count("[PASS]"), 10)
        self.assertIn("[BLOCK]", output)
        print(output, end="")

    def test_mutation_rejected_before_c(self):
        data = bytearray(pinned(SECTOR, 4096, SECTOR_SHA))
        data[1000] ^= 1
        with tempfile.TemporaryDirectory() as tmp:
            f = Path(tmp) / "corrupt.bin"
            f.write_bytes(data)
            with self.assertRaisesRegex(ValueError, "Pinned image mismatch"):
                pinned(f, 4096, SECTOR_SHA)

    def test_truncated_sector_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            f = Path(tmp) / "short.bin"
            f.write_bytes(b"\xff" * 4095)
            with self.assertRaises(ValueError):
                pinned(f, 4096, SECTOR_SHA)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, default=DEFAULT_APP)
    parser.add_argument("--sector", type=Path, default=DEFAULT_SECTOR)
    args = parser.parse_args()
    APP, SECTOR = args.app, args.sector
    try:
        pinned(APP, 3026, APP_SHA)
        pinned(SECTOR, 4096, SECTOR_SHA)
    except (OSError, ValueError) as exc:
        print("[FAIL] %s" % exc, file=sys.stderr)
        sys.exit(2)
    unittest.main(argv=[__file__], verbosity=2)
