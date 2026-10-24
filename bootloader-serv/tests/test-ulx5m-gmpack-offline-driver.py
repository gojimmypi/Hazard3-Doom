#!/usr/bin/env python3
"""Offline regression for scripts/qualify-ulx5m-gmpack-handoff.sh.

Uses a fake gmpack and the real seed-147 reference files. No hardware tools run.
"""

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE_BASE = (ROOT / "bootloader-serv/build-ulx5m-gs/"
               "top_ulx5m_gs_flash_read-serv-dfu-hw-quad-btn2")
SCRIPT = ROOT / "scripts/qualify-ulx5m-gmpack-handoff.sh"
INSPECTOR = ROOT / "bootloader-serv/tests/inspect-ulx5m-cfg-variants.py"

FAKE_PACKER = r'''#!/usr/bin/env python3
import os
from pathlib import Path
import sys
args = sys.argv[1:]
with open(os.environ['MOCK_CALL_LOG'], 'a', encoding='ascii') as log:
    log.write(' '.join(args) + '\n')
if '--help' in args:
    print('Mock gmpack: --reconfig --bootaddr')
    sys.exit(0)
if os.environ.get('MOCK_FAIL_VARIANT') == '1' and '--reconfig' in args:
    sys.exit(2)
source = Path(os.environ['MOCK_GOLDEN']).read_bytes()
if '--reconfig' in args and os.environ.get('MOCK_IDENTICAL') != '1':
    source = source[:100] + bytes([source[100] ^ 1]) + source[101:]
if '--bootaddr' in args and os.environ.get('MOCK_IDENTICAL') != '1':
    source = source[:200] + bytes([source[200] ^ 2]) + source[201:]
if not ('--reconfig' in args or '--bootaddr' in args) and os.environ.get('MOCK_BAD_DEFAULT') == '1':
    source = source[:300] + bytes([source[300] ^ 4]) + source[301:]
Path(args[-1]).write_bytes(source)
'''


class OfflinePackDriverTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="ulx5m-pack-test-")
        self.addCleanup(self.tmp.cleanup)
        base = Path(self.tmp.name)
        self.repo = base / "repo"
        (self.repo / "scripts").mkdir(parents=True)
        (self.repo / "bootloader-serv/tests").mkdir(parents=True)
        (self.repo / "bootloader-serv/build-ulx5m-gs").mkdir(parents=True)
        self.mock_bin = base / "mock-bin"
        self.mock_bin.mkdir()
        self.mock_log = base / "mock.log"
        self.mock_log.touch()

        for source, destination in (
            (SCRIPT, self.repo / "scripts" / SCRIPT.name),
            (INSPECTOR, self.repo / "bootloader-serv/tests" / INSPECTOR.name),
            (Path(str(SOURCE_BASE) + ".bit"),
             self.repo / "bootloader-serv/build-ulx5m-gs" / (SOURCE_BASE.name + ".bit")),
            (Path(str(SOURCE_BASE) + ".txt"),
             self.repo / "bootloader-serv/build-ulx5m-gs" / (SOURCE_BASE.name + ".txt")),
        ):
            self.assertTrue(source.is_file(), "required reference missing: %s" % source)
            shutil.copyfile(source, destination)
        (self.repo / "scripts" / SCRIPT.name).chmod(0o755)
        self.golden = self.repo / "bootloader-serv/build-ulx5m-gs" / (SOURCE_BASE.name + ".bit")
        mock = self.mock_bin / "gmpack"
        mock.write_text(FAKE_PACKER, encoding="ascii")
        mock.chmod(0o755)
        self.env = dict(os.environ)
        self.env.update({
            "PATH": str(self.mock_bin) + os.pathsep + os.environ["PATH"],
            "MOCK_GOLDEN": str(self.golden),
            "MOCK_CALL_LOG": str(self.mock_log),
        })

    def run_driver(self, *args, **env_updates):
        env = dict(self.env)
        env.update(env_updates)
        return subprocess.run([str(self.repo / "scripts" / SCRIPT.name), *args],
                              text=True, capture_output=True, env=env, check=False)

    def calls(self):
        return self.mock_log.read_text(encoding="ascii").splitlines()

    def test_all_variant_packaging_and_comparison(self):
        proc = self.run_driver()
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn("[PASS] Default gmpack output equals", proc.stdout)
        self.assertIn("[NOTE] NEVER load/program", proc.stdout)
        self.assertEqual(len(self.calls()), 5)  # help, default, 3 variants
        match = re.search(r"Offline output directory: (.+)", proc.stdout)
        self.assertIsNotNone(match)
        out = Path(match.group(1))
        self.addCleanup(lambda: shutil.rmtree(out, ignore_errors=True))
        self.assertTrue(str(out).startswith("/tmp/ulx5m-gmpack-offline."))
        self.assertEqual((out / "default.bit").read_bytes(), self.golden.read_bytes())
        report = json.loads((out / "variants.json").read_text(encoding="utf-8"))
        self.assertEqual(set(report["variants"]), {
            "reconfig", "bootaddr_probe", "reconfig_bootaddr_probe"})
        for item in report["variants"].values():
            self.assertFalse(item["same_as_golden"])
        self.assertTrue((out / "SHA256SUMS").is_file())

    def test_hash_mismatch_stops_before_any_gmpack_call(self):
        with self.golden.open("r+b") as image:
            image.seek(0)
            image.write(b"XXXX")
        proc = self.run_driver()
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("SHA-256 mismatch", proc.stderr)
        self.assertEqual(self.calls(), [])

    def test_implementation_hash_mismatch_stops_before_packing(self):
        impl = self.repo / "bootloader-serv/build-ulx5m-gs" / (SOURCE_BASE.name + ".txt")
        with impl.open("r+b") as content:
            content.seek(0)
            content.write(b"broken")
        proc = self.run_driver()
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("SHA-256 mismatch", proc.stderr)
        self.assertEqual(self.calls(), [])

    def test_default_pack_mismatch_stops_before_variants(self):
        proc = self.run_driver(MOCK_BAD_DEFAULT="1")
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("Default pack is not byte-identical", proc.stderr)
        self.assertEqual(len(self.calls()), 2)  # help, default only

    def test_identical_variants_fail_closed(self):
        proc = self.run_driver(MOCK_IDENTICAL="1")
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("identical to golden", proc.stderr)
        self.assertEqual(len(self.calls()), 5)

    def test_variant_generation_error_stops(self):
        proc = self.run_driver(MOCK_FAIL_VARIANT="1")
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("gmpack reconfig failed", proc.stderr)
        self.assertEqual(len(self.calls()), 3)

    def test_help_is_nonmutating(self):
        proc = self.run_driver("--help")
        self.assertEqual(proc.returncode, 0)
        self.assertIn("Offline only", proc.stdout)
        self.assertEqual(self.calls(), [])

    def test_arguments_are_rejected_without_execution(self):
        proc = self.run_driver("--target=flash")
        self.assertEqual(proc.returncode, 2)
        self.assertIn("Usage:", proc.stderr)
        self.assertEqual(self.calls(), [])


if __name__ == "__main__":
    unittest.main(verbosity=2)
