#!/usr/bin/env python3
"""Regression tests for the one canonical ULX5M timing sweep, without CAD tools."""
import csv
import io
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[2]
TOOL = ROOT / '.github/scripts/ulx5m_bootloader_sweep.py'
SPEC = importlib.util.spec_from_file_location('ulx5m_bootloader_sweep', TOOL)
SWEEP = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SWEEP)


class SweepOfflineTests(unittest.TestCase):
    def test_matrix_and_seed_guards(self):
        proc = subprocess.run(
            [sys.executable, str(TOOL), 'matrix', '--first', '1',
             '--last', '9', '--per-job', '4'],
            capture_output=True, text=True, check=True)
        self.assertIn('"first":1,"last":4', proc.stdout)
        self.assertIn('"first":9,"last":9', proc.stdout)
        # Any positive starting seed; no more than 512 consecutive seeds.
        self.assertEqual(SWEEP.sweep_last(750, None, 512), 1261)
        self.assertEqual(SWEEP.sweep_last(10000, None, 1), 10000)
        for count in (0, 513):
            with self.assertRaises(ValueError):
                SWEEP.sweep_last(750, None, count)
        with self.assertRaises(ValueError):
            SWEEP.sweep_last(0, None, 512)
        proc = subprocess.run(
            [sys.executable, str(TOOL), 'matrix', '--first', '750',
             '--count', '512', '--per-job', '5'],
            capture_output=True, text=True, check=True)
        groups = json.loads(proc.stdout)['include']
        self.assertEqual(len(groups), 103)
        self.assertEqual((groups[0]['first'], groups[-1]['last']), (750, 1261))

    def test_both_clock_names_and_constraints_mandatory(self):
        good = ("Max frequency for clock 'cfg25_i.clk25': 66.56 MHz "
                "(PASS at 25.00 MHz)\n"
                "Max frequency for clock    'bram_i.clk': 49.67 MHz "
                "(PASS at 48.00 MHz)\n")
        self.assertEqual(SWEEP.timing(good), (True, 66.56, 49.67))
        bad = good.replace('49.67', '44.67').replace('PASS at 48', 'FAIL at 48')
        self.assertEqual(SWEEP.timing(bad), (False, 66.56, 44.67))
        self.assertFalse(SWEEP.timing(good.replace('bram_i.clk', 'other'))[0])
        self.assertFalse(SWEEP.timing(good.replace('48.00', '40.00'))[0])
        self.assertFalse(SWEEP.timing(good.replace('25.00', '20.00'))[0])
        self.assertFalse(SWEEP.timing(good + "Max frequency for clock 'extra': 1 MHz (FAIL at 2 MHz)\n")[0])

    def test_mock_full_build_and_summary(self):
        # Simulate the real Makefile build/qualify interface. A frozen-netlist
        # route command is not part of the canonical CI or local workflow.
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            project = root / 'bootloader-serv'
            project.mkdir()
            (project / 'Makefile.ulx5m-gs').write_text('mock only\n', encoding='ascii')
            fake_make = root / 'make'
            fake_make.write_text('''#!/usr/bin/env python3
import pathlib, shutil, sys
args = sys.argv[1:]
target = args[args.index('-f') + 2]
seed = int(next((x.split('=', 1)[1] for x in args if x.startswith('SEED=')), '0'))
assert all(x in args for x in ('HEAP_BETA=0.7', 'NEXTPNR_EXTRA_ARGS=--timing-allow-fail')) or target == 'clean'
out = pathlib.Path('build-ulx5m-gs/bootloader')
if target == 'clean':
    shutil.rmtree('build-ulx5m-gs', ignore_errors=True)
elif target == 'build':
    out.mkdir(parents=True, exist_ok=True)
    passed = seed != 2
    (out / 'pnr.log').write_text(
        "Max frequency for clock 'cfg25_i.clk25': 66.56 MHz (PASS at 25.00 MHz)\\n"
        "Max frequency for clock 'bram_i.clk': " +
        ("49.67 MHz (PASS" if seed == 1 else
         "50.00 MHz (PASS" if passed else "44.67 MHz (FAIL") +
        " at 48.00 MHz)\\n", encoding='ascii')
    if passed:
        (out / 'top_ulx5m_gs_bootloader-PACK-ONLY.bit').write_bytes(
            ('packed seed %d\\n' % seed).encode('ascii'))
    else:
        sys.exit(1)
elif target == 'qualify':
    assert (out / 'top_ulx5m_gs_bootloader-PACK-ONLY.bit').is_file()
else:
    sys.exit('unexpected Makefile target: ' + target)
''', encoding='ascii')
            fake_make.chmod(0o755)
            out = root / 'groups'
            cmd = [
                sys.executable, str(TOOL), 'full-build', '--first', '1',
                '--last', '3', '--project', str(project), '--make', str(fake_make),
                '--timeout', '30', '--heap-beta', '0.7',
                '--extra-args=--timing-allow-fail', '--output', str(out)]
            proc = subprocess.run(cmd, capture_output=True, text=True,
                                  timeout=15, check=False)
            self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
            with (out / 'group-1-3.csv').open(newline='', encoding='ascii') as fh:
                rows = list(csv.DictReader(fh))
            self.assertEqual([r['status'] for r in rows],
                             ['PASS_FINAL', 'FAIL_TIMING', 'PASS_FINAL'])
            self.assertEqual(rows[1]['bram48_mhz'], '44.67')
            self.assertEqual(sorted(x.name for x in (out / 'logs').glob('*.log')),
                             ['seed-1.log', 'seed-2.log', 'seed-3.log'])
            self.assertEqual([x.name for x in
                             (out / 'qualified-PACK-ONLY').glob('*.bit')],
                             ['seed-3-PACK-ONLY.bit'])
            # Retention is operational: keep all passing full-build images.
            out_all = root / 'all'
            proc = subprocess.run(cmd[:-2] + ['--retain-bitstreams',
                                  '--output', str(out_all)],
                                  capture_output=True, text=True,
                                  timeout=15, check=False)
            self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
            self.assertEqual(sorted(x.name for x in
                             (out_all / 'qualified-PACK-ONLY').glob('*.bit')),
                             ['seed-1-PACK-ONLY.bit', 'seed-3-PACK-ONLY.bit'])
            summary = root / 'summary'
            proc = subprocess.run([
                sys.executable, str(TOOL), 'summarize',
                '--input', str(out), '--output', str(summary)],
                capture_output=True, text=True, check=False)
            self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
            result = (summary / 'summary.md').read_text(encoding='ascii')
            self.assertIn('Timing + final-image qualification PASS: 2 seeds', result)
            self.assertIn('Makefile.ulx5m-gs build SEED=N', result)

    def test_canonical_makefile_target(self):
        mk = (ROOT / 'bootloader-serv/Makefile.ulx5m-gs').read_text(encoding='ascii')
        self.assertIn('build: test verify-serv', mk)
        self.assertIn('qualify:', mk)
        self.assertIn('$(PYTHON) $(CLI) qualify --bit $(BIT)', mk)
        self.assertIn('$(YOSYS) -p', mk)
        self.assertIn('--seed $(SEED)', mk)
        self.assertIn('HEAP_BETA ?= 0.6', mk)
        self.assertIn('--placer-heap-beta=$(HEAP_BETA)', mk)
        self.assertIn('$(NEXTPNR_EXTRA_ARGS)', mk)
        self.assertIn('$(PYTHON) $(CLI) bootstrap --output $(CMD);', mk)
    def test_nextpnr_arguments_are_passed_without_shell_or_override(self):
        self.assertEqual(SWEEP.extra_nextpnr_args('--timing-allow-fail --verbose'),
                         ['--timing-allow-fail', '--verbose'])
        for value in ('--seed 4', '--device=other', '--json foo.json',
                      '--placer-heap-beta=0.4', '-o out=bad', '-l bad.log'):
            with self.assertRaises(ValueError, msg=value):
                SWEEP.extra_nextpnr_args(value)

    def test_live_collector_reads_artifact_groups_incrementally(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            rows = [dict(zip(SWEEP.FIELDS, fields)) for fields in (
                ('1', 'PASS_FINAL', '66.56', '49.67', '0', '12.3'),
                ('2', 'FAIL_TIMING', '66.56', '44.67', '1', '13.4'),
                ('3', 'PASS_FINAL', '60.11', '50.00', '0', '10.1'))]
            groups = {'1-2': rows[:2], '3-3': rows[2:]}
            snapshots = [
                [{'name': 'ulx5m-group-1-2-1234', 'id': 10, 'expired': False}],
                [{'name': 'ulx5m-group-1-2-1234', 'id': 10, 'expired': False},
                 {'name': 'ulx5m-group-3-3-1234', 'id': 11, 'expired': False}]]
            calls = []
            def artifact_list(repo, run_id):
                self.assertEqual((repo, run_id), ('org/example', 1234))
                calls.append(1)
                return snapshots[min(len(calls) - 1, len(snapshots) - 1)]
            def artifact_fetch(repo, artifact_id, group):
                self.assertEqual(artifact_id, {'1-2': 10, '3-3': 11}[group])
                return groups[group]
            args = type('Args', (), dict(first=1, last=None, count=3, per_job=2,
                repo='org/example', run_id=1234, output=root,
                max_minutes=5, interval=1, step_summary=str(root / 'step.md')))()
            with patch.object(SWEEP, 'list_run_artifacts', side_effect=artifact_list), \
                    patch.object(SWEEP, 'fetch_group_csv', side_effect=artifact_fetch), \
                    patch.object(SWEEP.time, 'sleep', return_value=None):
                self.assertEqual(SWEEP.watch(args), 0)
            self.assertEqual(len(calls), 2)
            self.assertIn('seed 1', (root / 'live.md').read_text(encoding='ascii'))
            self.assertIn('seed 3', (root / 'live.md').read_text(encoding='ascii'))
            self.assertIn('Group 1-2: 1 final passes',
                          (root / 'step.md').read_text(encoding='ascii'))
            with (root / 'live-results.csv').open(newline='', encoding='ascii') as fp:
                self.assertEqual(len(list(csv.DictReader(fp))), 3)

    def test_workflow_has_live_watcher_and_operational_inputs(self):
        workflow = (ROOT / '.github/workflows/ulx5m-bootloader-seed-sweep.yml').read_text()
        for item in ('retain_bitstreams:', 'synth_oss_cad_suite_version:',
                     'route_oss_cad_suite_version:', 'ulx5m_heap_beta:',
                     'nextpnr_extra_args:', 'LIVE timing-pass collector',
                     'SWEEP_HEAP_BETA', 'SWEEP_NEXTPNR_EXTRA_ARGS',
                     'RETAIN_BITSTREAMS', 'actions: read'):
            self.assertIn(item, workflow)
        self.assertIn('description: Consecutive seeds to test (1..512)', workflow)
        self.assertIn('SWEEP_COUNT: ${{ inputs.seed_count }}', workflow)
        self.assertNotIn('      seed_last:', workflow)
        self.assertNotIn('SWEEP_LAST', workflow)
        self.assertNotIn('v73-integrated', workflow)
        self.assertIn('watch:', workflow)



if __name__ == '__main__':
    unittest.main(verbosity=2)
