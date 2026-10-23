#!/usr/bin/env python3
"""Offline regression tests for the ULX5M SERV toolchain gate."""
import os
import pathlib
import shutil
import subprocess
import tempfile
import unittest

SCRIPT_DIR = pathlib.Path(__file__).resolve().parent
WRAPPER = SCRIPT_DIR / "build-ulx5m-gs-bootloader.sh"
CHECKER = SCRIPT_DIR / "check-ulx5m-oss-cad-suite.sh"


def write_exe(path, contents):
    path.write_text(contents, encoding="ascii")
    path.chmod(0o755)


class ToolchainGateTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="ulx5m-toolchain-gate-")
        self.addCleanup(self.tmp.cleanup)
        self.root = pathlib.Path(self.tmp.name)
        scripts = self.root / "scripts"
        scripts.mkdir()
        build = self.root / "bootloader-serv" / "build-ulx5m-gs"
        build.mkdir(parents=True)
        self.build = build
        (self.root / "bootloader-serv" / "Makefile.ulx5m-gs").write_text(
            "# mock only\n", encoding="ascii")
        shutil.copy2(WRAPPER, scripts / WRAPPER.name)
        shutil.copy2(CHECKER, scripts / CHECKER.name)
        (scripts / WRAPPER.name).chmod(0o755)
        (scripts / CHECKER.name).chmod(0o755)
        fakebin = self.root / "fakebin"
        fakebin.mkdir()
        self.fakebin = fakebin
        write_exe(fakebin / "yosys", '''#!/bin/sh
if [ "$1" = '-V' ]; then
    printf '%s\\n' "${FAKE_YOSYS_VERSION:-Yosys 0.67+47 (git sha1 5f29546d8-dirty, Release, Clang /usr/bin/clang++ 18.1.8)}"
else
    exit 40
fi
''')
        write_exe(fakebin / "nextpnr-himbaechel", '''#!/bin/sh
if [ "$1" = '--version' ]; then
    printf '%s\\n' "${FAKE_NEXTPNR_VERSION:-\"nextpnr-himbaechel\" -- Next Generation Place and Route (Version nextpnr-0.10-95-gddc6c8c8)}" >&2
else
    exit 41
fi
''')
        write_exe(fakebin / "gmpack", "#!/bin/sh\nexit 42\n")
        write_exe(fakebin / "make", '''#!/bin/sh
printf 'called\\n' >> "$MOCK_MAKE_CALLS"
mkdir -p "$MOCK_BUILD"
printf 'json\\n' > "$MOCK_BUILD/top_ulx5m_gs_flash_read-serv.json"
printf 'route\\n' > "$MOCK_BUILD/top_ulx5m_gs_flash_read-serv.txt"
printf 'bit\\n' > "$MOCK_BUILD/top_ulx5m_gs_flash_read-serv.bit"
printf "Info: Max frequency for clock 'bram_i.clk': 50.06 MHz (PASS at 48.00 MHz)\\n" > "$MOCK_BUILD/flash-read-serv-pnr.log"
''')
        self.calls = self.root / "make.calls"
        self.env = os.environ.copy()
        self.env.pop("OSS_CAD_SUITE_VERSION", None)
        self.env["PATH"] = str(fakebin) + os.pathsep + os.environ["PATH"]
        self.env["MOCK_BUILD"] = str(build)
        self.env["MOCK_MAKE_CALLS"] = str(self.calls)

    def run_wrapper(self, *args, **changes):
        env = self.env.copy()
        env.update(changes)
        return subprocess.run(
            ["bash", str(self.root / "scripts" / WRAPPER.name), *args],
            cwd=self.root, env=env, text=True, capture_output=True, check=False)

    def test_stderr_only_nextpnr_version_is_accepted(self):
        result = self.run_wrapper("--seed", "148")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("PASS: pinned Yosys and nextpnr versions match", result.stdout)
        self.assertIn("50.06 MHz", result.stdout)
        self.assertTrue(self.calls.exists())
        self.assertTrue((self.build / "top_ulx5m_gs_flash_read-serv.bit").is_file())

    def test_wrong_nextpnr_blocks_before_deleting_outputs(self):
        bit = self.build / "top_ulx5m_gs_flash_read-serv.bit"
        bit.write_bytes(b"preserved")
        result = self.run_wrapper(FAKE_NEXTPNR_VERSION="nextpnr-unknown")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unexpected nextpnr build", result.stderr)
        self.assertEqual(bit.read_bytes(), b"preserved")
        self.assertFalse(self.calls.exists())

    def test_wrong_yosys_blocks_before_make(self):
        result = self.run_wrapper(FAKE_YOSYS_VERSION="Yosys 0.66")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unexpected Yosys build", result.stderr)
        self.assertFalse(self.calls.exists())

    def test_suite_override_is_not_accepted(self):
        result = self.run_wrapper(OSS_CAD_SUITE_VERSION="2026-01-01")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("requires OSS CAD Suite", result.stderr)
        self.assertFalse(self.calls.exists())

    def test_help_has_no_toolchain_or_make_side_effect(self):
        result = self.run_wrapper("--help")
        self.assertEqual(result.returncode, 0)
        self.assertIn("Usage:", result.stdout)
        self.assertFalse(self.calls.exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
