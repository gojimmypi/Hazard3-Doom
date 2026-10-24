#!/usr/bin/env python3
"""Host-only exact-byte and fail-closed tests for isolated reset variant."""
import importlib.util
from pathlib import Path
import tempfile
import types
import unittest

SCRIPT = Path(__file__).with_name("prepare-ulx5m-cfg-probe-reset-reconfig-rom.py")
spec = importlib.util.spec_from_file_location("reset_preparer", SCRIPT)
prep = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prep)


class ResetReconfigPreparationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original = Path("build-ulx5m-gs/top_ulx5m_gs_normal_led.bit").read_bytes()
        cls.expected = prep.expected_variant(cls.original)

    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.image = self.root / "led.bit"
        self.image.write_bytes(self.original)
        self.impl = self.root / "led.txt"
        self.impl.write_text("dummy", encoding="ascii")
        self.rom = self.root / "led.hex"
        self.bit = self.root / "new.bit"

    def runner(self, variant=None, default=None, fail=False):
        def run(args, **unused):
            if fail:
                return types.SimpleNamespace(returncode=1, stderr="intentional", stdout="")
            bytes_out = (self.expected if variant is None else variant) if "--reset" in args else (self.original if default is None else default)
            Path(args[-1]).write_bytes(bytes_out)
            return types.SimpleNamespace(returncode=0, stderr="", stdout="")
        return run

    def test_expected_bytes_and_sha(self):
        self.assertEqual(len(self.expected), 3033)
        self.assertEqual(prep.sha256(self.expected), prep.VARIANT_SHA256)
        self.assertEqual(self.expected[:16], self.original[:16])
        self.assertEqual(self.expected[16:23], prep.RESET_COMMAND)
        self.assertEqual(self.expected[23:23+prep.STATUS_OFFSET-16], self.original[16:prep.STATUS_OFFSET])
        self.assertEqual(self.expected[prep.STATUS_OFFSET+7:prep.STATUS_OFFSET+21], prep.NEW_STATUS)

    def test_prepares_exact_output_idempotently(self):
        self.assertEqual(prep.prepare(self.image, self.impl, self.rom, self.bit,
                                      runner=self.runner()), prep.VARIANT_SHA256)
        self.assertEqual(self.bit.read_bytes(), self.expected)
        self.assertEqual(self.rom.read_text(encoding="ascii").splitlines(),
                         ["{:02x}".format(x) for x in self.expected])
        prep.prepare(self.image, self.impl, self.rom, self.bit, runner=self.runner())

    def test_refuse_corrupt_source(self):
        content = bytearray(self.original)
        content[128] ^= 1
        self.image.write_bytes(content)
        with self.assertRaises(ValueError):
            prep.prepare(self.image, self.impl, self.rom, self.bit, runner=self.runner())
        self.assertFalse(self.rom.exists())

    def test_refuse_wrong_default(self):
        with self.assertRaises(ValueError):
            prep.prepare(self.image, self.impl, self.rom, self.bit, runner=self.runner(default=b"bad"))
        self.assertFalse(self.bit.exists())

    def test_refuse_unexpected_reset_mutation(self):
        wrong = bytearray(self.expected)
        wrong[42] ^= 1
        with self.assertRaises(ValueError):
            prep.prepare(self.image, self.impl, self.rom, self.bit, runner=self.runner(variant=wrong))
        self.assertFalse(self.bit.exists())

    def test_refuse_gmpack_error(self):
        with self.assertRaises(ValueError):
            prep.prepare(self.image, self.impl, self.rom, self.bit, runner=self.runner(fail=True))
        self.assertFalse(self.rom.exists())

    def test_refuse_conflicting_rom(self):
        self.rom.write_text("original\n", encoding="ascii")
        with self.assertRaises(ValueError):
            prep.prepare(self.image, self.impl, self.rom, self.bit, runner=self.runner())
        self.assertEqual(self.rom.read_text(encoding="ascii"), "original\n")
        self.assertFalse(self.bit.exists())

    def test_refuse_same_output_path(self):
        with self.assertRaises(ValueError):
            prep.prepare(self.image, self.impl, self.rom, self.rom, runner=self.runner())
        self.assertFalse(self.rom.exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
