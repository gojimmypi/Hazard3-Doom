#!/usr/bin/env python3
"""Offline regression: gmpack trailer analysis; no gmpack or hardware use."""

import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("analyze-ulx5m-gmpack-trailers.py")
ROOT = Path(__file__).resolve().parents[2]
BASE = (ROOT / "bootloader-serv/build-ulx5m-gs/"
        "top_ulx5m_gs_flash_read-serv-dfu-hw-quad-btn2")


def sha(data):
    return hashlib.sha256(data).hexdigest()


class TrailerAnalysisTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="ulx5m-trailer-test-")
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name)
        self.output = self.path / "offline"
        self.output.mkdir()
        self.golden_path = self.path / "golden.bit"
        self.impl_path = self.path / "impl.txt"
        original = Path(str(BASE) + ".bit")
        impl = Path(str(BASE) + ".txt")
        self.assertTrue(original.is_file(), "missing frozen golden .bit")
        self.assertTrue(impl.is_file(), "missing frozen nextpnr .txt")
        self.golden = original.read_bytes()
        self.golden_path.write_bytes(self.golden)
        self.impl_path.write_bytes(impl.read_bytes())
        # Simulate a one-byte option effect plus an independent 19-byte addition.
        needle = len(self.golden) - 23
        reconfig = bytearray(self.golden)
        reconfig[needle] ^= 1
        reconfig[needle + 13] ^= 2
        reconfig = bytes(reconfig)
        injection = b"Synthetic-19-byte!"  # 18 bytes, then a marker byte.
        self.assertEqual(len(injection), 18)
        injection += b"#"
        bootaddr = self.golden[:needle] + injection + self.golden[needle:]
        combined = reconfig[:needle] + injection + reconfig[needle:]
        self.images = {"default": self.golden, "reconfig": reconfig,
                       "bootaddr_probe": bootaddr,
                       "reconfig_bootaddr_probe": combined}
        for name, image in self.images.items():
            (self.output / (name + ".bit")).write_bytes(image)
        report = {
            "golden": {"size": len(self.golden), "sha256": sha(self.golden)},
            "implementation": {"sha256": sha(self.impl_path.read_bytes())},
            "variants": {name: {"size": len(image), "sha256": sha(image)}
                         for name, image in self.images.items() if name != "default"},
        }
        (self.output / "variants.json").write_text(json.dumps(report), encoding="ascii")

    def call(self, *more):
        return subprocess.run([sys.executable, str(SCRIPT),
                               "--offline-dir", str(self.output),
                               "--golden-bit", str(self.golden_path),
                               "--implementation", str(self.impl_path), *more],
                              capture_output=True, text=True, check=False)

    def modify_report(self, fn):
        path = self.output / "variants.json"
        obj = json.loads(path.read_text(encoding="utf-8"))
        fn(obj)
        path.write_text(json.dumps(obj), encoding="utf-8")

    def test_valid_full_comparison(self):
        proc = self.call()
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("[PASS] Seed-147", proc.stdout)
        self.assertIn("default_to_reconfig", proc.stdout)
        self.assertIn("bootaddr_to_combined", proc.stdout)
        self.assertIn("0x6547c", proc.stdout)
        self.assertIn("[HEX]", proc.stdout)
        self.assertIn("NEVER program", proc.stdout)
        self.assertFalse((self.output / "trailer-analysis.json").exists())

    def test_json_create_only(self):
        target = self.path / "report.json"
        self.assertEqual(self.call("--json-out", str(target)).returncode, 0)
        obj = json.loads(target.read_text(encoding="utf-8"))
        self.assertEqual(len(obj["images"]), 4)
        self.assertEqual(obj["comparisons"]["default_to_reconfig"]["same_prefix_bytes"],
                         len(self.golden) - 23)
        original = target.read_bytes()
        self.assertNotEqual(self.call("--json-out", str(target)).returncode, 0)
        self.assertEqual(target.read_bytes(), original)

    def test_golden_corruption_rejected(self):
        self.golden_path.write_bytes(self.golden + b"z")
        self.assertIn("golden", self.call().stderr)
        self.assertNotEqual(self.call().returncode, 0)

    def test_implementation_hash_rejected(self):
        self.impl_path.write_bytes(b"wrong")
        proc = self.call()
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("nextpnr", proc.stderr)

    def test_default_mismatch_rejected(self):
        mutated = bytearray(self.golden)
        mutated[100] ^= 1
        (self.output / "default.bit").write_bytes(mutated)
        self.assertIn("default.bit differs", self.call().stderr)

    def test_variant_checksum_mismatch_rejected(self):
        mutated = bytearray(self.images["reconfig"])
        mutated[-1] ^= 1
        (self.output / "reconfig.bit").write_bytes(mutated)
        self.assertIn("size/SHA-256 mismatch", self.call().stderr)

    def test_report_reference_mismatch_rejected(self):
        self.modify_report(lambda obj: obj["golden"].update(sha256="bad"))
        self.assertIn("identities mismatch", self.call().stderr)

    def test_wrong_size_and_consistent_metadata_rejected(self):
        bad = self.images["bootaddr_probe"] + b"!"
        (self.output / "bootaddr_probe.bit").write_bytes(bad)
        self.modify_report(lambda obj: obj["variants"]["bootaddr_probe"].update(
            size=len(bad), sha256=sha(bad)))
        self.assertIn("unexpected variant size", self.call().stderr)

    def test_early_delta_with_consistent_metadata_rejected(self):
        bad = bytearray(self.images["bootaddr_probe"])
        bad[100] ^= 1
        bad = bytes(bad)
        (self.output / "bootaddr_probe.bit").write_bytes(bad)
        self.modify_report(lambda obj: obj["variants"]["bootaddr_probe"].update(
            sha256=sha(bad)))
        self.assertIn("outside the last 256", self.call().stderr)

    def test_unlisted_variant_rejected(self):
        self.modify_report(lambda obj: obj["variants"].update(unlisted={}))
        self.assertIn("exactly the three", self.call().stderr)

    def test_identical_variant_rejected(self):
        (self.output / "reconfig.bit").write_bytes(self.golden)
        self.modify_report(lambda obj: obj["variants"]["reconfig"].update(
            sha256=sha(self.golden)))
        self.assertIn("has no change", self.call().stderr)

    def test_missing_files_rejected(self):
        (self.output / "bootaddr_probe.bit").unlink()
        self.assertIn("missing", self.call().stderr)

    def test_invalid_json_rejected(self):
        (self.output / "variants.json").write_text("not json", encoding="ascii")
        self.assertNotEqual(self.call().returncode, 0)

    def test_no_report_created_on_failure(self):
        destination = self.path / "report.json"
        (self.output / "default.bit").unlink()
        self.assertNotEqual(self.call("--json-out", str(destination)).returncode, 0)
        self.assertFalse(destination.exists())

    def test_same_comparison_means_no_incremental_effect(self):
        # Combined effect matching bootaddr alone is a finding, not a rejection.
        same = self.images["bootaddr_probe"]
        (self.output / "reconfig_bootaddr_probe.bit").write_bytes(same)
        self.modify_report(lambda obj: obj["variants"]["reconfig_bootaddr_probe"].update(
            sha256=sha(same)))
        self.assertIn("no additional measured effect", self.call().stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
