#!/usr/bin/env python3
"""Offline regressions for inspect-ulx5m-cfg-variants.py; no hardware access."""

import contextlib
import hashlib
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
from unittest import mock

SRC = Path(__file__).with_name("inspect-ulx5m-cfg-variants.py")
spec = importlib.util.spec_from_file_location("ulx5m_cfg_variants", SRC)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


def sha(data):
    return hashlib.sha256(data).hexdigest()


class GateMateVariantsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.golden = mod.GATEMATE_PREFIX + bytes(range(64))
        self.text = b".device CCGM1A1\n.config 0\n"
        self.golden_path = self._put("seed147.bit", self.golden)
        self.text_path = self._put("seed147.txt", self.text)
        self.variant = bytearray(self.golden)
        self.variant[10] ^= 1
        self.variant[19] ^= 2
        self.variant_path = self._put("reconfig.bit", bytes(self.variant))
        self.hash_patch = mock.patch.multiple(
            mod, GOLDEN_SHA256=sha(self.golden), IMPLEMENTATION_SHA256=sha(self.text))
        self.hash_patch.start()
        self.addCleanup(self.hash_patch.stop)

    def _put(self, name, contents):
        path = self.root / name
        path.write_bytes(contents)
        return str(path)

    def _run(self, extra=None):
        base = ["--golden-bit", self.golden_path, "--implementation", self.text_path]
        stdout, stderr = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            code = mod.main(base + (extra or []))
        return code, stdout.getvalue(), stderr.getvalue()

    def test_golden_and_variant(self):
        code, output, error = self._run(["--variant", "reconfig=" + self.variant_path])
        self.assertEqual(code, 0, error)
        self.assertIn('"different_bytes_including_size_delta": 2', output)
        self.assertIn('"first_different_offset": 10', output)
        self.assertIn('"last_different_offset": 19', output)
        self.assertIn("NO RECONFIGURATION AUTHORIZED", output)

    def test_golden_only(self):
        code, output, _ = self._run()
        self.assertEqual(code, 0)
        self.assertIn("Golden inputs checked only", output)

    def test_wrong_golden_rejected(self):
        bad = bytearray(self.golden)
        bad[-1] ^= 1
        path = self._put("bad.bit", bad)
        self.assertEqual(self._run(["--golden-bit", path])[0], 1)

    def test_wrong_implementation_rejected(self):
        other = self._put("other.txt", self.text + b"bad")
        self.assertEqual(self._run(["--implementation", other])[0], 1)

    def test_same_variant_rejected(self):
        self.assertEqual(self._run(["--variant", "same=" + self.golden_path])[0], 1)

    def test_wrong_preamble_rejected(self):
        data = bytearray(self.variant)
        data[0] ^= 1
        path = self._put("no-sync.bit", data)
        self.assertEqual(self._run(["--variant", "bad=" + path])[0], 1)

    def test_duplicate_name_rejected(self):
        opts = ["--variant", "one=" + self.variant_path, "--variant", "one=" + self.variant_path]
        self.assertEqual(self._run(opts)[0], 1)

    def test_malformed_name_rejected(self):
        with self.assertRaises(Exception):
            mod.parse_variant("invalid")
        with self.assertRaises(Exception):
            mod.parse_variant("../unsafe=x")

    def test_missing_variant_rejected(self):
        self.assertEqual(self._run(["--variant", "absent=" + str(self.root / "none.bit")])[0], 1)

    def test_variants_length_change(self):
        appended = self._put("appended.bit", self.golden + b"TAIL")
        code, output, _ = self._run(["--variant", "extended=" + appended])
        self.assertEqual(code, 0)
        self.assertIn('"different_bytes_including_size_delta": 4', output)
        self.assertIn('"first_different_offset": 68', output)

    def test_json_create_only(self):
        report = str(self.root / "result.json")
        args = ["--variant", "reconfig=" + self.variant_path, "--json-out", report]
        self.assertEqual(self._run(args)[0], 0)
        original = Path(report).read_bytes()
        self.assertEqual(self._run(args)[0], 1)
        self.assertEqual(Path(report).read_bytes(), original)

    def test_invalid_file_does_not_create_report(self):
        out = str(self.root / "should-not-exist.json")
        code, _, _ = self._run(["--variant", "same=" + self.golden_path, "--json-out", out])
        self.assertEqual(code, 1)
        self.assertFalse(Path(out).exists())

    def test_factory_backup_checked_without_mutation(self):
        flash = bytearray(b"\xff" * mod.FLASH_SIZE)
        flash[:4] = mod.GATEMATE_PREFIX
        flash[mod.CANDIDATE_OFFSET:mod.CANDIDATE_OFFSET + 4] = b"NONE"
        flash_path = self._put("factory.bin", flash)
        original = sha(flash)
        with mock.patch.object(mod, "FACTORY_SHA256", original):
            code, report, err = self._run(["--factory-flash", flash_path])
            self.assertEqual(code, 0, err)
            self.assertIn('"candidate_u5im_magic_present": false', report)
            self.assertIn('"first_fully_erased_sector": 4096', report)
        self.assertEqual(sha(Path(flash_path).read_bytes()), original)

    def test_factory_bad_hash_rejected(self):
        flash_path = self._put("wrong-flash.bin", b"\xff" * mod.FLASH_SIZE)
        self.assertEqual(self._run(["--factory-flash", flash_path])[0], 1)

    def test_factory_wrong_length_rejected(self):
        flash_path = self._put("short-flash.bin", b"\xff" * 512)
        self.assertEqual(self._run(["--factory-flash", flash_path])[0], 1)

    def test_factory_u5im_magic_only_is_not_authorization(self):
        flash = bytearray(b"\xff" * mod.FLASH_SIZE)
        flash[0:4] = mod.GATEMATE_PREFIX
        flash[mod.CANDIDATE_OFFSET:mod.CANDIDATE_OFFSET + 4] = b"U5IM"
        path = self._put("magic-only.bin", flash)
        with mock.patch.object(mod, "FACTORY_SHA256", sha(flash)):
            code, output, err = self._run(["--factory-flash", path])
        self.assertEqual(code, 0, err)
        self.assertIn('"candidate_u5im_magic_present": true', output)
        self.assertIn("no writable region", output)

    def test_oversized_variant_rejected(self):
        bad = self._put("oversize.bit", b"z" * (mod.FLASH_SIZE + 1))
        self.assertEqual(self._run(["--variant", "too_big=" + bad])[0], 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
