#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Check sweep summary classification and rolling history without FPGA tools."""
import csv
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent


class ReportingTests(unittest.TestCase):
    def test_workflow_matrix_boundaries(self):
        generator = str(SCRIPT_DIR / 'generate-ecp5-seed-matrix.py')
        for board in ('ulx3s-12f', 'ulx3s-45f', 'ulx3s-85f', 'ulx4m-ld-85f', 'ulx5m-gs'):
            preflight = board != 'ulx5m-gs'
            capacity = 512 + int(preflight)
            for count in (1, 2, 512, capacity, capacity + 1):
                with self.subTest(board=board, count=count):
                    result = subprocess.run([sys.executable, generator, '--first', '750',
                                             '--last', str(749 + count), '--per-job', '2',
                                             '--target', board], capture_output=True, text=True)
                    if count > capacity:
                        self.assertNotEqual(result.returncode, 0)
                        continue
                    self.assertEqual(result.returncode, 0, result.stderr)
                    plan = json.loads(result.stdout)
                    first = plan['preflight_matrix']['include']
                    self.assertEqual(first, [{'group': 'preflight', 'seeds': '750'}] if preflight else [])
                    remaining = plan['matrix']['include']
                    self.assertLessEqual(len(remaining), 256)
                    self.assertEqual(plan['has_remaining'], bool(remaining))
                    seeds = [int(seed) for group in first + remaining for seed in group['seeds'].split()]
                    self.assertEqual(seeds, list(range(750, 750 + count)))

    def test_completed_seed_validation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            metadata = root / 'metadata.txt'
            metadata.write_text('result_columns=seed,clk_sys_mhz,clk_video_mhz,clk_tmds_mhz,route_seconds,timing_status\n'
                                'clk_sys_required_mhz=25\nclk_video_required_mhz=25\nclk_tmds_required_mhz=125\n')
            command = [sys.executable, str(SCRIPT_DIR / 'summarize-ecp5-sweep.py'),
                       '--target', 'ulx3s-85f', '--seed-first', '1', '--seed-last', '1',
                       '--seed-dir', str(root), '--metadata', str(metadata), '--validate-completed-seed']
            cases = [('0', '1,30,40,200,100,PASS', True),
                     ('0', '1,20,40,200,100,FAIL', True),
                     ('0', '1,30,40,200,100,FAIL', True),
                     ('0', '1,20,40,200,100,PASS', False),
                     ('0', '2,30,40,200,100,PASS', False),
                     ('0', '1,NaN,40,200,100,PASS', False),
                     ('0', '1,30,40,200,-1,PASS', False),
                     ('0', None, False),
                     ('1', '1,30,40,200,100,PASS', False),
                     ('124', '1,30,40,200,100,FAIL', False)]
            for status, row, valid in cases:
                with self.subTest(status=status, row=row):
                    (root / 'exit-1.txt').write_text(status + '\n')
                    path = root / 'result-seed-1.csv'
                    if row is None:
                        path.unlink(missing_ok=True)
                    else:
                        path.write_text(row + '\n')
                    result = subprocess.run(command, capture_output=True, text=True)
                    self.assertEqual(result.returncode == 0, valid, result.stdout + result.stderr)
            self.assertFalse((root / 'summary.csv').exists())

    def test_history_multiple_attempts_and_schema(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            older = root / 'older.csv'
            newer = root / 'newer.csv'
            current = root / 'current.csv'
            merged = root / 'merged.csv'
            older.write_text('run_id,run_attempt,board,pass_count\n100,1,ulx3s-85f,1\n101,1,ulx3s-85f,2\n')
            newer.write_text('run_id,run_attempt,board,pass_count,nextpnr_version\n100,1,ulx3s-85f,1,old\n102,1,ulx3s-85f,3,new\n')
            current.write_text('run_id,run_attempt,board,pass_count,nextpnr_version\n100,2,ulx3s-85f,4,new\n')
            subprocess.run([sys.executable, str(SCRIPT_DIR / 'merge-sweep-history.py'),
                            '--output', str(merged), str(older), str(newer), str(current)], check=True)
            with merged.open(newline='') as handle:
                rows = list(csv.DictReader(handle))
            self.assertEqual([(row['run_id'], row['run_attempt']) for row in rows],
                             [('100', '1'), ('100', '2'), ('101', '1'), ('102', '1')])
            self.assertEqual(rows[0]['nextpnr_version'], 'old')

    def test_effective_clock_requirement(self):
        # Source the actual Bash helper; avoid inventory checks in this fixture.
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            helper = root / 'sweep-ecp5-common.sh'
            helper.write_bytes((SCRIPT_DIR / helper.name).read_bytes())
            inventory = root / 'inventory.sh'
            inventory.write_text('#!/bin/bash\nexit 0\n')
            inventory.chmod(0o755)
            for floor, requested, effective in (('40', '0', '40'),
                                                ('40', '35', '40'),
                                                ('40', '45.125', '45.125'),
                                                ('60.01', '60', '60.01')):
                with self.subTest(floor=floor, requested=requested):
                    result = subprocess.run([
                        'bash', '-c', 'source "$1"; effective="$(sweep_ecp5_effective_clock_requirement "$2" "$3")"; sweep_ecp5_write_clock_requirement test "$3" "$effective"',
                        'test', str(helper), floor, requested], check=True,
                        capture_output=True, text=True)
                    self.assertEqual(result.stdout.splitlines(), [
                        f'test_requested_mhz={requested}', f'test_required_mhz={effective}'])

    def test_invalid_metadata_and_result_rows(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            seeds = root / 'seeds'
            seeds.mkdir()
            metadata = root / 'metadata.txt'
            schema = ('result_columns=seed,clk_sys_mhz,clk_video_mhz,clk_tmds_mhz,'
                      'route_seconds,timing_status\n')
            requirements = ('clk_sys_required_mhz=25\nclk_video_required_mhz=25\n'
                            'clk_tmds_required_mhz=125\n')
            command = [sys.executable, str(SCRIPT_DIR / 'summarize-ecp5-sweep.py'),
                       '--target', 'ulx3s-85f', '--seed-first', '1', '--seed-last', '1',
                       '--seed-dir', str(seeds), '--metadata', str(metadata),
                       '--output-dir', str(root)]
            (seeds / 'exit-1.txt').write_text('0\n')
            result_file = seeds / 'result-seed-1.csv'
            result_file.write_text('1,30,40,200,100,PASS\n')
            for invalid in (requirements.replace('clk_tmds_required_mhz=125\n', ''),
                            requirements.replace('=125', '=0'),
                            requirements.replace('=125', '=NaN')):
                with self.subTest(metadata=invalid):
                    metadata.write_text(schema + invalid)
                    result = subprocess.run(command, capture_output=True, text=True)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn('Missing or invalid clock requirement', result.stderr)
            metadata.write_text(schema.replace('clk_tmds_mhz,', '') + requirements)
            result = subprocess.run(command, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Invalid result schema', result.stderr)
            metadata.write_text(schema + requirements)
            for invalid in ('2,30,40,200,100,PASS', '1,30,40,200,-1,PASS',
                            '1,30,40,200,0.5,PASS', '1,30,40,200,,PASS',
                            '1,30,40,0,100,PASS', '1,30,-40,200,100,PASS',
                            '1,24.99,40,200,100,PASS'):
                with self.subTest(row=invalid):
                    result_file.write_text(invalid + '\n')
                    result = subprocess.run(command, capture_output=True, text=True)
                    self.assertEqual(result.returncode, 1, result.stderr)
                    with (root / 'summary.csv').open(newline='') as handle:
                        row = next(csv.DictReader(handle))
                    self.assertEqual(row['timing_status'], 'ERROR')
                    self.assertEqual(row['all_timing_pass'], 'FAIL')

    def test_summary_all_board_schemas(self):
        profiles = {
            'ulx3s-12f': {'clk_sys': 40, 'clk_video': 50, 'clk_tmds': 250},
            'ulx3s-45f': {'clk_sys': 40, 'clk_video': 50, 'clk_tmds': 250},
            'ulx3s-85f': {'clk_sys': 25, 'clk_video': 25, 'clk_tmds': 125},
            'ulx4m-ld-85f': {'clk_sys': 40, 'litedram_user': 60.01, 'clk_video': 50,
                            'clk_tmds': 250, 'init_clk': 25},
            'ulx5m-gs': {'clk_sys': 12},
        }
        for board, requirements in profiles.items():
            with self.subTest(board=board), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                columns = ['seed', *(name + '_mhz' for name in requirements),
                           'route_seconds', 'timing_status']
                metadata = root / 'metadata.txt'
                metadata.write_text('result_columns=' + ','.join(columns) + '\n' +
                                    ''.join(f'{name}_required_mhz={value}\n'
                                            for name, value in requirements.items()))
                (root / 'exit-1.txt').write_text('0\n')
                (root / 'result-seed-1.csv').write_text(','.join([
                    '1', *(str(value + 1) for value in requirements.values()), '10', 'PASS']) + '\n')
                result = subprocess.run([
                    sys.executable, str(SCRIPT_DIR / 'summarize-ecp5-sweep.py'),
                    '--target', board, '--seed-first', '1', '--seed-last', '1',
                    '--seed-dir', str(root), '--metadata', str(metadata),
                    '--output-dir', str(root)], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                with (root / 'summary.csv').open(newline='') as handle:
                    self.assertEqual(next(csv.DictReader(handle))['all_timing_pass'], 'PASS')

    def test_summary_and_history(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            seeds = root / 'seeds'
            seeds.mkdir()
            metadata = root / 'metadata.txt'
            metadata.write_text(
                'result_columns=seed,clk_sys_mhz,clk_video_mhz,clk_tmds_mhz,route_seconds,timing_status\n'
                'clk_sys_required_mhz=25\nclk_video_required_mhz=25\nclk_tmds_required_mhz=125\n'
                'synthesis_seconds=31\nnetlist_sha256=test\n')
            config = root / 'configuration.txt'
            config.write_text('git_sha=test\nsynth_oss_cad_suite_version=2026-11-24\n')
            rows = {
                1: ('0', '1,30,40,200,100,PASS'),
                2: ('0', '2,20,50,220,120,FAIL'),
                3: ('1', '3,ERROR,ERROR,ERROR,15,ERROR'),
                4: ('124', '4,TIMEOUT,TIMEOUT,TIMEOUT,600,TIMEOUT'),
                5: ('0', '5,NaN,50,200,110,PASS'),
                6: ('0', None),
            }
            # Seed 7 is missing entirely. Malformed or absent reports with a
            # successful process exit must count as errors, not timing misses.
            for seed, (exit_code, row) in rows.items():
                (seeds / f'exit-{seed}.txt').write_text(exit_code + '\n')
                if row is not None:
                    (seeds / f'result-seed-{seed}.csv').write_text(row + '\n')
            env = dict(os.environ, GITHUB_RUN_ID='100', GITHUB_RUN_ATTEMPT='1')
            result = subprocess.run([
                sys.executable, str(SCRIPT_DIR / 'summarize-ecp5-sweep.py'),
                '--target', 'ulx3s-85f', '--seed-first', '1', '--seed-last', '7',
                '--seed-dir', str(seeds), '--metadata', str(metadata),
                '--configuration', str(config), '--output-dir', str(root),
            ], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 1, result.stderr)
            performance = root / 'toolchain-performance.csv'
            with performance.open(newline='') as handle:
                row = next(csv.DictReader(handle))
            expected = dict(seeds='7', completed='2', pass_count='1', timing_fail_count='1',
                            timeout_count='1', missing_count='1', tool_error_count='3',
                            clk_sys_min_mhz='20.00', clk_sys_median_mhz='25.00',
                            clk_sys_max_mhz='30.00', median_route_seconds='110.0')
            for key, value in expected.items():
                self.assertEqual(row[key], value, key)
            history = root / 'toolchain-history.csv'
            subprocess.run([sys.executable, str(SCRIPT_DIR / 'merge-sweep-history.py'),
                            '--output', str(history), str(performance), str(performance)], check=True)
            with history.open(newline='') as handle:
                self.assertEqual(len(list(csv.DictReader(handle))), 1)


if __name__ == '__main__':
    unittest.main(verbosity=2)
