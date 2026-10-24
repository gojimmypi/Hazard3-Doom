#!/usr/bin/env python3
"""Offline regression tests for read-only native-sector JTAG-SPI alignment check."""

import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).with_name("check-ulx5m-fwtn-jtag-raw.py")
SPEC = importlib.util.spec_from_file_location("ulx5m_shift_check", SCRIPT)
MOD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MOD)


class Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = bytes.fromhex("d901ed96") + bytes(MOD.APP_LENGTH - 4)
        cls.sector = cls.app + b"\xff" * (MOD.SECTOR_LENGTH - len(cls.app))

    def test_clean_raw_dump(self):
        self.assertEqual(MOD.diagnose(self.sector, self.sector)[0], "clean")
        self.assertEqual(MOD.diagnose(self.sector + b"\xff", self.sector)[0], "clean")

    def test_complete_bit_shift(self):
        s = self.sector + b"\xff"
        shifted = bytes([s[0] >> 1] + [(s[i] >> 1) | ((s[i - 1] & 1) << 7) for i in range(1, len(s))])
        self.assertEqual(MOD.diagnose(shifted, self.sector)[0], "shifted")

    def test_real_shifted_full_read(self):
        s = self.sector + b"\xff"
        shifted = bytes([s[0] >> 1] + [(s[i] >> 1) | ((s[i - 1] & 1) << 7) for i in range(1, len(s))])
        self.assertEqual(MOD.diagnose(shifted[:4096], self.sector)[0], "shifted")

    def test_mismatch(self):
        bad = bytearray(self.sector)
        bad[12] ^= 0x80
        self.assertEqual(MOD.diagnose(bytes(bad), self.sector)[0], "mismatch")

    def test_invalid_length(self):
        self.assertEqual(MOD.diagnose(b"", self.sector)[0], "invalid")
        self.assertEqual(MOD.diagnose(b"\xff" * 4098, self.sector)[0], "invalid")

    def test_read_command_is_read_only(self):
        cmd = MOD.inverted_read_command("loader", "output.bin", 1000)
        self.assertIn("--invert-read-edge", cmd)
        self.assertIn("--dump-flash", cmd)
        self.assertEqual(cmd[cmd.index("--offset") + 1], str(0x201000))
        self.assertEqual(cmd[cmd.index("--file-size") + 1], "4097")
        self.assertFalse(any(x in cmd for x in ("-m", "-f", "--write-flash", "--bulk-erase")))

    def test_standard_read_command_is_read_only(self):
        cmd = MOD.read_command("loader", "output.bin", 1000)
        self.assertNotIn("--invert-read-edge", cmd)
        self.assertIn("--dump-flash", cmd)
        self.assertEqual(cmd[cmd.index("--file-size") + 1], "4097")
        self.assertFalse(any(x in cmd for x in ("-m", "-f", "--write-flash", "--bulk-erase")))

    def test_existent_output_refused(self):
        with tempfile.TemporaryDirectory() as d:
            loader, out = Path(d) / "openFPGALoader.exe", Path(d) / "out.bin"
            loader.write_bytes(b"executable")
            out.write_bytes(b"existing")
            with patch.object(MOD.subprocess, "run") as run:
                with self.assertRaisesRegex(ValueError, "output exists"):
                    MOD.run_inverted_probe(loader, out, 1000)
                run.assert_not_called()

    def test_standard_output_exists_refused(self):
        with tempfile.TemporaryDirectory() as d:
            loader, out = Path(d) / "candidate.exe", Path(d) / "existing.bin"
            loader.write_bytes(b"executable")
            out.write_bytes(b"existing")
            with patch.object(MOD.subprocess, "run") as run:
                with self.assertRaisesRegex(ValueError, "output exists"):
                    MOD.run_read_probe(loader, out, 1000)
                run.assert_not_called()

    def test_bad_frequency(self):
        with self.assertRaises(ValueError):
            MOD.inverted_read_command("loader", "out.bin", 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
