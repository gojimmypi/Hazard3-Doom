#!/usr/bin/env python3
"""Offline tests for the isolated v73 local timing sweep and fail-closed gates."""

import importlib.util
from pathlib import Path
import tempfile
import types
import unittest
from unittest import mock

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
SPEC = importlib.util.spec_from_file_location('v73_sweep', HERE / 'sweep-ulx5m-v73-local.py')
SWEEP = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SWEEP)


def timing(fmax, state, routed=True, finished=True, early=None):
    lines = []
    if early is not None:
        lines.append("Max frequency for clock 'bram_i.clk': %.2f MHz (FAIL at 48.00 MHz)" % early)
    if routed:
        lines.append('Routing complete.')
    lines.append("%sMax frequency for clock 'bram_i.clk': %.2f MHz (%s at 48.00 MHz)" %
                 ('ERROR: ' if state == 'FAIL' else '', fmax, state))
    if finished:
        lines.append('Program finished normally.')
    return '\n'.join(lines) + '\n'


class SweepTests(unittest.TestCase):
    def test_early_placement_estimate_is_not_routed_fmax(self):
        result = SWEEP.parse_routed_timing(timing(49.13, 'PASS', early=31.66))
        self.assertEqual(result, (49.13, 'PASS', 48.0))
        self.assertIsNone(SWEEP.parse_routed_timing(timing(55.0, 'PASS', routed=False)))
        self.assertIsNone(SWEEP.parse_routed_timing(timing(55.0, 'PASS', finished=False)))

    def test_actual_user_failure_is_rejected(self):
        sample = timing(40.87, 'FAIL', early=31.66)
        self.assertEqual(SWEEP.parse_routed_timing(sample), (40.87, 'FAIL', 48.0))

    def test_new_sweep_makefile_is_offline_and_uses_exact_v73_inputs(self):
        make = (ROOT / 'Makefile.ulx5m-v73-sweep').read_text(encoding='ascii')
        self.assertIn('include Makefile.ulx5m-v73-integrated', make)
        self.assertIn('$(V73_JSON)', make)
        self.assertIn('$(V73_SOURCE)', make)
        self.assertIn('$(FLASH_CCF)', make)
        self.assertIn('$(FLASH_SDC)', make)
        self.assertIn('--beta 0.6 --mhz 48.0', make)
        self.assertNotIn('openFPGALoader', make)
        self.assertNotIn('dfu-util', make)
        self.assertNotIn('gmpack ', make)

    def test_fake_nextpnr_seed_sweep_and_winner(self):
        with tempfile.TemporaryDirectory(prefix='v73-sweep-mock-') as d:
            root = Path(d)
            tools = root / 'tools'
            tools.mkdir()
            fake = tools / 'nextpnr-himbaechel'
            fake.write_text('''#!/usr/bin/env python3
import sys
from pathlib import Path
args=sys.argv
seed=int(args[args.index('--seed')+1])
log=Path(args[args.index('-l')+1])
impl=Path(next(a.split('=',1)[1] for a in args if a.startswith('out=')))
fmax={10:40.87,11:50.12,12:47.99}[seed]
state='PASS' if fmax>=48 else 'FAIL'
log.write_text("Max frequency for clock 'bram_i.clk': 31.66 MHz (FAIL at 48.00 MHz)\\nRouting complete.\\nMax frequency for clock 'bram_i.clk': %.2f MHz (%s at 48.00 MHz)\\nProgram finished normally.\\n"%(fmax,state),encoding='ascii')
if state=='PASS':impl.write_text('fake route implementation\\n',encoding='ascii')
sys.exit(0 if state=='PASS' else 1)
''', encoding='ascii')
            fake.chmod(0o755)
            for name in ('netlist.json', 'constraints.ccf', 'constraints.sdc', 'source.sha256'):
                (root / name).write_text('fake but pinned\n', encoding='ascii')
            args = types.SimpleNamespace(netlist=root / 'netlist.json',
                                         ccf=root / 'constraints.ccf', sdc=root / 'constraints.sdc',
                                         source_sha=root / 'source.sha256',
                                         first=10, last=12, jobs=2, beta=0.6, mhz=48.0,
                                         timeout=30, output=root / 'results')
            with mock.patch.object(SWEEP, 'check_tools', return_value=str(fake)), \
                 mock.patch.object(SWEEP, 'verify_source', return_value=None):
                self.assertEqual(SWEEP.run(args), 0)
            result = (root / 'results/results.tsv').read_text(encoding='ascii')
            self.assertIn('10\tFAIL\t40.87', result)
            self.assertIn('11\tPASS\t50.12', result)
            self.assertIn('12\tFAIL\t47.99', result)
            summary = (root / 'results/summary.md').read_text(encoding='ascii')
            self.assertIn('Best timing candidate: seed 11', summary)
            self.assertIn('V73_SEED=11 v73-build', summary)
            self.assertTrue((root / 'results/frozen/SHA256SUMS').is_file())
            self.assertFalse((root / 'results/route-seed10.txt').is_file())

    def test_reject_nonreproducible_beta_and_clock(self):
        with tempfile.TemporaryDirectory() as d:
            a = types.SimpleNamespace(first=1, last=2, jobs=2, beta=0.7, mhz=48.0,
                                      timeout=600, netlist=Path(d)/'bad')
            with self.assertRaisesRegex(ValueError, 'HeAP beta'):
                SWEEP.run(a)
            a.beta, a.mhz = 0.6, 40.0
            with self.assertRaisesRegex(ValueError, '48.00 MHz'):
                SWEEP.run(a)

    def test_source_drift_and_missing_snapshot_block(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            args = types.SimpleNamespace(first=1, last=1, jobs=1, beta=0.6,
                                         mhz=48.0, timeout=600, netlist=root/'missing.json',
                                         ccf=root/'missing.ccf', sdc=root/'missing.sdc',
                                         source_sha=root/'missing.sha', output=root/'out')
            with self.assertRaisesRegex(ValueError, 'missing/empty frozen input'):
                SWEEP.run(args)


if __name__ == '__main__':
    unittest.main(verbosity=2)
