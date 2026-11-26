#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Regression tests for sweep-ecp5-clocks.py (no FPGA tools required).

Set SWEEP_CLOCK_TEST_ARTIFACT to the retained ULX3S 85F 25 MHz peek ZIP
from the 2026-11-24 toolchain sweep to also replay the 260 real routes.
"""

import importlib.util
import json
import os
import re
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


class ClockTests(unittest.TestCase):
    def test_old_and_arbitrary_aliases(self):
        for legacy in (False, True):
            netlist, system, pix, tmds = fixture(legacy=legacy)
            aliases = CLOCKS.discover(netlist, 'ulx3s-85f', 25)
            log = fmax(pix, '99.00') + routed([
                fmax(system + '$TRELLIS_IO_IN'), fmax(pix, '44.00'),
                fmax(tmds, '200.00', target='125.00'), fmax(pix + '_not_the_clock')])
            result = CLOCKS.routed_report(log, aliases)
            self.assertEqual(result['video'][1:], ('44.00', 'PASS'))
            self.assertEqual(result['sys'][0], '$glbnet$clk_osc$TRELLIS_IO_IN')

    def test_all_board_profiles(self):
        for board in CLOCKS.BOARDS:
            profiles = (40,) if board in ('ulx3s-12f', 'ulx3s-45f') else (25, 40, 50)
            for mhz in profiles:
                with self.subTest(board=board, mhz=mhz):
                    netlist, system, pix, tmds = fixture(board, mhz)
                    mapping = CLOCKS.discover(netlist, board, mhz)
                    rows = [fmax(system), fmax(pix), fmax(tmds)]
                    if board == 'ulx4m-ld-85f':
                        rows.extend([fmax('renamed.ddr_user'), fmax('renamed.ddr_init')])
                    self.assertTrue(all(x[2] == 'PASS' for x in CLOCKS.routed_report(routed(rows), mapping).values()))

    def test_failure_modes(self):
        netlist, system, pix, tmds = fixture()
        mapping = CLOCKS.discover(netlist, 'ulx3s-85f', 25)
        base = [fmax(system), fmax(pix), fmax(tmds)]
        for log in (''.join(base), routed(base).replace('Info: Program finished normally.', ''),
                    fmax(pix) + routed([base[0], base[2]]),
                    routed(base + [fmax('another.pixel.alias')]),
                    routed(base + [fmax(pix)]),
                    routed(base).replace('55.00 MHz', 'malformed MHz'),
                    routed(base).replace('at 25.00 MHz', 'at 0.00 MHz')):
            with self.subTest(log=log), self.assertRaises(ValueError):
                CLOCKS.routed_report(log, mapping)
        fail = routed([base[0], fmax(pix, '20.00', 'FAIL'), base[2]])
        self.assertEqual(CLOCKS.routed_report(fail, mapping)['video'][1:], ('20.00', 'FAIL'))

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
                result = CLOCKS.routed_report(archive.read(name).decode(), aliases)
                self.assertTrue(all(value[2] == 'PASS' for value in result.values()), name)
                if name == 'seeds/pnr-72.log':
                    self.assertEqual([x[1] for x in result.values()], ['34.28', '49.62', '253.23'])
                count += 1
            self.assertEqual(count, 260)


if __name__ == '__main__':
    unittest.main(verbosity=2)
