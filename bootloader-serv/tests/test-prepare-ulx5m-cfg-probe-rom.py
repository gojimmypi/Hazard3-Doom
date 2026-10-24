#!/usr/bin/env python3
"""Offline fail-closed ROM generation regressions (no FPGA tools)."""
import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest

SOURCE = Path(__file__).with_name("prepare-ulx5m-cfg-probe-rom.py")
spec = importlib.util.spec_from_file_location("cfg_probe_rom", SOURCE)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class ProbeROMTest(unittest.TestCase):
    def test_known_image_and_identical_existing_output(self):
        fixture = Path(__file__).resolve().parents[1] / "build-ulx5m-gs/top_ulx5m_gs_normal_led.bit"
        if not fixture.exists():
            self.skipTest("Physical fixture absent; the Makefile checks it during ROM preparation")
        with tempfile.TemporaryDirectory() as tmp:
            dest = Path(tmp) / "rom.hex"
            digest = mod.prepare(fixture, dest)
            self.assertEqual(digest, mod.KNOWN_SHA256)
            self.assertEqual(len(dest.read_text(encoding="ascii").splitlines()), 3026)
            self.assertEqual(mod.prepare(fixture, dest), mod.KNOWN_SHA256)
            dest.write_text("00\n", encoding="ascii")
            with self.assertRaisesRegex(ValueError, "will not overwrite"):
                mod.prepare(fixture, dest)

    def test_wrong_payload_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            fixture = Path(tmp) / "bad.bit"
            dest = Path(tmp) / "rom.hex"
            fixture.write_bytes(bytes.fromhex("d901ed96") + bytes(3022))
            with self.assertRaisesRegex(ValueError, "not the exact"):
                mod.prepare(fixture, dest)
            self.assertFalse(dest.exists())

    def test_sync_and_size_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            fixture = Path(tmp) / "bad.bit"
            dest = Path(tmp) / "rom.hex"
            fixture.write_bytes(b"HELLO")
            with self.assertRaisesRegex(ValueError, "not the exact"):
                mod.prepare(fixture, dest)
            self.assertFalse(dest.exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
