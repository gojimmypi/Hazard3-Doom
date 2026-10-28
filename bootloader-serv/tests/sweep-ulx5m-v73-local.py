#!/usr/bin/env python3
"""Offline, reproducible local placement sweep for the frozen v73 SERV netlist.

This tool runs nextpnr only. It never invokes gmpack, JTAG or a flash writer.
A timing winner is guidance, not a qualified v73 packed primary.
"""

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
CLOCK = 'bram_i.clk'
FREQ_RE = re.compile(r"(?:ERROR:\s*)?Max frequency for clock 'bram_i\.clk':\s*([0-9.]+) MHz \((PASS|FAIL) at ([0-9.]+) MHz\)")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify_source(source_sha):
    spec = importlib.util.spec_from_file_location('v73_qualifier', HERE / 'qualify-ulx5m-v73-integrated.py')
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    mod.verify_source(source_sha)


def check_tools():
    checker = ROOT.parent / 'scripts/check-ulx5m-oss-cad-suite.sh'
    if not checker.is_file():
        raise RuntimeError('missing pinned toolchain checker: ' + str(checker))
    result = subprocess.run(['bash', str(checker)], cwd=ROOT, capture_output=True,
                            text=True, check=False)
    if result.returncode:
        raise RuntimeError('pinned toolchain check failed:\n' + result.stdout + result.stderr)
    exe = shutil.which('nextpnr-himbaechel')
    if not exe:
        raise RuntimeError('nextpnr-himbaechel is not on PATH')
    print(result.stdout.strip())
    return exe


def parse_routed_timing(log):
    """Ignore placer estimates: only the final report after completed routing counts."""
    if 'Routing complete.' not in log or 'Program finished normally.' not in log:
        return None
    after_route = log.rsplit('Routing complete.', 1)[-1]
    matches = FREQ_RE.findall(after_route)
    if not matches:
        return None
    value, status, required = matches[-1]
    return float(value), status, float(required)


def route_one(exe, netlist, ccf, sdc, output, seed, beta, timeout, mhz):
    route_log = output / ('pnr-seed%d.log' % seed)
    impl = output / ('route-seed%d.txt' % seed)
    console = output / ('console-seed%d.log' % seed)
    command = [exe, '--device', 'CCGM1A1', '--json', str(netlist),
               '-o', 'ccf=' + str(ccf), '-o', 'out=' + str(impl),
               '--sdc', str(sdc), '--router', 'router2',
               '--placer-heap-beta=' + str(beta), '--seed', str(seed),
               '-l', str(route_log)]
    exit_code = None
    problem = ''
    try:
        result = subprocess.run(command, cwd=ROOT, capture_output=True,
                                text=True, check=False, timeout=timeout)
        exit_code = result.returncode
        console.write_text(result.stdout + result.stderr, encoding='utf-8')
    except subprocess.TimeoutExpired as exc:
        exit_code = 124
        problem = 'TIMEOUT'
        text = (exc.stdout or b'') + (exc.stderr or b'')
        if isinstance(text, bytes):
            text = text.decode('utf-8', errors='replace')
        console.write_text(text, encoding='utf-8')
    except OSError as exc:
        problem = 'TOOL_ERROR: ' + str(exc)
        console.write_text(problem + '\n', encoding='utf-8')
    log = route_log.read_text(encoding='utf-8', errors='replace') if route_log.is_file() else ''
    routed = parse_routed_timing(log)
    fmax = routed[0] if routed else None
    status = 'FAIL'
    if problem == 'TIMEOUT':
        status = 'TIMEOUT'
    elif not routed:
        status = 'INCOMPLETE'
    elif (exit_code == 0 and routed[1] == 'PASS' and routed[2] >= mhz
          and fmax >= mhz and impl.is_file() and impl.stat().st_size > 0):
        status = 'PASS'
    return {'seed': seed, 'status': status, 'fmax_mhz': fmax,
            'exit_code': exit_code, 'problem': problem,
            'route_log': route_log.name, 'route_file': impl.name if impl.is_file() else ''}


def run(args):
    if args.first < 1 or args.last < args.first or args.last > 100000:
        raise ValueError('seed range must be ascending positive integers <= 100000')
    if not 1 <= args.jobs <= 8:
        raise ValueError('jobs must be between 1 and 8 (routing consumes memory)')
    if args.beta != 0.6:
        raise ValueError('v73-build hard-codes HeAP beta 0.6; sweeping another beta would not reproduce it')
    if args.mhz != 48.0:
        raise ValueError('v73 requires the 48.00 MHz clock constraint')
    if args.timeout < 30:
        raise ValueError('per-seed timeout is too short')
    inputs = [args.netlist, args.ccf, args.sdc, args.source_sha]
    for item in inputs:
        if not item.is_file() or item.stat().st_size == 0:
            raise ValueError('missing/empty frozen input: ' + str(item))
    verify_source(args.source_sha)
    exe = check_tools()
    output = args.output.resolve()
    if output.exists() and any(output.iterdir()):
        raise ValueError('sweep output directory must be new/empty: ' + str(output))
    output.mkdir(parents=True, exist_ok=True)
    frozen = output / 'frozen'
    frozen.mkdir()
    names = ['netlist.json', 'constraints.ccf', 'constraints.sdc', 'source.sha256']
    for src, name in zip(inputs, names):
        shutil.copyfile(src, frozen / name)
    snap_hash = {name: digest(frozen / name) for name in names}
    (frozen / 'SHA256SUMS').write_text(
        ''.join('%s  %s\n' % (snap_hash[name], name) for name in names), encoding='ascii')
    meta = {'target': 'v73-integrated', 'clock': CLOCK, 'required_mhz': args.mhz,
            'first_seed': args.first, 'last_seed': args.last, 'heap_beta': args.beta,
            'router': 'router2', 'netlist_sha256': snap_hash['netlist.json'],
            'source_sha256_file': snap_hash['source.sha256'],
            'proven_v72_is_not_part_of_sweep': True,
            'not_a_hardware_qualification': True}
    (output / 'metadata.json').write_text(json.dumps(meta, indent=2) + '\n', encoding='ascii')
    print('[INFO] Frozen v73 netlist SHA-256:', snap_hash['netlist.json'], flush=True)
    print('[INFO] Routing seeds %d..%d, %d concurrent, beta %.1f, target %.2f MHz' %
          (args.first, args.last, args.jobs, args.beta, args.mhz), flush=True)
    results = []
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        jobs = [pool.submit(route_one, exe, *(frozen / name for name in names[:3]),
                            output, seed, args.beta, args.timeout, args.mhz)
                for seed in range(args.first, args.last + 1)]
        for future in as_completed(jobs):
            result = future.result()
            results.append(result)
            print('[%s] seed=%d, Fmax=%s MHz, exit=%s' %
                  (result['status'], result['seed'],
                   ('%.2f' % result['fmax_mhz']) if result['fmax_mhz'] is not None else 'NA',
                   result['exit_code']), flush=True)
    # Confirm the working-tree inputs and source contents have not changed mid-sweep.
    verify_source(args.source_sha)
    for src, name in zip(inputs, names):
        if digest(src) != snap_hash[name]:
            raise RuntimeError('input changed during routing sweep: ' + str(src))
    results.sort(key=lambda r: r['seed'])
    with (output / 'results.tsv').open('w', encoding='ascii') as f:
        f.write('seed\tstatus\tfmax_mhz\texit_code\tlog\timpl\n')
        for r in results:
            freq = 'NA' if r['fmax_mhz'] is None else '%.2f' % r['fmax_mhz']
            f.write('%d\t%s\t%s\t%s\t%s\t%s\n' %
                    (r['seed'], r['status'], freq, r['exit_code'], r['route_log'], r['route_file']))
    winners = sorted((r for r in results if r['status'] == 'PASS'),
                     key=lambda r: (-r['fmax_mhz'], r['seed']))
    summary = ['# Local v73 seed sweep', '',
               'Frozen netlist SHA-256: `%s`' % snap_hash['netlist.json'],
               '48 MHz required, beta=0.6, router2. This is ROUTE ONLY, not a packed or tested bootloader.', '',
               'PASS: %d / %d seeds.' % (len(winners), len(results)), '']
    if winners:
        for winner in winners[:10]:
            summary.append('- Seed %d: %.2f MHz' % (winner['seed'], winner['fmax_mhz']))
        summary.extend(['', 'Best timing candidate: seed %d' % winners[0]['seed'],
                        '', 'Rebuild locally with the full command-ROM fixed-point check:',
                        '', '    make -f Makefile.ulx5m-v73-integrated V73_SEED=%d v73-build' % winners[0]['seed'],
                        '    make -f Makefile.ulx5m-v73-integrated V73_SEED=%d v73-qualify' % winners[0]['seed'],
                        '', 'Do not flash on timing alone; final packed image must separately qualify.'])
    else:
        summary.extend(['No 48 MHz route passed. Extend the seed range before changing RTL.',
                        'Do not lower the SDC clock target or flash any generated artifact.'])
    (output / 'summary.md').write_text('\n'.join(summary) + '\n', encoding='ascii')
    (output / 'winners.json').write_text(json.dumps(winners, indent=2) + '\n', encoding='ascii')
    print('\n'.join(summary), flush=True)
    return 0 if winners else 2


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--netlist', type=Path, required=True)
    ap.add_argument('--ccf', type=Path, required=True)
    ap.add_argument('--sdc', type=Path, required=True)
    ap.add_argument('--source-sha', type=Path, required=True)
    ap.add_argument('--first', type=int, default=1)
    ap.add_argument('--last', type=int, default=64)
    ap.add_argument('--jobs', type=int, default=2)
    ap.add_argument('--beta', type=float, default=0.6)
    ap.add_argument('--mhz', type=float, default=48.0)
    ap.add_argument('--timeout', type=int, default=600)
    ap.add_argument('--output', type=Path, required=True)
    args = ap.parse_args()
    try:
        return run(args)
    except (ValueError, RuntimeError, OSError) as exc:
        print('[FAIL] ' + str(exc), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
