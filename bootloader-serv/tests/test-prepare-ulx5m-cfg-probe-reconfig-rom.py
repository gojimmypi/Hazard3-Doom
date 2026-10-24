#!/usr/bin/env python3
"""Fail-closed host tests of v30 reconfiguration-destination preparation."""
import importlib.util
from pathlib import Path
import tempfile
import types
import unittest

SCRIPT = Path(__file__).with_name("prepare-ulx5m-cfg-probe-reconfig-rom.py")
spec = importlib.util.spec_from_file_location("reconfig_prep", SCRIPT)
prep = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prep)
LED = Path("build-ulx5m-gs/top_ulx5m_gs_normal_led.bit")


class ROMPreparationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original = LED.read_bytes()
        prep.validate_original(cls.original)
        cls.variant = (cls.original[:prep.OFFSET] + prep.AFTER
                       + cls.original[prep.OFFSET + len(prep.BEFORE):])

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.original_path = self.root / "original.bit"
        self.original_path.write_bytes(self.original)
        self.impl = self.root / "original.txt"
        self.impl.write_text("test", encoding="ascii")
        self.rom = self.root / "probe.hex"
        self.bit = self.root / "target.bit"

    def fake_runner(self, corrupt=False, fail=False):
        def runner(args, **kwargs):
            output = Path(args[-1])
            if fail:
                return types.SimpleNamespace(returncode=1, stderr="intentional error", stdout="")
            data = self.variant if "--reconfig" in args else self.original
            if corrupt and "--reconfig" in args:
                data = bytearray(data)
                data[32] ^= 1
            output.write_bytes(data)
            return types.SimpleNamespace(returncode=0, stderr="", stdout="")
        return runner

    def test_exact_pinned_delta(self):
        self.assertEqual(prep.sha256(self.variant), prep.RECONFIG_SHA256)
        prep.validate_reconfig(self.original, self.variant)
        self.assertEqual(self.variant[:prep.OFFSET], self.original[:prep.OFFSET])
        self.assertEqual(self.variant[prep.OFFSET + len(prep.AFTER):],
                         self.original[prep.OFFSET + len(prep.BEFORE):])

    def test_publishes_exact_byte_rom_and_binary(self):
        self.assertEqual(prep.prepare(self.original_path, self.impl, self.rom, self.bit,
                                      runner=self.fake_runner()), prep.RECONFIG_SHA256)
        self.assertEqual(self.bit.read_bytes(), self.variant)
        self.assertEqual(self.rom.read_text(encoding="ascii").splitlines(),
                         ["{:02x}".format(b) for b in self.variant])
        # Repeated runs must remain idempotent and not rewrite output.
        prep.prepare(self.original_path, self.impl, self.rom, self.bit,
                     runner=self.fake_runner())

    def test_corrupt_original_rejected_without_outputs(self):
        corrupted = bytearray(self.original)
        corrupted[30] ^= 1
        self.original_path.write_bytes(corrupted)
        with self.assertRaises(ValueError):
            prep.prepare(self.original_path, self.impl, self.rom, self.bit,
                         runner=self.fake_runner())
        self.assertFalse(self.rom.exists())
        self.assertFalse(self.bit.exists())

    def test_bad_reconfig_delta_rejected_without_outputs(self):
        with self.assertRaises(ValueError):
            prep.prepare(self.original_path, self.impl, self.rom, self.bit,
                         runner=self.fake_runner(corrupt=True))
        self.assertFalse(self.rom.exists())
        self.assertFalse(self.bit.exists())

    def test_gmpack_error_rejected(self):
        with self.assertRaises(ValueError):
            prep.prepare(self.original_path, self.impl, self.rom, self.bit,
                         runner=self.fake_runner(fail=True))
        self.assertFalse(self.rom.exists())

    def test_conflicting_existing_rom_preserved(self):
        self.rom.write_text("do-not-overwrite\n", encoding="ascii")
        with self.assertRaises(ValueError):
            prep.prepare(self.original_path, self.impl, self.rom, self.bit,
                         runner=self.fake_runner())
        self.assertEqual(self.rom.read_text(encoding="ascii"), "do-not-overwrite\n")
        self.assertFalse(self.bit.exists())

    def test_default_gmpack_mismatch_rejected(self):
        def runner(args, **kwargs):
            Path(args[-1]).write_bytes(b"wrong-default")
            return types.SimpleNamespace(returncode=0, stderr="", stdout="")
        with self.assertRaises(ValueError):
            prep.prepare(self.original_path, self.impl, self.rom, self.bit, runner=runner)
        self.assertFalse(self.rom.exists())
        self.assertFalse(self.bit.exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
