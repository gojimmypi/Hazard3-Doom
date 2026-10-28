#!/usr/bin/env python3
"""Offline, toolchain-free tests for the v73 GitHub Actions seed workflow."""
import csv
import hashlib
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent


def load(script, name):
    spec = importlib.util.spec_from_file_location(name, HERE / script)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


sweep = load('sweep-ulx5m-v73-gh.py', 'sweep_v73_gh')
bootstrap = load('v73-gh-bootstrap-rom.py', 'bootstrap_v73_gh')


class V73GitHubSweep(unittest.TestCase):
    def test_proven_bootstrap_exact_sha(self):
        payload = bootstrap.FRAME
        self.assertEqual(len(payload), 27)
        self.assertEqual(hashlib.sha256(payload).hexdigest(), bootstrap.SHA256)
        self.assertEqual(bootstrap.output_text().count('\n'), 27)

    def test_v73_synthesis_requires_pinned_serv_sources(self):
        root = HERE.parent
        legacy = (root / 'Makefile.ulx5m-gs').read_text(encoding='ascii')
        local = (root / 'Makefile.ulx5m-v73-integrated').read_text(encoding='ascii')
        github = (root / 'Makefile.ulx5m-v73-gh-sweep').read_text(encoding='ascii')
        self.assertIn('v73-gh-synth: $(SERV_STAMP) $(SERV_RTL) $(PROBE_MC)', github)
        self.assertIn('v73-build: v73-prepare v73-test $(SERV_STAMP) $(SERV_RTL) $(PROBE_MC)', local)
        self.assertIn('SERV_TAG := 1.4.0', legacy)
        self.assertIn('SERV_COMMIT := 7d9cde4', legacy)
        self.assertIn('$(SERV_RTL): $(SERV_STAMP)', legacy)
        self.assertIn("git clone --quiet --depth 1 --branch '$(SERV_TAG)'", legacy)
        self.assertIn("if [ \"$$rev\" != '$(SERV_COMMIT)' ]", legacy)

    def test_microcode_generator_matches_full_serv_reference(self):
        root = HERE.parent
        legacy = (root / 'Makefile.ulx5m-gs').read_text(encoding='ascii')
        local = (root / 'Makefile.ulx5m-v73-integrated').read_text(encoding='ascii')
        github = (root / 'Makefile.ulx5m-v73-gh-sweep').read_text(encoding='ascii')
        top = (root / 'rtl/top-ulx5m-gs-flash-read.v').read_text(encoding='ascii')
        self.assertIn('PROBE_MC := $(BUILD_DIR)/usb_trans_mc.hex', legacy)
        self.assertIn('$(PROBE_MC): cores/usb/utils/microcode.py | $(BUILD_DIR)', legacy)
        self.assertIn('python3 $< > $@', legacy)
        self.assertIn('$(PROBE_MC)', github)
        self.assertIn('$(PROBE_MC)', local)
        self.assertIn('test -s $(PROBE_MC)', github)
        self.assertIn('test -s $(PROBE_MC)', local)
        self.assertIn('.MC_INIT_FILE("build-ulx5m-gs/usb_trans_mc.hex")', top)
        result = subprocess.run([sys.executable, 'cores/usb/utils/microcode.py'],
                                cwd=root, capture_output=True, check=True)
        self.assertEqual(len(result.stdout), 775)
        self.assertEqual(hashlib.sha256(result.stdout).hexdigest(),
                         'ca5ba19844e125bea322b5ae8cb0a3d748199753ad0a9cfe8d6b4a6ccf6f4832')

    def test_fresh_ci_make_graph_generates_microcode_before_yosys(self):
        root = HERE.parent
        result = subprocess.run(['make', '-B', '-n', '-f', 'Makefile.ulx5m-v73-gh-sweep',
                                 'v73-gh-synth'], cwd=root, text=True,
                                capture_output=True, check=True)
        marker = 'python3 cores/usb/utils/microcode.py > build-ulx5m-gs/usb_trans_mc.hex'
        self.assertIn(marker, result.stdout)
        self.assertLess(result.stdout.index(marker), result.stdout.index('yosys -p'))

    def test_matrix_partition_and_guard(self):
        groups = sweep.matrix(1, 260, 4)
        self.assertEqual(len(groups), 65)
        self.assertEqual(groups[0], {'group': '1-4', 'first': 1, 'last': 4})
        self.assertEqual(groups[-1], {'group': '257-260', 'first': 257, 'last': 260})
        self.assertRaises(ValueError, sweep.matrix, 1, 2000, 1)
        self.assertRaises(ValueError, sweep.matrix, 4, 1, 2)

    def test_only_final_routed_fmax_counts(self):
        early = "Max frequency for clock 'bram_i.clk': 60.00 MHz (PASS at 48.00 MHz)\n"
        late = "Max frequency for clock 'bram_i.clk': 40.87 MHz (FAIL at 48.00 MHz)\n"
        self.assertIsNone(sweep.routed_result(early + late + 'Program finished normally.'))
        self.assertEqual(sweep.routed_result(early + 'Routing complete.\n' + late +
                                             'Program finished normally.'),
                         (40.87, 'FAIL', 48.0))
        self.assertEqual(sweep.routed_result(early + 'Routing complete.\n' + early +
                                             'Program finished normally.'),
                         (60.0, 'PASS', 48.0))

    def test_route_rejects_failed_and_accepts_real_pass(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            for name in ('netlist.json', 'constraints.ccf', 'constraints.sdc'):
                (root / name).write_text(name, encoding='ascii')
            count = [0]

            def fake_run(command, **kwargs):
                count[0] += 1
                seed = int(command[command.index('--seed') + 1])
                log = Path(command[command.index('-l') + 1])
                # Find the out= argument independent of path spelling.
                impl = Path(next(item[4:] for item in command if item.startswith('out=')))
                fmax = 40.87 if seed == 122 else 50.12
                status = 'FAIL' if seed == 122 else 'PASS'
                log.write_text('Routing complete.\nMax frequency for clock '
                               "'bram_i.clk': %.2f MHz (%s at 48.00 MHz)\n"
                               'Program finished normally.\n' % (fmax, status), encoding='ascii')
                impl.write_text('mock result', encoding='ascii')
                return SimpleNamespace(returncode=1 if seed == 122 else 0,
                                       stdout='', stderr='')

            args = SimpleNamespace(first=122, last=123, nextpnr='nextpnr',
                                   netlist=root / 'netlist.json',
                                   ccf=root / 'constraints.ccf', sdc=root / 'constraints.sdc',
                                   output=root / 'group', timeout=90)
            with patch.object(sweep.subprocess, 'run', side_effect=fake_run):
                sweep.route(args)
            with (root / 'group/results.csv').open(newline='', encoding='ascii') as fp:
                rows = list(csv.DictReader(fp))
            self.assertEqual([(r['seed'], r['status']) for r in rows],
                             [('122', 'FAIL'), ('123', 'PASS')])
            self.assertEqual(count[0], 2)
            self.assertFalse((root / 'group/route-seed-123.txt').exists())

    def test_summary_checks_completeness_and_rank(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            out = root / 'groups/1-3'
            out.mkdir(parents=True)
            with (out / 'results.csv').open('w', newline='', encoding='ascii') as fp:
                fp.write('seed,status,fmax_mhz,exit_code\n'
                         '1,FAIL,40.87,1\n2,PASS,50.12,0\n3,PASS,49.98,0\n')
            args = SimpleNamespace(first=1, last=3, groups=root / 'groups',
                                   output=root / 'report')
            self.assertEqual(sweep.summarize(args), 0)
            with (root / 'report/ranking.csv').open(newline='', encoding='ascii') as fp:
                ranking = list(csv.DictReader(fp))
            self.assertEqual([int(item['seed']) for item in ranking], [2, 3])
            args.last = 4
            self.assertRaises(ValueError, sweep.summarize, args)

    def test_no_pass_fails(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            out = root / 'groups/1-1'
            out.mkdir(parents=True)
            (out / 'results.csv').write_text('seed,status,fmax_mhz,exit_code\n1,FAIL,40.87,1\n',
                                             encoding='ascii')
            args = SimpleNamespace(first=1, last=1, groups=root / 'groups',
                                   output=root / 'report')
            self.assertEqual(sweep.summarize(args), 1)


if __name__ == '__main__':
    unittest.main(verbosity=2)
