#!/usr/bin/env python3
"""ULX5M-GS v75 seed-228 guarded 512KiB primary, pinned to installed v73.

Offline by default. Never flash without explicit candidate hash and approval.
This extends the primary 0x70000..0x7ffff by 16 sectors while preserving an
exact full-chip v73 recovery and all flash contents from 0x80000 onward.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT.parent
BUILD = ROOT / 'build-ulx5m-gs'
HERE = Path(__file__).resolve().parent
V73_DIR = BUILD / 'v73-normal-boot-dfu-hw-native'
V73_SESSION = BUILD / 'v73-guarded-ab-20261029T001424726363Z-31248'
LOADER = PROJECT / 'bin/openFPGALoader-v1.2.0.exe'
FORMAT = 'ULX5M-GS-V75-512K-FULL-PRIMARY-GUARDED-AB-V1'
FLASH_BYTES = 0x400000
PRIMARY_BYTES = 0x80000
ERASE_BYTES = 0x1000
APP_OFFSET = 0x201000
APP_LENGTH = 0x1000
V73_FULL_SHA = '71f928da968accf8f0dbe054013c7badf1bfac316266c0b5fee28e5aa794ed1f'
V73_PRIMARY_448K_SHA = '915dd7a957e74a3c5c03d5b86b7aeb5c2fdae036ada35ac20adcce44d8168049'
APP_SECTOR_SHA = '28b1e5cbfa45a319600ec38c81207a36d9889c3179e8055f5a663c616ef97bee'
APPROVED_SEED = 228
APPROVED_BIT_SHA = '6cfac23d92139f32d21a84c058ce6a25c8caaaf0b51d52a624dadab61c68c7c3'
APPROVED_BIT_BYTES = 468116
INSTALL_ACK = 'I_AUTHORIZE_V75_SEED228_FULL_PRIMARY_512K_FLASH_WITH_JTAG_ROLLBACK'
RESTORE_ACK = 'I_AUTHORIZE_RESTORE_EXACT_SAVED_V73_512K_PRIMARY'

def sha(data):
    return hashlib.sha256(data).hexdigest()


def load_py(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def hw_adapter():
    return load_py(HERE / 'qualify-ulx5m-serv-jtag-write.py', 'v75_jtag_hw')


def candidate_paths(seed):
    if not 1 <= seed <= 260:
        raise ValueError('Seed must be in 1..260')
    name = 'top_ulx5m_gs_flash_read'
    return (V73_DIR / (name + '-seed%d-PACK-ONLY.bit' % seed),
            V73_DIR / 'cmd.hex',
            V73_DIR / (name + '.json'),
            V73_DIR / ('pnr-seed%d.log' % seed),
            V73_DIR / 'source.sha256')


def baseline_v73():
    """Recreate the exact hardware-verified installed v73, never an assumed map."""
    old = load_py(HERE / 'qualify-ulx5m-v73-guarded-ab.py', 'v73_installer')
    before, after, rollback, primary = old.verify_session(V73_SESSION)
    meta = json.loads((V73_SESSION / 'manifest.json').read_text(encoding='ascii'))
    phase = json.loads((V73_SESSION / 'state.json').read_text(encoding='ascii'))
    if (phase.get('phase') != 'V73_FLASH_VERIFIED_RUNTIME_UNTESTED' or
            len(before) != FLASH_BYTES or len(after) != FLASH_BYTES or
            len(primary) != 0x70000 or sha(primary) != V73_PRIMARY_448K_SHA or
            sha(after) != V73_FULL_SHA or meta.get('v73_expected_after_sha256') != V73_FULL_SHA or
            meta.get('candidate_sha256') != '7b376ae65941fdc5e99fa135004332c69bc577fe1d34d5a72b9f67595834bad7'):
        raise ValueError('Archived installed v73 does not match pinned physical install')
    if sha(after[APP_OFFSET:APP_OFFSET + APP_LENGTH]) != APP_SECTOR_SHA:
        raise ValueError('Secondary v41 sector changed in archived installed v73')
    if after[0x70000:PRIMARY_BYTES] == bytes([255]) * (PRIMARY_BYTES - 0x70000):
        raise ValueError('Unexpected empty extension sectors; verify archived flash layout')
    return after


def check_candidate(seed, expected_sha=None):
    if seed != APPROVED_SEED:
        raise ValueError('Only pinned seed 228 is eligible; NO HARDWARE ACCESS')
    bit, cmd, netlist, log, source = candidate_paths(seed)
    # Gate this before shared cmd.hex/netlist checks. Rebuilding another seed
    # legitimately replaces those shared files but must never make a known
    # over-size old candidate eligible for physical access.
    disk_size = bit.stat().st_size
    if disk_size > PRIMARY_BYTES:
        raise ValueError('candidate %d bytes (0x%x) overlaps protected 0x%06x..0x1fffff; '
                         'exceeds approved 512 KiB by %d bytes; NO HARDWARE ACCESS' %
                         (disk_size, disk_size, PRIMARY_BYTES, disk_size - PRIMARY_BYTES))
    qualifier = load_py(HERE / 'qualify-ulx5m-v73-integrated.py', 'v73_integrated_qual')
    size, digest, command_sha, clocks = qualifier.qualify(bit, cmd, log, netlist, source)
    if size != APPROVED_BIT_BYTES or digest != APPROVED_BIT_SHA:
        raise ValueError('Candidate differs from the local qualified seed-228 bitstream')
    if expected_sha is not None:
        if not re.fullmatch('[0-9a-f]{64}', expected_sha) or digest != expected_sha:
            raise ValueError('Explicit candidate SHA-256 mismatch')
    if size > PRIMARY_BYTES:
        raise ValueError('candidate %d bytes (0x%x) overlaps protected 0x%06x..0x1fffff; '
                         'exceeds approved 512 KiB by %d bytes; NO HARDWARE ACCESS' %
                         (size, size, PRIMARY_BYTES, size - PRIMARY_BYTES))
    if size <= 0 or PRIMARY_BYTES % ERASE_BYTES:
        raise ValueError('Invalid primary image/erase geometry')
    raw = bit.read_bytes()
    if sha(raw) != digest or len(raw) != size:
        raise ValueError('Candidate changed during qualification')
    print('[PASS] Candidate fits 0x000000..0x07ffff: %d bytes, SHA256 %s' %
          (size, digest), flush=True)
    print('[PASS] v75 source/ROM/48MHz/pins qualified; ROM SHA256 %s' %
          command_sha, flush=True)
    return raw + bytes([255]) * (PRIMARY_BYTES - size), digest, size


def proposed(before, primary):
    if len(before) != FLASH_BYTES or len(primary) != PRIMARY_BYTES:
        raise ValueError('Flash/primary size is not exact')
    return primary + before[PRIMARY_BYTES:]


def verify_protected(live, before):
    if len(live) != FLASH_BYTES or live[PRIMARY_BYTES:] != before[PRIMARY_BYTES:]:
        raise ValueError('PROTECTED flash suffix changed; automatic restore prohibited')


def write_once(path, data):
    with path.open('xb') as f:
        f.write(data)
        f.flush()
        os.fsync(f.fileno())


def make_manifest(before, after, digest, size):
    return {
        'format': FORMAT, 'base': 0, 'length': PRIMARY_BYTES,
        'erase_bytes': ERASE_BYTES, 'flash_bytes': FLASH_BYTES,
        'baseline': 'v73 seed-7 hardware-verified full chip',
        'v73_before_sha256': sha(before),
        'v75_expected_after_sha256': sha(after),
        'candidate_sha256': digest, 'candidate_bytes': size,
        'rollback_primary_sha256': sha(before[:PRIMARY_BYTES]),
        'install_primary_sha256': sha(after[:PRIMARY_BYTES]),
        'protected_suffix_sha256': sha(before[PRIMARY_BYTES:]),
        'v41_sector_sha256': sha(before[APP_OFFSET:APP_OFFSET + APP_LENGTH]),
        'replaced_extension_64k_sha256': sha(before[0x70000:PRIMARY_BYTES]),
    }


def create_session(directory, before, primary, digest, size):
    after = proposed(before, primary)
    directory.mkdir(parents=False, exist_ok=False)
    write_once(directory / 'v73-full-flash-before.bin', before)
    write_once(directory / 'v73-primary-512k-rollback.bin', before[:PRIMARY_BYTES])
    write_once(directory / 'v75-primary-512k-install.bin', primary)
    write_once(directory / 'manifest.json',
               (json.dumps(make_manifest(before, after, digest, size),
                           indent=2, sort_keys=True) + '\n').encode('ascii'))
    if hasattr(os, 'sync'):
        os.sync()
    verify_session(directory)


def verify_session(directory):
    meta = json.loads((directory / 'manifest.json').read_text(encoding='ascii'))
    before = (directory / 'v73-full-flash-before.bin').read_bytes()
    rollback = (directory / 'v73-primary-512k-rollback.bin').read_bytes()
    primary = (directory / 'v75-primary-512k-install.bin').read_bytes()
    size = meta.get('candidate_bytes')
    digest = meta.get('candidate_sha256')
    if (not isinstance(size, int) or isinstance(size, bool) or
            not 1 <= size <= PRIMARY_BYTES or not isinstance(digest, str) or
            not re.fullmatch('[0-9a-f]{64}', digest)):
        raise ValueError('Corrupted session candidate metadata')
    if (len(before) != FLASH_BYTES or sha(before) != V73_FULL_SHA or
            rollback != before[:PRIMARY_BYTES] or len(primary) != PRIMARY_BYTES or
            primary[size:] != bytes([255]) * (PRIMARY_BYTES - size) or
            sha(primary[:size]) != digest):
        raise ValueError('Session backup/primary/padding differs from pinned installed v73')
    if meta != make_manifest(before, proposed(before, primary), digest, size):
        raise ValueError('Session manifest failed full verification')
    return before, proposed(before, primary), rollback, primary


def state(directory, phase):
    tmp = directory / 'state.json.tmp'
    with tmp.open('w', encoding='ascii', newline='\n') as f:
        json.dump({'format': FORMAT, 'phase': phase}, f, sort_keys=True)
        f.write('\n')
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, directory / 'state.json')


def read_full(hw):
    return hw.read_region(LOADER, 100, 0, FLASH_BYTES)


def write_primary(hw, file):
    if file.suffix != '.bin' or file.stat().st_size != PRIMARY_BYTES:
        raise ValueError('Refusing non-512KiB primary payload')
    # Existing proven JTAG adapter translates only file arguments at WSL->EXE boundary.
    hw.call(hw.jtag_cmd(LOADER, 100) +
            ['-f', '--verify', '--offset', '0', str(file)], timeout=900)


def restore(hw, directory):
    before, after, rollback, primary = verify_session(directory)
    current = read_full(hw)
    verify_protected(current, before)
    state(directory, 'V73_RESTORE_STARTED')
    write_primary(hw, directory / 'v73-primary-512k-rollback.bin')
    if read_full(hw) != before:
        raise ValueError('v73 exact full 4MiB rollback readback mismatch')
    state(directory, 'EXACT_V73_4M_RESTORED')
    print('[PASS] Exact pre-install v73 4MiB restored; cold boot requires physical test', flush=True)


def new_session():
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    return BUILD / ('v75-512k-guarded-ab-%s-%d' % (stamp, os.getpid()))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument('--read-only', action='store_true',
                       help='Qualify image, then read and compare live 4MiB without writes')
    modes.add_argument('--install', action='store_true',
                       help='Danger: authorizes full 512KiB primary JTAG overwrite')
    modes.add_argument('--restore-session', type=Path, metavar='DIR',
                       help='Danger: restore exact archived v73 512KiB primary')
    parser.add_argument('--seed', type=int, default=228)
    parser.add_argument('--candidate-sha256', default='')
    parser.add_argument('--confirm', default='')
    args = parser.parse_args(argv)
    try:
        if args.install:
            if args.confirm != INSTALL_ACK or not args.candidate_sha256:
                raise ValueError('INSTALL blocked: explicit candidate SHA256 and --confirm ' + INSTALL_ACK)
        elif args.restore_session:
            if args.confirm != RESTORE_ACK or args.candidate_sha256:
                raise ValueError('RESTORE blocked: --confirm ' + RESTORE_ACK)
        elif args.confirm:
            raise ValueError('Acknowledgment not permitted in offline/read-only mode')
        if args.restore_session:
            directory = args.restore_session.resolve()
            if (directory.parent != BUILD.resolve() or
                    not directory.name.startswith('v75-512k-guarded-ab-')):
                raise ValueError('Restore directory must be a direct v75-512k-guarded-ab child of build-ulx5m-gs')
            verify_session(directory)
            hw = hw_adapter()
            hw.check_loader(LOADER)
            hw.detect(LOADER, 100)
            restore(hw, directory)
            return 0
        baseline = baseline_v73()
        print('[PASS] Archived installed v73 exact 4MiB SHA256 %s' %
              sha(baseline), flush=True)
        primary, digest, size = check_candidate(args.seed,
                                               args.candidate_sha256 or None)
        after = proposed(baseline, primary)
        print('[PLAN] Replace exactly 0x000000..0x07ffff; protect 0x080000..0x3fffff',
              flush=True)
        print('[PLAN] Proposed expected 4MiB post-write SHA256 %s' % sha(after),
              flush=True)
        print('[PLAN] 128 x 4KiB sectors; full 4MiB dual read and saved rollback required',
              flush=True)
        if not (args.read_only or args.install):
            print('[OFFLINE PASS] No hardware accessed. Flash write NOT authorized.', flush=True)
            return 0
        hw = hw_adapter()
        hw.check_loader(LOADER)
        hw.detect(LOADER, 100)
        before = read_full(hw)
        if before != baseline:
            raise ValueError('Live 4MiB is not exactly pinned installed v73 baseline')
        print('[PASS] Physical flash exactly matches installed v73', flush=True)
        if args.read_only:
            print('[READ-ONLY PASS] No flash writing performed.', flush=True)
            return 0
        # A second independent full-chip read is required immediately before backups.
        if read_full(hw) != before:
            raise ValueError('Independent full-chip JTAG reads differ; NO FLASH WRITE')
        directory = new_session()
        create_session(directory, before, primary, digest, size)
        print('[RECOVERY] Full 4MiB v73 baseline and 512KiB rollback saved in %s' %
              directory, flush=True)
        try:
            state(directory, 'V75_512K_WRITE_STARTED')
            write_primary(hw, directory / 'v75-primary-512k-install.bin')
            if read_full(hw) != after:
                raise ValueError('Full 4MiB post-install readback differs from pinned composite')
            state(directory, 'V75_FLASH_VERIFIED_RUNTIME_UNTESTED')
            print('[PASS] Flash 4MiB readback equals pinned composite; BOTH COLD BOOT MODES STILL UNTESTED', flush=True)
            return 0
        except (Exception, KeyboardInterrupt) as exc:
            print('[WRITE ERROR] %s; attempting full-primary JTAG rollback' % exc,
                  file=sys.stderr, flush=True)
            try:
                restore(hw, directory)
            except (Exception, KeyboardInterrupt) as secondary:
                state(directory, 'CRITICAL_RESTORE_UNVERIFIED')
                print('[CRITICAL] Restore not verified: %s' % secondary,
                      file=sys.stderr, flush=True)
            return 1
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as exc:
        print('[BLOCK] ' + str(exc), file=sys.stderr, flush=True)
        return 1


if __name__ == '__main__':
    sys.exit(main())
