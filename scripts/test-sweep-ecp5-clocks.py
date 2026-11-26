#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Regression tests for sweep-ecp5-clocks.py (no FPGA tools required).

Set SWEEP_CLOCK_TEST_ARTIFACT to the retained ULX3S 85F 25 MHz peek ZIP
from the 2026-11-24 toolchain sweep to also replay the 260 real routes.
"""

import importlib.util
from decimal import Decimal
import json
import os
import re
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path


SPEC = importlib.util.spec_from_file_location(
    'sweep_ecp5_clocks', Path(__file__).with_name('sweep-ecp5-clocks.py'))
CLOCKS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CLOCKS)


def fixture(board='ulx3s-85f', sys_mhz=25, legacy=False):
    """Small synthetic flattened Yosys JSON with the board's RTL topology."""
    ulx4m = board == 'ulx4m-ld-85f'
    video_pll = 'pll_video_u.pll_i' if ulx4m else 'pll_video.pll_i'
    cells = {video_pll: {'type': 'EHXPLLL', 'connections': {
        'CLKOS': [98], 'CLKOP': [3199]}}}
    system = 2 if sys_mhz == 25 else 42
    if sys_mhz != 25:
        if ulx4m:
            name = f'gen_pll_sys_{sys_mhz}.pll_sys_u.pll_i'
        elif board == 'ulx3s-85f':
            name = f'gen_clk_sys_{sys_mhz}.pll_sys.pll_i'
        else:
            name = 'pll_sys.pll_i'
        cells[name] = {'type': 'EHXPLLL', 'connections': {'CLKOP': [system]}}
    pix = 'clk_video_pix' if legacy else 'renamed.pixel[2]'
    tmds = 'clk_tmds_x5' if legacy else 'renamed.tmds'
    sys = 'clk_osc' if sys_mhz == 25 else 'renamed.system'
    names = {sys: system, pix: 98, tmds: 3199, 'clk_osc': 2,
             'another.pixel.alias': 98, pix + '_not_the_clock': 100}
    if ulx4m:
        prefix = 'soc_u.litedram_target.litedram_u.litedram_u.'
        cells[prefix + 'CLKDIVF'] = {'type': 'CLKDIVF', 'connections': {'CDIVX': [61]}}
        cells[prefix + 'EHXPLLL'] = {'type': 'EHXPLLL', 'connections': {'CLKOS': [62]}}
        names.update({'renamed.ddr_user': 61, 'renamed.ddr_init': 62})
    netlist = {'modules': {'top': {'attributes': {'top': '1'}, 'cells': cells,
                                 'ports': {'clk_osc': {'bits': [2]}},
                                 'netnames': {k: {'bits': [v]} for k, v in names.items()}}}}
    return netlist, sys, pix, tmds


def fmax(name, achieved='55.00', status='PASS', target='25.00'):
    return f"Info: Max frequency for clock '$glbnet${name}': {achieved} MHz ({status} at {target} MHz)\n"


def routed(lines):
    return 'Info: Routing complete.\n' + ''.join(lines) + 'Info: Program finished normally.\n'


# Independent reference frequencies: do not derive test expectations from
# the implementation under test. LiteDRAM's nominal constraint is 60 MHz.
PROFILES = {
    ('ulx3s-12f', 40): (40, 50, 250),
    ('ulx3s-45f', 40): (40, 50, 250),
    ('ulx3s-85f', 25): (25, 25, 125),
    ('ulx3s-85f', 40): (40, 25, 125),
    ('ulx3s-85f', 50): (50, 25, 125),
    ('ulx4m-ld-85f', 25): (25, 50, 250),
    ('ulx4m-ld-85f', 40): (40, 50, 250),
    ('ulx4m-ld-85f', 50): (50, 50, 250),
}


def expected_constraints(board, mhz):
    system, video, tmds = PROFILES[(board, mhz)]
    expected = {'sys': system, 'video': video, 'tmds': tmds}
    if board == 'ulx4m-ld-85f':
        expected.update(litedram_user=60, init=25)
    return expected


class ClockTests(unittest.TestCase):
    def test_physical_constraints(self):
        self.assertEqual(set(CLOCKS.BOARDS), {board for board, _ in PROFILES})
        for board, mhz in PROFILES:
            with self.subTest(board=board, mhz=mhz):
                self.assertEqual(CLOCKS.physical_constraints(board, mhz),
                                 expected_constraints(board, mhz))
        for board, mhz in [('ulx3s-12f', 25), ('ulx3s-45f', 50),
                           ('ulx3s-85f', 30), ('ulx4m-ld-85f', 75),
                           ('ulx5m-gs', 25), ('unknown', 40)]:
            with self.subTest(board=board, mhz=mhz), self.assertRaises(ValueError):
                CLOCKS.physical_constraints(board, mhz)

    def test_minimum_fmax_and_shell_profile(self):
        # Run the real Bash profile initialization and metadata writer. The
        # expected values are independent of both the CLI and the Python API.
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ('sweep-ecp5-common.sh', 'sweep-ecp5-clocks.py'):
                (root / name).write_bytes(Path(__file__).with_name(name).read_bytes())
            inventory = root / 'inventory.sh'
            inventory.write_text('#!/bin/bash\nexit 0\n')
            inventory.chmod(0o755)
            env = {key: value for key, value in os.environ.items()
                   if not key.startswith(('SWEEP_', 'HAZARD3_'))}
            columns = {'sys': 'clk_sys', 'video': 'clk_video', 'tmds': 'clk_tmds',
                       'litedram_user': 'litedram_user', 'init': 'init_clk'}
            overrides = {'sys': 'SWEEP_SYS_TARGET_MHZ', 'video': 'SWEEP_VIDEO_TARGET_MHZ',
                         'tmds': 'SWEEP_TMDS_TARGET_MHZ', 'litedram_user': 'SWEEP_LITEDRAM_TARGET_MHZ',
                         'init': 'SWEEP_INIT_TARGET_MHZ'}
            for board, mhz in PROFILES:
                nominal = expected_constraints(board, mhz)
                floors = {role: Decimal(value) for role, value in nominal.items()}
                if board == 'ulx4m-ld-85f':
                    floors['litedram_user'] = Decimal('60.01')
                self.assertEqual(CLOCKS.minimum_fmax(board, mhz), floors)
                for delta in (None, Decimal('-1'), Decimal('5.125')):
                    with self.subTest(board=board, mhz=mhz, delta=delta):
                        config = dict(env, SWEEP_ECP5_BOARD_ID=board,
                                      HAZARD3_ULX3S_85F_SYS_CLK_MHZ=str(mhz),
                                      HAZARD3_ULX4M_SYS_CLK_MHZ=str(mhz))
                        if delta is not None:
                            config.update({overrides[role]: str(floors[role] + delta)
                                           for role in floors})
                        result = subprocess.run([
                            'bash', '-eu', '-o', 'pipefail', '-c',
                            'source "$1"; sweep_ecp5_clock_targets; sweep_ecp5_write_clock_requirements',
                            'test', str(root / 'sweep-ecp5-common.sh')],
                            env=config, text=True, capture_output=True, check=True)
                        metadata = dict(line.split('=', 1) for line in result.stdout.splitlines())
                        expected = {}
                        for role, floor in floors.items():
                            requested = floor if delta is None else floor + delta
                            prefix = columns[role]
                            expected[f'{prefix}_requested_mhz'] = requested
                            expected[f'{prefix}_required_mhz'] = max(floor, requested)
                        self.assertEqual({key: Decimal(value) for key, value in metadata.items()}, expected)

    def test_old_and_arbitrary_aliases(self):
        for legacy in (False, True):
            netlist, system, pix, tmds = fixture(legacy=legacy)
            aliases = CLOCKS.discover(netlist, 'ulx3s-85f', 25)
            log = fmax(pix, '99.00') + routed([
                fmax(system + '$TRELLIS_IO_IN'), fmax(pix, '44.00'),
                fmax(tmds, '200.00', target='125.00'), fmax(pix + '_not_the_clock')])
            result = CLOCKS.routed_report(log, aliases, CLOCKS.physical_constraints('ulx3s-85f', 25))
            self.assertEqual(result['video'][1:], ('44.00', 'PASS', '25.00'))
            self.assertEqual(result['sys'][0], '$glbnet$clk_osc$TRELLIS_IO_IN')

    def test_all_board_profiles(self):
        for board in CLOCKS.BOARDS:
            profiles = (40,) if board in ('ulx3s-12f', 'ulx3s-45f') else (25, 40, 50)
            for mhz in profiles:
                with self.subTest(board=board, mhz=mhz):
                    netlist, system, pix, tmds = fixture(board, mhz)
                    mapping = CLOCKS.discover(netlist, board, mhz)
                    expected = expected_constraints(board, mhz)
                    rows = [fmax(system, target=str(mhz)),
                            fmax(pix, target=str(expected['video'])),
                            fmax(tmds, '300.00', target=str(expected['tmds']))]
                    if board == 'ulx4m-ld-85f':
                        rows.extend([fmax('renamed.ddr_user', '65.00', target='60.01'),
                                     fmax('renamed.ddr_init')])
                    self.assertTrue(all(x[2] == 'PASS' for x in CLOCKS.routed_report(routed(rows), mapping, expected).values()))

    def test_failure_modes(self):
        netlist, system, pix, tmds = fixture()
        mapping = CLOCKS.discover(netlist, 'ulx3s-85f', 25)
        expected = CLOCKS.physical_constraints('ulx3s-85f', 25)
        base = [fmax(system), fmax(pix), fmax(tmds, '200.00', target='125.00')]
        for log in (''.join(base), routed(base).replace('Info: Program finished normally.', ''),
                    'Info: Program finished normally.\n' + routed(base).replace('Info: Program finished normally.', ''),
                    fmax(pix) + routed([base[0], base[2]]),
                    routed(base + [fmax('another.pixel.alias')]),
                    routed(base + [fmax(pix)]),
                    routed(base).replace('55.00 MHz', 'malformed MHz'),
                    routed(base).replace('at 25.00 MHz', 'at 0.00 MHz'),
                    routed(base).replace('at 125.00 MHz', 'at 25.00 MHz'),
                    routed(base).replace('at 25.00 MHz', 'at 24.98 MHz')):
            with self.subTest(log=log), self.assertRaises(ValueError):
                CLOCKS.routed_report(log, mapping, expected)
        # nextpnr can emit Warning rather than Info for a completed timing miss.
        for prefix in ('Info', 'Warning'):
            with self.subTest(prefix=prefix):
                failed_clock = fmax(pix, '20.00', 'FAIL').replace('Info:', prefix + ':')
                fail = routed([base[0], failed_clock, base[2]])
                self.assertEqual(CLOCKS.routed_report(fail, mapping, expected)['video'][1:],
                                 ('20.00', 'FAIL', '25.00'))
        # An unrelated failed clock must not prevent required clock discovery.
        unrelated = fmax('unrelated', '10.00', 'FAIL').replace('Info:', 'Warning:')
        result = CLOCKS.routed_report(routed(base + [unrelated]), mapping, expected)
        self.assertTrue(all(value[2] == 'PASS' for value in result.values()))

    def test_missing_pll_and_shared_bits(self):
        netlist, *_ = fixture()
        del netlist['modules']['top']['cells']['pll_video.pll_i']
        with self.assertRaises(ValueError):
            CLOCKS.discover(netlist, 'ulx3s-85f', 25)
        netlist, *_ = fixture()
        netlist['modules']['top']['cells']['pll_video.pll_i']['connections']['CLKOS'] = [2]
        with self.assertRaises(ValueError):
            CLOCKS.discover(netlist, 'ulx3s-85f', 25)
        netlist, *_ = fixture(sys_mhz=40)
        with self.assertRaises(ValueError):
            CLOCKS.discover(netlist, 'ulx3s-85f', 50)

    @unittest.skipUnless(os.environ.get('SWEEP_CLOCK_TEST_ARTIFACT'), 'optional retained artifact not supplied')
    def test_actual_260_seed_sweep(self):
        with zipfile.ZipFile(os.environ['SWEEP_CLOCK_TEST_ARTIFACT']) as archive:
            netlist = json.loads(archive.read('frozen/build/fpga_ulx3s_85f.json'))
            aliases = CLOCKS.discover(netlist, 'ulx3s-85f', 25)
            count = 0
            for name in archive.namelist():
                if not re.fullmatch(r'seeds/pnr-\d+\.log', name):
                    continue
                result = CLOCKS.routed_report(archive.read(name).decode(), aliases,
                                              CLOCKS.physical_constraints('ulx3s-85f', 25))
                self.assertTrue(all(value[2] == 'PASS' for value in result.values()), name)
                if name == 'seeds/pnr-72.log':
                    self.assertEqual([x[1] for x in result.values()], ['34.28', '49.62', '253.23'])
                count += 1
            self.assertEqual(count, 260)


if __name__ == '__main__':
    unittest.main(verbosity=2)
