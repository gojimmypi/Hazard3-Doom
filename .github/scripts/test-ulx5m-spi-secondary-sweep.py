#!/usr/bin/env python3
"""Offline tests for v47 SPI-primary seed-sweep wiring and bitstream packing."""

from pathlib import Path
import os
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / '.github/workflows/ulx5m-bootloader-seed-sweep.yml'
SCRIPT = ROOT / 'scripts/sweep-ulx5m-spi-secondary.sh'
INSPECTOR = ROOT / 'bootloader-serv/tests/inspect-ulx5m-v47-primary.py'


class SweepTests(unittest.TestCase):
    def test_workflow_synthesizes_v47_not_legacy(self):
        src = WORKFLOW.read_text(encoding='ascii')
        self.assertIn('          - spi-secondary\n', src)
        self.assertIn('design=normal-boot-dfu-hw-native/spi-secondary', src)
        self.assertIn('makefile=Makefile.ulx5m-spi-secondary', src)
        self.assertIn('bash scripts/sweep-ulx5m-spi-secondary.sh', src)
        self.assertIn('gmpack_bootaddr=0x201000', src)
        self.assertIn('SWEEP_SKIP_SYNTH=1', src)
        self.assertIn('sha256sum --check SHA256SUMS', src)
        self.assertIn('upload-artifact', src)

    def test_reference_packaging_is_pinned(self):
        src = SCRIPT.read_text(encoding='ascii')
        self.assertIn('gmpack --bootaddr 2101248', src)
        self.assertIn('inspect-ulx5m-v47-primary.py', src)
        self.assertIn("Max frequency for clock 'bram_i.clk':", src)
        self.assertIn('SWEEP_ALLOW_NO_PASS', src)
        self.assertIn('SWEEP_SKIP_SYNTH', src)

    def run_mock(self, bad_pack=False, seeds=('1', '3')):
        with tempfile.TemporaryDirectory(prefix='ulx5m-v47-sweep-') as t:
            tmp = Path(t)
            tools = tmp / 'tools'
            tools.mkdir()
            pnr = tools / 'nextpnr-himbaechel'
            pnr.write_text('''#!/usr/bin/env python3
import sys
from pathlib import Path
args = sys.argv[1:]
if '--version' in args:
    print('mock nextpnr 0.10-95')
    sys.exit(0)
seed = int(args[args.index('--seed') + 1])
out = Path(next(x[4:] for x in args if x.startswith('out=')))
log = Path(args[args.index('-l') + 1])
# Both placement and post-route lines: use LAST, not FIRST.
if seed == 1:
    freq, verdict, rc = '38.57', 'FAIL', 1
elif seed == 2:
    freq, verdict, rc = '49.51', 'PASS', 0
else:
    freq, verdict, rc = '50.12', 'PASS', 0
log.write_text("Max frequency for clock 'bram_i.clk': 55.00 MHz (PASS at 48.00 MHz)\\n" +
               "Routing complete.\\nMax frequency for clock 'bram_i.clk': " +
               freq + " MHz (" + verdict + " at 48.00 MHz)\\n", encoding='ascii')
if rc == 0:
    out.write_text('routed seed ' + str(seed), encoding='ascii')
sys.exit(rc)
''', encoding='ascii')
            gmpack = tools / 'gmpack'
            trailer = 'c3010cfe00ccc6da0428eb0010200029510000'
            gmpack.write_text('''#!/usr/bin/env python3
import sys
from pathlib import Path
args=sys.argv[1:]
if '--version' in args:
    print('mock gmpack')
    sys.exit(0)
if len(args) != 4 or args[:2] != ['--bootaddr', '2101248']:
    sys.exit(3)
raw = b'mock config body' + bytes.fromhex("''' +
                ('000000' if bad_pack else trailer) + '''")
Path(args[3]).write_bytes(raw)
''', encoding='ascii')
            for file in (pnr, gmpack):
                file.chmod(0o755)
            for file in ('netlist.json', 'constraints.ccf', 'constraints.sdc'):
                (tmp / file).write_text(file + '\n', encoding='ascii')
            result_dir = tmp / 'results'
            env = dict(os.environ, PATH=str(tools) + os.pathsep + os.environ['PATH'],
                       SWEEP_SKIP_SYNTH='1', SWEEP_ALLOW_NO_PASS='1',
                       SWEEP_JSON=str(tmp / 'netlist.json'),
                       SWEEP_CCF=str(tmp / 'constraints.ccf'),
                       SWEEP_SDC=str(tmp / 'constraints.sdc'),
                       SWEEP_OUTPUT_DIR=str(result_dir))
            result = subprocess.run(['bash', str(SCRIPT), *seeds, '30'], env=env,
                                    capture_output=True, text=True, timeout=15, check=False)
            rows = (result_dir / 'results.tsv').read_text(encoding='ascii').splitlines()
            return result, rows, sorted(p.name for p in result_dir.iterdir()), result_dir.joinpath('summary.md').read_text(encoding='ascii')

    def test_mock_route_and_best_pack(self):
        result, rows, files, summary = self.run_mock()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual([x.split('\t')[1] for x in rows[1:]], ['FAIL', 'PASS', 'PASS'])
        self.assertEqual(rows[1].split('\t')[2], '38.57')
        self.assertIn('best-seed-3.bit', files)
        self.assertNotIn('seed-2.bit', files)
        self.assertIn('2 PASS', summary)
        self.assertIn('50.12 MHz', summary)

    def test_pack_validation_failure_is_not_pass(self):
        result, rows, files, _ = self.run_mock(bad_pack=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual([x.split('\t')[1] for x in rows[1:]], ['FAIL', 'ERROR', 'ERROR'])
        self.assertFalse(any(name.endswith('.bit') for name in files))

    def test_no_pass_does_not_hide_timing_failure(self):
        result, rows, files, summary = self.run_mock(seeds=('1', '1'))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(rows[1].split('\t')[1], 'FAIL')
        self.assertIn('0 PASS', summary)
        self.assertFalse(any(name.endswith('.bit') for name in files))


if __name__ == '__main__':
    unittest.main(verbosity=2)
