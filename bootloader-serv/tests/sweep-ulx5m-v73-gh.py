#!/usr/bin/env python3
"""GitHub parallel v73 GateMate 48MHz seed-sweep controller (no hardware writes)."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

TIMING = re.compile(r"Max frequency for clock 'bram_i\.clk':\s*([0-9.]+) MHz \((PASS|FAIL) at ([0-9.]+) MHz\)")
REQUIRED = 48.0


def checksum(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def routed_result(log):
    """Return post-route Fmax and status, or None for incomplete results."""
    if 'Routing complete.' not in log or 'Program finished normally.' not in log:
        return None
    matches = TIMING.findall(log.rsplit('Routing complete.', 1)[-1])
    if not matches:
        return None
    fmax, timing_status, constraint = matches[-1]
    return float(fmax), timing_status, float(constraint)


def matrix(first, last, per):
    if not 1 <= first <= last <= 2147483647 or not 1 <= per <= 20:
        raise ValueError('invalid seed range/group size')
    groups = [{'group': '%d-%d' % (a, min(last, a + per - 1)),
               'first': a, 'last': min(last, a + per - 1)}
              for a in range(first, last + 1, per)]
    if len(groups) > 256:
        raise ValueError('too many matrix jobs (maximum 256); increase seeds_per_job')
    return groups


def route(args):
    for path in (args.netlist, args.ccf, args.sdc):
        if not path.is_file() or not path.stat().st_size:
            raise ValueError('missing frozen routing input: ' + str(path))
    args.output.mkdir(parents=True, exist_ok=True)
    results = []
    for seed in range(args.first, args.last + 1):
        log = args.output / ('pnr-seed-%d.log' % seed)
        impl = args.output / ('route-seed-%d.txt' % seed)
        command = [args.nextpnr, '--device', 'CCGM1A1', '--json', str(args.netlist),
                   '-o', 'ccf=' + str(args.ccf), '-o', 'out=' + str(impl),
                   '--sdc', str(args.sdc), '--router', 'router2',
                   '--placer-heap-beta=0.6', '--seed', str(seed), '-l', str(log)]
        status = 'INCOMPLETE'
        rc = None
        try:
            proc = subprocess.run(command, capture_output=True, text=True,
                                  timeout=args.timeout, check=False)
            rc = proc.returncode
            (args.output / ('console-seed-%d.log' % seed)).write_text(
                proc.stdout + proc.stderr, encoding='utf-8')
        except subprocess.TimeoutExpired:
            status = 'TIMEOUT'
            rc = 124
        details = routed_result(log.read_text(encoding='utf-8', errors='replace')) if log.is_file() else None
        fmax = None if details is None else details[0]
        if details is not None:
            status = 'PASS' if (details[1] == 'PASS' and details[2] == REQUIRED
                                and fmax >= REQUIRED and rc == 0
                                and impl.is_file() and impl.stat().st_size > 0) else 'FAIL'
        results.append({'seed': seed, 'status': status,
                        'fmax_mhz': '' if fmax is None else '%.2f' % fmax,
                        'exit_code': '' if rc is None else rc})
        print('seed=%d status=%s routed_fmax=%s' % (seed, status, results[-1]['fmax_mhz']), flush=True)
        # The routed .txt is huge, and no candidate may be used without a local
        # re-build and packed-image fixed-point qualification. Keep logs only.
        if impl.is_file():
            impl.unlink()
    with (args.output / 'results.csv').open('w', encoding='ascii', newline='') as fp:
        writer = csv.DictWriter(fp, fieldnames=['seed', 'status', 'fmax_mhz', 'exit_code'])
        writer.writeheader()
        writer.writerows(results)
    winners = sorted((r for r in results if r['status'] == 'PASS'),
                     key=lambda row: (-float(row['fmax_mhz']), row['seed']))
    (args.output / 'summary.md').write_text(
        '# v73 seed group %d-%d\n\n' % (args.first, args.last) +
        '%d / %d seeds meet 48 MHz after routing.\n\n' % (len(winners), len(results)) +
        '\n'.join('- seed %s: %s MHz' % (r['seed'], r['fmax_mhz']) for r in winners[:10]) + '\n',
        encoding='ascii')


def summarize(args):
    groups = list(args.groups.glob('*/results.csv'))
    rows = {}
    for group in groups:
        with group.open(encoding='ascii', newline='') as fp:
            for row in csv.DictReader(fp):
                seed = int(row['seed'])
                if seed in rows:
                    raise ValueError('duplicate seed %d' % seed)
                rows[seed] = row
    required_seeds = set(range(args.first, args.last + 1))
    if set(rows) != required_seeds:
        missing = sorted(required_seeds - set(rows))
        unexpected = sorted(set(rows) - required_seeds)
        raise ValueError('incomplete seed coverage; missing=%s unexpected=%s' %
                         (missing[:20], unexpected[:20]))
    passing = [r for r in rows.values() if r['status'] == 'PASS' and
               r['fmax_mhz'] and float(r['fmax_mhz']) >= REQUIRED]
    passing.sort(key=lambda r: (-float(r['fmax_mhz']), int(r['seed'])))
    args.output.mkdir(parents=True, exist_ok=True)
    with (args.output / 'ranking.csv').open('w', encoding='ascii', newline='') as fp:
        writer = csv.DictWriter(fp, fieldnames=['seed', 'status', 'fmax_mhz', 'exit_code'])
        writer.writeheader()
        writer.writerows(passing)
    lines = ['# v73 integrated SERV 48 MHz seed sweep', '',
             'Complete: %d / %d seeds; passing: %d' % (len(rows), len(required_seeds), len(passing)),
             '', 'Timing search only. No bitstreams produced or hardware programmed.',
             'Local v73-build must regenerate the packed command ROM and pass v73-qualify.', '']
    lines += ['- Seed %s: %s MHz' % (r['seed'], r['fmax_mhz']) for r in passing[:20]]
    if not passing:
        lines += ['No timing-pass seed found. Investigate usb_trans.v microcode ROM feedback path.']
    (args.output / 'summary.md').write_text('\n'.join(lines) + '\n', encoding='ascii')
    print('\n'.join(lines))
    return 0 if passing else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest='mode', required=True)
    m = sub.add_parser('matrix')
    m.add_argument('--first', type=int, required=True)
    m.add_argument('--last', type=int, required=True)
    m.add_argument('--per', type=int, required=True)
    r = sub.add_parser('route')
    r.add_argument('--first', type=int, required=True)
    r.add_argument('--last', type=int, required=True)
    r.add_argument('--netlist', type=Path, required=True)
    r.add_argument('--ccf', type=Path, required=True)
    r.add_argument('--sdc', type=Path, required=True)
    r.add_argument('--output', type=Path, required=True)
    r.add_argument('--timeout', type=int, default=540)
    r.add_argument('--nextpnr', default='nextpnr-himbaechel')
    s = sub.add_parser('summarize')
    s.add_argument('--first', type=int, required=True)
    s.add_argument('--last', type=int, required=True)
    s.add_argument('--groups', type=Path, required=True)
    s.add_argument('--output', type=Path, required=True)
    args = ap.parse_args()
    try:
        if args.mode == 'matrix':
            print(json.dumps({'include': matrix(args.first, args.last, args.per)}, separators=(',', ':')))
            return 0
        if args.mode == 'route':
            if args.first > args.last or args.first < 1 or args.timeout < 10:
                raise ValueError('bad routing inputs')
            route(args)
            return 0
        return summarize(args)
    except (OSError, ValueError) as exc:
        print('[FAIL] ' + str(exc), file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
