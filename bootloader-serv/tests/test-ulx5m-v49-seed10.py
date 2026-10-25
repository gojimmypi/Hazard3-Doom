#!/usr/bin/env python3
"""Offline seed-10 build-isolation and CI-artifact validator regressions."""
import hashlib
import importlib.util
import shutil
import subprocess
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
MAKEFILE = ROOT / 'Makefile.ulx5m-spi-secondary'
VALIDATOR = ROOT / 'tests/qualify-ulx5m-v49-seed10.py'
INSPECTOR = ROOT / 'tests/inspect-ulx5m-v47-primary.py'
TRAILER = bytes.fromhex('c3 01 0c fe 00 cc c6 da 04 28 eb 00 10 20 00 29 51 00 00')

spec = importlib.util.spec_from_file_location('seed10', VALIDATOR)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class Seed10(unittest.TestCase):
    def test_default_seed_and_isolated_files(self):
        src = MAKEFILE.read_text(encoding='ascii')
        self.assertIn('SPI_SECONDARY_SEED ?= 10', src)
        self.assertIn('spi-secondary-seed$(SPI_SECONDARY_SEED).txt', src)
        self.assertIn('spi-secondary-spi-primary-seed$(SPI_SECONDARY_SEED).bit', src)
        self.assertIn('pnr-seed$(SPI_SECONDARY_SEED).log', src)
        self.assertIn('.DELETE_ON_ERROR:', src)
        self.assertIn('--bootaddr $(SPI_SECONDARY_ADDR)', src)
        self.assertIn('tests/inspect-ulx5m-v47-primary.py', src)
        self.assertIn('SPI_SECONDARY_ADDR := 2101248', src)

    def test_make_evaluates_seed_named_artifacts(self):
        if shutil.which('make') is None:
            self.skipTest('make unavailable')
        with tempfile.TemporaryDirectory() as name:
            work = Path(name)
            (work / 'Makefile.ulx5m-native-dfu').write_text(
                'BUILD_DIR := build-ulx5m-gs\n', encoding='ascii')
            (work / 'print.mk').write_text(
                '.PHONY: info\ninfo:\n'
                '\t@printf "%s\\n" "$(SPI_SECONDARY_SEED)" "$(SPI_SECONDARY_IMPL)" "$(SPI_SECONDARY_BIT)"\n',
                encoding='ascii')
            def get(*overrides):
                return subprocess.check_output([
                    'make', '--no-print-directory', '-s', '-f', str(MAKEFILE),
                    '-f', 'print.mk', 'info', *overrides], cwd=work, text=True).splitlines()
            default = get()
            changed = get('SPI_SECONDARY_SEED=11')
            self.assertEqual(default[0], '10')
            self.assertEqual(changed[0], '11')
            self.assertEqual(default[1], 'build-ulx5m-gs/normal-boot-dfu-hw-native/spi-secondary-seed10.txt')
            self.assertTrue(default[2].endswith('/spi-secondary-spi-primary-seed10.bit'))
            self.assertNotEqual(default[1:], changed[1:])

    def make_evidence(self, temp):
        g = temp / 'group'
        f = temp / 'frozen'
        g.mkdir(); f.mkdir()
        inputs = {'netlist.json': b'json', 'constraints.ccf': b'ccf', 'constraints.sdc': b'sdc'}
        for name, data in inputs.items():
            (f / name).write_bytes(data)
        netsha = hashlib.sha256(inputs['netlist.json']).hexdigest()
        (f / 'SHA256SUMS').write_text(''.join('%s  %s\n' % (hashlib.sha256(data).hexdigest(), name)
                                                   for name, data in inputs.items()), encoding='ascii')
        (f / 'metadata.txt').write_text('target=spi-secondary\ngmpack_bootaddr=0x201000\ncommit=test123\nnetlist_sha256=%s\n' % netsha, encoding='ascii')
        (g / 'build-info.txt').write_text('target=spi-secondary\nbootaddr=0x201000\ncommit=test123\nnetlist_sha256=%s\n' % netsha, encoding='ascii')
        (g / 'inputs.sha256').write_text(''.join('%s  /tmp/frozen/%s\n' % (hashlib.sha256(data).hexdigest(), name) for name, data in inputs.items()), encoding='ascii')
        (g / 'results.tsv').write_text('seed\tstatus\tfmax_mhz\tmargin_mhz\texit_code\telapsed_seconds\tlog\n10\tPASS\t48.19\t0.19\t0\t42\tseed-10.log\n', encoding='ascii')
        (g / 'seed-10.log').write_text("Info: Routing complete.\nInfo: Max frequency for clock 'bram_i.clk': 48.19 MHz (PASS at 48.00 MHz)\n", encoding='ascii')
        (g / 'best-seed-10.bit').write_bytes(b'v49 synthetic primary' + TRAILER)
        return g, f

    def test_valid_synthetic_evidence(self):
        with tempfile.TemporaryDirectory() as name:
            group, frozen = self.make_evidence(Path(name))
            result = mod.validate(group, frozen, INSPECTOR)
            self.assertEqual(result['seed'], 10)
            self.assertEqual(result['fmax_mhz'], 48.19)

    def test_rejects_wrong_netlist(self):
        with tempfile.TemporaryDirectory() as name:
            group, frozen = self.make_evidence(Path(name))
            (frozen / 'netlist.json').write_bytes(b'different')
            with self.assertRaisesRegex(ValueError, 'netlist'):
                mod.validate(group, frozen, INSPECTOR)

    def test_rejects_failed_final_route(self):
        with tempfile.TemporaryDirectory() as name:
            group, frozen = self.make_evidence(Path(name))
            (group / 'seed-10.log').write_text("Routing complete.\nMax frequency for clock 'bram_i.clk': 47.5 MHz (FAIL at 48.00 MHz)\n", encoding='ascii')
            with self.assertRaisesRegex(ValueError, 'clock'):
                mod.validate(group, frozen, INSPECTOR)

    def test_rejects_wrong_bootaddr_trailer(self):
        with tempfile.TemporaryDirectory() as name:
            group, frozen = self.make_evidence(Path(name))
            p = group / 'best-seed-10.bit'
            data = p.read_bytes()
            p.write_bytes(data[:-1] + bytes([data[-1] ^ 1]))
            with self.assertRaisesRegex(ValueError, 'trailer'):
                mod.validate(group, frozen, INSPECTOR)

    def test_rejects_missing_bitstream(self):
        with tempfile.TemporaryDirectory() as name:
            group, frozen = self.make_evidence(Path(name))
            (group / 'best-seed-10.bit').unlink()
            with self.assertRaisesRegex(ValueError, 'absent'):
                mod.validate(group, frozen, INSPECTOR)

    def test_rejects_mixed_constraints(self):
        with tempfile.TemporaryDirectory() as name:
            group, frozen = self.make_evidence(Path(name))
            (group / 'inputs.sha256').write_text('bad  /tmp/frozen/netlist.json\n', encoding='ascii')
            with self.assertRaisesRegex(ValueError, 'frozen inputs'):
                mod.validate(group, frozen, INSPECTOR)

    def test_rejects_mixed_commits(self):
        with tempfile.TemporaryDirectory() as name:
            group, frozen = self.make_evidence(Path(name))
            (group / 'build-info.txt').write_text('target=spi-secondary\nbootaddr=0x201000\ncommit=different\n', encoding='ascii')
            with self.assertRaisesRegex(ValueError, 'mixed sweep commits'):
                mod.validate(group, frozen, INSPECTOR)

    def test_rejects_wrong_target(self):
        with tempfile.TemporaryDirectory() as name:
            group, frozen = self.make_evidence(Path(name))
            (group / 'build-info.txt').write_text('target=normal-boot\nbootaddr=0x201000\ncommit=test123\n', encoding='ascii')
            with self.assertRaisesRegex(ValueError, 'target'):
                mod.validate(group, frozen, INSPECTOR)


if __name__ == '__main__':
    unittest.main(verbosity=2)
