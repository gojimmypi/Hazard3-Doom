#!/usr/bin/env python3
"""Read-only tests for full-SERV v73 command seeding (no FPGA hardware)."""
import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
HERE = Path(__file__).resolve().parent
V63C_REFERENCE = ROOT / ('build-ulx5m-gs/'
    'v63c-reconfig-PACK-ONLY-20261027T193352039818Z-3024/'
    'EXPERIMENTAL-NOT-FOR-FLASH.bit')
V72_PROBE = ROOT / ('build-ulx5m-gs/v72-registered-probe/'
    'top_ulx5m_gs_v72_cfg_registered_probe-seed302-PACK-ONLY.bit')
V63C_SHA = '689f17a6b2e5ba1669e8f7652da4163b2d824ec91878b767e202ca1b33b9d4a2'
FULL_SHA = 'aab512b6714eafa14fc96458fdf3852e7881642b26c9ac891082a58209f33468'
V72_SHA = '8fbec9715a209dac2dc35dc6b517972b9d64dcdc5a7b4437fac7731a0d2849e4'


def load(name, mod):
    spec = importlib.util.spec_from_file_location(mod, HERE / name)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


bootstrap = load('v73-gh-bootstrap-rom.py', 'v73f_bootstrap')
generator = load('mk-ulx5m-v72-cmd.py', 'v73f_generator')


class V73FullServRom(unittest.TestCase):
    def test_full_serv_command_is_pinned(self):
        self.assertEqual(len(bootstrap.FRAME), 27)
        self.assertEqual(hashlib.sha256(bootstrap.FRAME).hexdigest(), FULL_SHA)
        self.assertEqual(bootstrap.SHA256, FULL_SHA)
        self.assertEqual(bootstrap.FRAME[4:10], bytes.fromhex('17 10 00 21 C7 01'))

    def test_archive_reference_matches_when_available(self):
        if not V63C_REFERENCE.exists():
            self.skipTest('archived v63c reference absent; pinned frame still checked')
        data = V63C_REFERENCE.read_bytes()
        self.assertEqual(hashlib.sha256(data).hexdigest(), V63C_SHA)
        self.assertEqual(generator.derive(data), bootstrap.FRAME)

    def test_minimal_v72_reference_is_different(self):
        if not V72_PROBE.exists():
            self.skipTest('v72 reference absent; command inequality checked via SHA')
        data = V72_PROBE.read_bytes()
        self.assertEqual(hashlib.sha256(generator.derive(data)).hexdigest(), V72_SHA)
        self.assertNotEqual(generator.derive(data), bootstrap.FRAME)

    def test_local_and_gh_use_same_rom_source(self):
        make = (ROOT / 'Makefile.ulx5m-v73-integrated').read_text(encoding='ascii')
        gh = (ROOT / 'Makefile.ulx5m-v73-gh-sweep').read_text(encoding='ascii')
        flow = (ROOT.parent / '.github/workflows/ulx5m-bootloader-seed-sweep.yml').read_text(encoding='ascii')
        self.assertIn('tests/v73-gh-bootstrap-rom.py --output $(V73_CMD)', make)
        self.assertIn('tests/v73-gh-bootstrap-rom.py --output $(V73_CMD)', gh)
        self.assertIn('bootstrap=full-serv-v63c-status-command-unqualified', flow)
        self.assertNotIn('V72_PROVEN_BIT', make)
        self.assertIn('tests/mk-ulx5m-v72-cmd.py --bit $(V73_BIT) --hex $(V73_CMD) --check', make)
        self.assertIn('--reconfig --bootaddr 2101248', make)
        self.assertNotIn('openFPGALoader', make)
        self.assertNotIn('dfu-util', make)

    def test_rom_write_check_and_reject_stale(self):
        with tempfile.TemporaryDirectory() as directory:
            file = Path(directory) / 'cmd.hex'
            file.write_text(bootstrap.output_text(), encoding='ascii')
            self.assertEqual(file.read_text(), bootstrap.output_text())
            self.assertEqual(file.read_bytes().count(b'\n'), 27)
            file.write_text('00\n' * 27, encoding='ascii')
            self.assertNotEqual(file.read_text(), bootstrap.output_text())


if __name__ == '__main__':
    unittest.main(verbosity=2)
