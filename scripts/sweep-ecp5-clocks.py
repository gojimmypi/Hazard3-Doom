#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Resolve ECP5 sweep clocks from Yosys connectivity, then read routed timing.

Only the RTL PLL instance/port and oscillator input identify system/video
clocks. Wire names are aliases of Yosys bit IDs, not clock identifiers.
LiteDRAM uses its generated CLKDIVF and EHXPLLL output ports.
"""

import argparse
import json
import re
import sys
from pathlib import Path


BOARDS = ("ulx3s-12f", "ulx3s-45f", "ulx3s-85f", "ulx4m-ld-85f")
FMAX = re.compile(
    r"^Info:\s+Max frequency for clock\s+'([^']+)':\s+"
    r"([0-9]+(?:\.[0-9]+)?) MHz\s+\((PASS|FAIL) at "
    r"([0-9]+(?:\.[0-9]+)?) MHz\)\s*$"
)


def one(values, description):
    if len(values) != 1:
        raise ValueError(f"{description}: expected one, found {len(values)}")
    return values[0]


def bit(bits, description):
    value = one(bits, description)
    if type(value) is not int:
        raise ValueError(f"{description}: not a connected signal")
    return value


def discover(netlist, board, sys_mhz):
    top = one([
        module for module in netlist['modules'].values()
        if int(module.get('attributes', {}).get('top', '0'), 2)
    ], 'top module')
    nets = top['netnames']
    cells = top['cells']
    plls = {name: cell for name, cell in cells.items()
            if cell['type'] == 'EHXPLLL'}

    def cell_port(cell_type, pattern, port):
        name = one([name for name, cell in cells.items()
                    if cell['type'] == cell_type and re.fullmatch(pattern, name)],
                   f'{cell_type} matching {pattern}')
        return bit(cells[name]['connections'][port], f'{name}.{port}')

    def pll_port(pattern, port):
        return cell_port('EHXPLLL', pattern, port)

    if board == 'ulx4m-ld-85f':
        video_pll = r'pll_video_u\.pll_i'
        sys_pll = r'gen_pll_sys_(?:40|50)\.pll_sys_u\.pll_i'
        selected_sys_pll = rf'gen_pll_sys_{sys_mhz}\.pll_sys_u\.pll_i'
    else:
        video_pll = r'pll_video\.pll_i'
        sys_pll = r'(?:gen_clk_sys_(?:40|50)\.)?pll_sys\.pll_i'
        selected_sys_pll = r'pll_sys\.pll_i'
        if board == 'ulx3s-85f':
            selected_sys_pll = rf'(?:gen_clk_sys_{sys_mhz}\.)?pll_sys\.pll_i'

    if sys_mhz == 25:
        if board in ('ulx3s-12f', 'ulx3s-45f'):
            raise ValueError('compact ULX3S requires the 40 MHz system PLL')
        if any(re.fullmatch(sys_pll, name) for name in plls):
            raise ValueError('25 MHz profile unexpectedly contains a system PLL')
        system = bit(top['ports']['clk_osc']['bits'], 'oscillator input')
    else:
        if board in ('ulx3s-12f', 'ulx3s-45f') and sys_mhz != 40:
            raise ValueError('compact ULX3S requires 40 MHz')
        # Verify that the actual generate branch matches the profile.
        system = pll_port(selected_sys_pll, 'CLKOP')

    roles = {'sys': system}
    if board == 'ulx4m-ld-85f':
        # Both generated SERV and VexRiscv cores divide the DDR ECLK by
        # two; CDIVX is sys_clk, exported as the user Wishbone clock.
        roles['litedram_user'] = cell_port(
            'CLKDIVF', r'.*\.litedram_u\.litedram_u\.CLKDIVF', 'CDIVX')
    roles['video'] = pll_port(video_pll, 'CLKOS')
    roles['tmds'] = pll_port(video_pll, 'CLKOP')
    if board == 'ulx4m-ld-85f':
        # The generated LiteDRAM PLL's CLKOS feeds init_clk, not the
        # independent board oscillator or the HDMI PLL.
        roles['init'] = pll_port(r'.*\.litedram_u\.litedram_u\.EHXPLLL', 'CLKOS')
    if len(set(roles.values())) != len(roles):
        raise ValueError(f'required clock roles share a bit: {roles}')

    aliases = {}
    for role, signal in roles.items():
        names = sorted(name for name, net in nets.items()
                       if net['bits'] == [signal])
        if not names:
            raise ValueError(f'{role}: no scalar aliases for bit {signal}')
        aliases[role] = names
    return aliases


def routed_report(log, aliases):
    # Do not accidentally use the placement Fmax when the routed report is
    # absent. Both router implementations must emit the routing completion
    # marker; an unsupported log format must fail closed.
    marker = 'Info: Routing complete.'
    if marker not in log or 'Info: Program finished normally.' not in log:
        raise ValueError('missing routing completion or normal completion marker')
    final = log.rsplit(marker, 1)[1].split('Info: Program finished normally.', 1)[0]
    reports = {}
    for line in final.splitlines():
        if 'Max frequency for clock' not in line:
            continue
        match = FMAX.fullmatch(line)
        if not match:
            raise ValueError(f'unrecognized Fmax line: {line}')
        name, mhz, status, target = match.groups()
        if name in reports:
            raise ValueError(f'duplicate routed Fmax for {name}')
        reports[name] = (mhz, status, target)

    results = {}
    used = set()
    for role, names in aliases.items():
        # nextpnr may insert a global buffer and/or input IO buffer.
        # Match complete names literally, never by substring or regex.
        candidates = {prefix + name + suffix for name in names
                      for prefix in ('', '$glbnet$')
                      for suffix in ('', '$TRELLIS_IO_IN')}
        matches = sorted(candidates.intersection(reports))
        if len(matches) != 1:
            raise ValueError(f'{role}: expected one routed clock, found {matches}; '
                             f'netlist aliases={names}; reported={sorted(reports)}')
        name = matches[0]
        if name in used:
            raise ValueError(f'{role}: clock {name} already mapped to another role')
        used.add(name)
        mhz, status, target = reports[name]
        if float(target) <= 0:
            raise ValueError(f'{role}: nonpositive timing constraint')
        results[role] = (name, mhz, status)
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    mapping = sub.add_parser('discover')
    mapping.add_argument('netlist', type=Path)
    mapping.add_argument('board', choices=BOARDS)
    mapping.add_argument('sys_mhz', type=int, choices=(25, 40, 50))
    report = sub.add_parser('read')
    report.add_argument('mapping', help='JSON returned by discover')
    report.add_argument('log', type=Path)
    args = parser.parse_args()
    try:
        if args.command == 'discover':
            aliases = discover(json.loads(args.netlist.read_text()), args.board, args.sys_mhz)
            print(json.dumps(aliases, separators=(',', ':')))
        else:
            results = routed_report(args.log.read_text(errors='replace'), json.loads(args.mapping))
            for role, (name, mhz, status) in results.items():
                print(f'Clock {role}: {name} = {mhz} MHz ({status})', file=sys.stderr)
            # Fixed order is the role insertion order produced by discover.
            print(' '.join(mhz for _, mhz, _ in results.values()),
                  ' '.join(status for _, _, status in results.values()))
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f'ERROR: ECP5 clock discovery/report: {error}', file=sys.stderr)
        return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
