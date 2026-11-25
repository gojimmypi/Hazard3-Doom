
#!/usr/bin/env python3
"""Run the exact local ULX5M Makefile build/qualify sequence for each GH seed.

A PASS_FINAL is a correctly qualified PACK-ONLY image with both clocks passing.
It is NOT a hardware boot result. No flash/JTAG operations occur here.
"""
import argparse
import csv
import io
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import time
import zipfile

FIELDS = ('seed', 'status', 'cfg25_mhz', 'bram48_mhz', 'route_exit', 'seconds')
CLOCK = re.compile(r"Max frequency for clock\s+'([^']+)':\s*([0-9]+(?:\.[0-9]+)?) MHz\s*"
                   r"\((PASS|FAIL) at ([0-9]+(?:\.[0-9]+)?) MHz\)", re.I)
CFG_CLOCK = 'cfg25_i.clk25'
SERV_CLOCK = 'bram_i.clk'
PASS = 'PASS_FINAL'
SEEDS_PER_SWEEP = 512


def seed_range(first, last, per_job=None):
    if not (1 <= first <= last <= 2147483647):
        raise ValueError('seed range must be positive and ascending')
    if last - first + 1 > SEEDS_PER_SWEEP:
        raise ValueError(f'limit each sweep to {SEEDS_PER_SWEEP} seeds')
    if per_job is not None and not 1 <= per_job <= 10:
        raise ValueError('seeds per job must be 1..10')


def sweep_last(first, last, count):
    if count is not None:
        if last is not None:
            raise ValueError('specify --last or --count, not both')
        if not 1 <= count <= SEEDS_PER_SWEEP:
            raise ValueError(f'seed count must be 1..{SEEDS_PER_SWEEP}')
        last = first + count - 1
    elif last is None:
        last = first + SEEDS_PER_SWEEP - 1
    seed_range(first, last)
    return last


def matrix(args):
    args.last = sweep_last(args.first, args.last, args.count)
    seed_range(args.first, args.last, args.per_job)
    groups = [{'group': f'{first}-{min(first + args.per_job - 1, args.last)}',
               'first': first, 'last': min(first + args.per_job - 1, args.last)}
              for first in range(args.first, args.last + 1, args.per_job)]
    if len(groups) > 256:
        raise ValueError('too many GitHub matrix jobs; increase seeds_per_job')
    print(json.dumps({'include': groups}, separators=(',', ':')))


def timing(log):
    """Use the FINAL routing report for each clock, not the intermediate estimate."""
    rows = {}
    for name, value, state, required in CLOCK.findall(log):
        rows[name] = (float(value), state.upper(), float(required))
    cfg, serv = rows.get(CFG_CLOCK), rows.get(SERV_CLOCK)
    valid = (cfg is not None and serv is not None and
             abs(cfg[2] - 25.0) < 0.01 and abs(serv[2] - 48.0) < 0.01)
    passed = bool(valid and all(state == 'PASS' and value >= required
                                for value, state, required in rows.values()))
    return passed, cfg[0] if cfg else None, serv[0] if serv else None


def extra_nextpnr_args(value):
    """Reject options that override a required, identical CI/local build input."""
    tokens = shlex.split(value)
    blocked = ('--device', '--json', '--sdc', '--seed', '--router',
               '--placer-heap-beta', '--help', '--version', '--run',
               '--write', '--log', '--logfile')
    for token in tokens:
        if not re.fullmatch(r'[a-zA-Z0-9_./=:+,-]+', token):
            raise ValueError('unsafe characters in nextpnr argument: ' + token)
        if (token in ('-o', '-l') or token.startswith('-o=') or
                token.startswith('-l=') or
                any(token == x or token.startswith(x + '=') for x in blocked)):
            raise ValueError('nextpnr extra args cannot override build settings: ' + token)
    return tokens


def write_csv(file, rows):
    with file.open('w', newline='', encoding='ascii') as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(rows)


def _make(args, *targets, timeout=60):
    cmd = [args.make, '-f', 'Makefile.ulx5m-gs', *targets]
    return subprocess.run(cmd, cwd=args.project, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, text=True, timeout=timeout,
                          check=False)


def run_full_build(args, seed):
    """No frozen netlists. Identical Makefile build/qualify per seed."""
    logs = args.output / 'logs'
    logs.mkdir(parents=True, exist_ok=True)
    log_path = logs / f'seed-{seed}.log'
    started = time.monotonic()
    full_log = []
    cfg = serv = None
    rc = 'missing'
    try:
        clean = _make(args, 'clean', timeout=60)
        if clean.returncode:
            raise ValueError('make clean failed: ' + clean.stdout[-1200:])
        overrides = [f'SEED={seed}', f'HEAP_BETA={args.heap_beta}',
                     f'NEXTPNR_EXTRA_ARGS={args.extra_args}']
        result = _make(args, 'build', *overrides, timeout=args.timeout)
        full_log.append(result.stdout)
        rc = str(result.returncode)
        # The build itself can invoke nextpnr up to three times. The last report
        # is decisive, and is also preserved in the canonical pnr.log.
        packlog = args.project / 'build-ulx5m-gs/bootloader/pnr.log'
        measured = packlog.read_text(errors='replace') if packlog.is_file() else result.stdout
        ok, cfg, serv = timing(measured)
        if result.returncode == 0 and ok:
            qualify = _make(args, 'qualify', *overrides, timeout=60)
            full_log.append('\nQUALIFY:\n' + qualify.stdout)
            if qualify.returncode == 0:
                status = PASS
            else:
                status = 'QUALIFY_ERROR'
                rc = str(qualify.returncode)
        elif not ok and cfg is not None and serv is not None:
            status = 'FAIL_TIMING'
        elif 'did not converge' in result.stdout:
            status = 'FAIL_CONVERGENCE'
        else:
            status = 'BUILD_ERROR'
    except subprocess.TimeoutExpired as error:
        status, rc = 'TIMEOUT', 'timeout'
        full_log.append('FULL BUILD TIMEOUT\n' +
                        (error.stdout.decode(errors='replace')
                         if isinstance(error.stdout, bytes) else (error.stdout or '')))
    except ValueError as error:
        status, rc = 'BUILD_ERROR', 'error'
        full_log.append(str(error))
    log_path.write_text('\n'.join(full_log), encoding='utf-8')
    return {'seed': seed, 'status': status,
            'cfg25_mhz': f'{cfg:.2f}' if cfg is not None else '',
            'bram48_mhz': f'{serv:.2f}' if serv is not None else '',
            'route_exit': rc, 'seconds': f'{time.monotonic() - started:.1f}'}


def full_build(args):
    seed_range(args.first, args.last)
    if args.timeout < 30 or args.timeout > 3600:
        raise ValueError('per-seed timeout must be 30..3600 seconds')
    if args.heap_beta not in ('0.4', '0.5', '0.6', '0.7', '0.8'):
        raise ValueError('unsupported HeAP beta')
    extra_nextpnr_args(args.extra_args)
    if not (args.project / 'Makefile.ulx5m-gs').is_file():
        raise ValueError('canonical Makefile missing: ' + str(args.project))
    args.output.mkdir(parents=True, exist_ok=True)
    rows, best, best_bit = [], None, None
    try:
        for seed in range(args.first, args.last + 1):
            row = run_full_build(args, seed)
            rows.append(row)
            if row['status'] == PASS:
                bit = args.project / 'build-ulx5m-gs/bootloader/top_ulx5m_gs_bootloader-PACK-ONLY.bit'
                if not bit.is_file() or not bit.stat().st_size:
                    row['status'] = 'BUILD_ERROR'
                else:
                    if args.retain_bitstreams:
                        dest = args.output / 'qualified-PACK-ONLY' / f'seed-{seed}-PACK-ONLY.bit'
                        dest.parent.mkdir(parents=True, exist_ok=True)
                        shutil.copy2(bit, dest)
                    elif best is None or float(row['bram48_mhz']) > float(best['bram48_mhz']):
                        best, best_bit = row, bit.read_bytes()
            print(f"{seed:>5}: {row['status']:<17} "
                  f"25 MHz={row['cfg25_mhz'] or 'N/A':>6}  "
                  f"48 MHz={row['bram48_mhz'] or 'N/A':>6}", flush=True)
            write_csv(args.output / f'group-{args.first}-{args.last}.csv', rows)
        if best_bit is not None:
            dest = args.output / 'qualified-PACK-ONLY' / f"seed-{best['seed']}-PACK-ONLY.bit"
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(best_bit)
        print(f"Group complete: {sum(r['status'] == PASS for r in rows)} "
              f'of {len(rows)} final-image passes (NOT hardware-tested)', flush=True)
    finally:
        # Every completed seed is represented even if an unexpected runner failure
        # happens immediately afterward. The summarizer rejects missing seeds.
        if rows:
            write_csv(args.output / f'group-{args.first}-{args.last}.csv', rows)


def gh_api(path, binary=False):
    result = subprocess.run(['gh', 'api', path], capture_output=True, check=False)
    if result.returncode:
        raise OSError('GitHub artifact API failed: ' +
                      result.stderr.decode(errors='replace')[-1000:])
    return result.stdout if binary else json.loads(result.stdout)


def list_run_artifacts(repo, run_id):
    artifacts = []
    for page in range(1, 20):
        data = gh_api(f'repos/{repo}/actions/runs/{run_id}/artifacts?per_page=100&page={page}')
        artifacts.extend(data['artifacts'])
        if len(data['artifacts']) < 100:
            break
    return artifacts


def fetch_group_csv(repo, artifact_id, group):
    archive = gh_api(f'repos/{repo}/actions/artifacts/{artifact_id}/zip', binary=True)
    with zipfile.ZipFile(io.BytesIO(archive)) as content:
        expected = f'group-{group}.csv'
        matches = [name for name in content.namelist() if name.split('/')[-1] == expected]
        if len(matches) != 1:
            raise ValueError('missing or duplicated group CSV: ' + expected)
        return list(csv.DictReader(io.StringIO(content.read(matches[0]).decode('ascii'))))


def watch(args):
    args.last = sweep_last(args.first, args.last, args.count)
    seed_range(args.first, args.last, args.per_job)
    expected = {f'{start}-{min(start + args.per_job - 1, args.last)}'
                for start in range(args.first, args.last + 1, args.per_job)}
    seen, rows = set(), {}
    deadline = time.monotonic() + args.max_minutes * 60
    args.output.mkdir(parents=True, exist_ok=True)
    summary_path = args.output / 'live.md'
    summary_path.write_text('# Live ULX5M full-build timing passes\n\n'
                            'Final PACK-ONLY images; NOT hardware-tested.\n\n', encoding='ascii')
    print(f'LIVE final-image collector: {len(expected)} groups, both clocks required', flush=True)
    while seen != expected:
        for artifact in list_run_artifacts(args.repo, args.run_id):
            name = artifact['name']
            prefix, suffix = 'ulx5m-group-', f'-{args.run_id}'
            if not (name.startswith(prefix) and name.endswith(suffix)):
                continue
            group = name[len(prefix):-len(suffix)]
            if group not in expected or group in seen or artifact.get('expired'):
                continue
            block = fetch_group_csv(args.repo, artifact['id'], group)
            first, last = (int(v) for v in group.split('-'))
            actual, passes = set(), 0
            for row in block:
                if set(row) != set(FIELDS):
                    raise ValueError('invalid live group row: ' + group)
                seed = int(row['seed'])
                if seed < first or seed > last or seed in actual or seed in rows:
                    raise ValueError('invalid or repeated seed: ' + group)
                actual.add(seed)
                rows[seed] = row
                if row['status'] == PASS:
                    passes += 1
                    msg = (f"[FINAL IMAGE PASS] seed {seed}: "
                           f"25 MHz={row['cfg25_mhz']}, 48 MHz={row['bram48_mhz']}")
                    print(msg, flush=True)
                    with summary_path.open('a', encoding='ascii') as file:
                        file.write(f'- {msg}\n')
            if actual != set(range(first, last + 1)):
                print(f'[WARN] group {group} incomplete: {len(actual)} rows', flush=True)
            seen.add(group)
            print(f'[LIVE] group {group}: {passes} passing, '
                  f'{len(seen)}/{len(expected)} groups received', flush=True)
            if args.step_summary:
                with open(args.step_summary, 'a', encoding='ascii') as file:
                    file.write(f'- Group {group}: {passes} final passes '
                               f'({len(seen)}/{len(expected)} groups)\n')
            write_csv(args.output / 'live-results.csv', [rows[k] for k in sorted(rows)])
        if seen == expected:
            break
        if time.monotonic() >= deadline:
            raise ValueError('live collector timed out waiting for groups')
        time.sleep(args.interval)
    print(f"[LIVE] complete: {sum(r['status'] == PASS for r in rows.values())} "
          f'qualified images, {len(rows)} rows', flush=True)
    return 0


def summarize(args):
    files = sorted(args.input.glob('group-*.csv'))
    if not files:
        raise ValueError('no seed groups were received')
    rows = []
    for file in files:
        with file.open(newline='', encoding='ascii') as fh:
            for row in csv.DictReader(fh):
                if set(row) != set(FIELDS) or any(v is None for v in row.values()):
                    raise ValueError('invalid group CSV: ' + str(file))
                rows.append(row)
    seeds = [int(r['seed']) for r in rows]
    if len(set(seeds)) != len(seeds):
        raise ValueError('duplicate seeds')
    seed_range(min(seeds), max(seeds))
    if len(rows) != max(seeds) - min(seeds) + 1:
        raise ValueError('incomplete sweep results')
    rows.sort(key=lambda x: int(x['seed']))
    args.output.mkdir(parents=True, exist_ok=True)
    write_csv(args.output / 'results.csv', rows)
    passed = sorted((r for r in rows if r['status'] == PASS),
                    key=lambda r: (-float(r['bram48_mhz']), -float(r['cfg25_mhz']), int(r['seed'])))
    summary = ['# ULX5M-GS bootloader full-image sweep', '',
               f'- Checked: {len(rows)} seeds ({min(seeds)}..{max(seeds)})',
               f'- Timing + final-image qualification PASS: {len(passed)} seeds',
               '- Uses the same `Makefile.ulx5m-gs build SEED=N` and `qualify SEED=N` as local WSL.',
               '- Requirements: cfg25_i.clk25 >= 25 MHz and bram_i.clk >= 48 MHz.',
               '- PACK-ONLY images are not hardware-tested; never write protected flash automatically.', '',
               '| Seed | 25 MHz Fmax | 48 MHz Fmax |', '| ---: | ---: | ---: |']
    for r in passed[:20]:
        summary.append(f"| {r['seed']} | {r['cfg25_mhz']} | {r['bram48_mhz']} |")
    if not passed:
        summary.append('| No fully qualified seed passed | | |')
    summary.append('')
    (args.output / 'summary.md').write_text('\n'.join(summary) + '\n', encoding='ascii')
    print('\n'.join(summary))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='cmd', required=True)
    m = commands.add_parser('matrix')
    m.add_argument('--first', type=int, required=True)
    m.add_argument('--last', type=int)
    m.add_argument('--count', type=int)
    m.add_argument('--per-job', type=int, required=True)
    f = commands.add_parser('full-build')
    f.add_argument('--first', type=int, required=True)
    f.add_argument('--last', type=int, required=True)
    f.add_argument('--output', type=Path, required=True)
    f.add_argument('--project', type=Path, default=Path('bootloader-serv'))
    f.add_argument('--make', default='make')
    f.add_argument('--timeout', type=int, default=540)
    f.add_argument('--heap-beta', default='0.6')
    f.add_argument('--extra-args', default='')
    f.add_argument('--retain-bitstreams', action='store_true')
    w = commands.add_parser('watch')
    w.add_argument('--repo', required=True)
    w.add_argument('--run-id', type=int, required=True)
    w.add_argument('--first', type=int, required=True)
    w.add_argument('--last', type=int)
    w.add_argument('--count', type=int)
    w.add_argument('--per-job', type=int, required=True)
    w.add_argument('--interval', type=int, default=30)
    w.add_argument('--max-minutes', type=int, default=240)
    w.add_argument('--output', type=Path, required=True)
    w.add_argument('--step-summary', default=os.environ.get('GITHUB_STEP_SUMMARY', ''))
    s = commands.add_parser('summarize')
    s.add_argument('--input', type=Path, required=True)
    s.add_argument('--output', type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        {'matrix': matrix, 'full-build': full_build,
         'watch': watch, 'summarize': summarize}[args.cmd](args)
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        print('[FAIL]', error, file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
