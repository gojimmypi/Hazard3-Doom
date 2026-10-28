#!/usr/bin/env python3
"""ULX5M-GS v64: guarded, opt-in, single-64-KiB reconfiguration-status A/B.

Never call the prior v55->v60 installer for this test. A frozen v60 primary and
independently qualified v63c gmpack bitstream must differ by exactly 3 bytes.
Only 0x060000..0x06ffff is writable. Whole-flash and v60 rollback are saved
and read back; interrupted writes need JTAG restore, not SPI-active cold boot.

No writes in default or --read-only mode. --install and --restore-session
require separate exact acknowledgement strings. This test does NOT claim
that the configuration-bank mode transition has been solved.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BUILD = ROOT / 'bootloader-serv' / 'build-ulx5m-gs'
SRC = BUILD / 'normal-boot-dfu-hw-native' / 'spi-secondary-spi-primary-seed302.bit'
V60_REGION = BUILD / 'v62-spi-update-20261027T034513196538Z-1776' / 'v60-candidate-region-000000-06ffff.bin'
LOADER = ROOT / 'bin' / 'openFPGALoader-v1.2.0.exe'
BLOCK_BASE = 0x60000
BLOCK_SIZE = 0x10000
REGION_SIZE = 0x70000
FLASH_SIZE = 0x400000
APP_BASE = 0x201000
APP_LEN = 0x1000
PRIMARY_LEN = 446729
PRIMARY_SHA = '5a0c926ae560810800ccc9d864a970c8942863dfba22a42b8a53f519c1914b75'
CANDIDATE_SHA = '689f17a6b2e5ba1669e8f7652da4163b2d824ec91878b767e202ca1b33b9d4a2'
REGION_SHA = '5c72c39516f5e2b4fb2d39b8a153fb55eeeb12f9a5917799dc793ce006e61aee'
BEFORE_BLOCK_SHA = 'c7cba68fb84c9ec3c6dc81da336c9aac72e12d55a1e4d7981109d7aa5180666a'
AFTER_BLOCK_SHA = '132628e254237ad7656162449751d05ef7b09a4540b7334963f987b5452ad803'
BEFORE_FLASH_SHA = 'a2a29d6fab3291d14f37b8ec4ce1a07d0a58729172c4dd629a877a4c1874e0e2'
APP_SHA = '28b1e5cbfa45a319600ec38c81207a36d9889c3179e8055f5a663c616ef97bee'
EDIT_OFFSETS = (0x6d0df, 0x6d0eb, 0x6d0ec)
FORMAT = 'ULX5M-GS-V64-RECONFIG-AB-ONE-BLOCK-V1'
INSTALL_ACK = 'I_ACCEPT_V64_SINGLE_64K_RECONFIG_FLASH_TEST_AND_V60_ROLLBACK_RISK'
RESTORE_ACK = 'I_ACCEPT_V64_RESTORE_EXACT_V60_64K_BLOCK_RISK'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def check_bytes(label, data, length, expected_sha):
    if len(data) != length or sha(data) != expected_sha:
        raise ValueError('%s mismatch (len=%d, sha256=%s)' % (label, len(data), sha(data)))


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise ValueError('Cannot import %s' % path)
    obj = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(obj)
    return obj


def hw_adapter():
    return load_module('ulx5m_v64_verified_jtag', HERE / 'qualify-ulx5m-serv-jtag-write.py')


def inspect_candidate(base, candidate, region):
    """All inputs are pinned, with no network, flash, or subprocess access."""
    check_bytes('installed v60 .bit', base, PRIMARY_LEN, PRIMARY_SHA)
    check_bytes('real-gmpack v63c candidate', candidate, PRIMARY_LEN, CANDIDATE_SHA)
    check_bytes('v62 v60 region', region, REGION_SIZE, REGION_SHA)
    if not region.startswith(base):
        raise ValueError('v62 region does not contain exact installed primary')
    if region[PRIMARY_LEN:0x6e000] != b'\xff' * (0x6e000 - PRIMARY_LEN):
        raise ValueError('v60 primary flash padding differs from v62 manifest')
    diff = tuple(i for i, (a, b) in enumerate(zip(base, candidate)) if a != b)
    if diff != EDIT_OFFSETS or (base[EDIT_OFFSETS[0]], candidate[EDIT_OFFSETS[0]]) != (0x17, 0x1f):
        raise ValueError('Candidate is not exactly the observed v63c three-byte status/CRC A/B')
    # CRC and command semantics are additionally checked by v63c qualification.
    v63c = load_module('ulx5m_v64_v63c', HERE / 'qualify-ulx5m-v63c-reconfig-primary.py')
    v63c.validate_variant(base, candidate)
    updated_region = candidate + region[PRIMARY_LEN:]
    old_block = region[BLOCK_BASE:BLOCK_BASE + BLOCK_SIZE]
    new_block = updated_region[BLOCK_BASE:BLOCK_BASE + BLOCK_SIZE]
    check_bytes('v60 rollback block', old_block, BLOCK_SIZE, BEFORE_BLOCK_SHA)
    check_bytes('v63c candidate block', new_block, BLOCK_SIZE, AFTER_BLOCK_SHA)
    if updated_region[:BLOCK_BASE] != region[:BLOCK_BASE]:
        raise ValueError('Mutation reaches outside the single approved flash block')
    return old_block, new_block


def qualify_live(live, region, old_block, new_block):
    check_bytes('complete installed v60 flash', live, FLASH_SIZE, BEFORE_FLASH_SHA)
    if live[:REGION_SIZE] != region or live[BLOCK_BASE:BLOCK_BASE + BLOCK_SIZE] != old_block:
        raise ValueError('Flash contents disagree with pinned v60 region')
    check_bytes('installed v41 secondary sector', live[APP_BASE:APP_BASE + APP_LEN], APP_LEN, APP_SHA)
    proposed = bytearray(live)
    proposed[BLOCK_BASE:BLOCK_BASE + BLOCK_SIZE] = new_block
    proposed = bytes(proposed)
    diffs = tuple(i for i in range(BLOCK_BASE, BLOCK_BASE + BLOCK_SIZE)
                  if live[i] != proposed[i])
    if diffs != EDIT_OFFSETS or proposed[:BLOCK_BASE] != live[:BLOCK_BASE] or proposed[BLOCK_BASE + BLOCK_SIZE:] != live[BLOCK_BASE + BLOCK_SIZE:]:
        raise ValueError('Unexpected full-flash modification footprint')
    return proposed


def write_exclusive(path, data):
    with path.open('xb') as f:
        f.write(data)
        f.flush()
        os.fsync(f.fileno())


def new_session():
    return BUILD / ('v64-reconfig-ab-%s-%s' % (datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ'), os.getpid()))


def manifest(live, proposed):
    return {
        'format': FORMAT,
        'operation': 'SINGLE-BLOCK RECONFIG A/B; NO VENDOR COMMAND',
        'flash_before_sha256': BEFORE_FLASH_SHA,
        'flash_candidate_sha256': sha(proposed),
        'flash_bytes': FLASH_SIZE,
        'block_offset': BLOCK_BASE,
        'block_bytes': BLOCK_SIZE,
        'v60_rollback_block_sha256': BEFORE_BLOCK_SHA,
        'candidate_block_sha256': AFTER_BLOCK_SHA,
        'v60_primary_sha256': PRIMARY_SHA,
        'v63c_primary_sha256': CANDIDATE_SHA,
        'app_sector_sha256': APP_SHA,
        'changed_offsets_hex': ['0x%06x' % n for n in EDIT_OFFSETS],
        'protected_prefix_end': BLOCK_BASE,
        'protected_suffix_start': BLOCK_BASE + BLOCK_SIZE,
    }


def save_session(directory, live, proposed, old_block, new_block):
    directory.mkdir(parents=False, exist_ok=False)
    write_exclusive(directory / 'v60-full-flash-before.bin', live)
    write_exclusive(directory / 'v60-rollback-block-060000.bin', old_block)
    write_exclusive(directory / 'v63c-candidate-block-060000.bin', new_block)
    write_exclusive(directory / 'manifest.json', (json.dumps(manifest(live, proposed), indent=2, sort_keys=True) + '\n').encode('ascii'))
    if hasattr(os, 'sync'):
        os.sync()
    verify_session(directory)
    return directory


def verify_session(directory):
    meta = json.loads((directory / 'manifest.json').read_text(encoding='ascii'))
    if meta.get('format') != FORMAT or meta.get('flash_before_sha256') != BEFORE_FLASH_SHA:
        raise ValueError('Wrong session format or previous flash')
    before = (directory / 'v60-full-flash-before.bin').read_bytes()
    old = (directory / 'v60-rollback-block-060000.bin').read_bytes()
    after = (directory / 'v63c-candidate-block-060000.bin').read_bytes()
    check_bytes('session full-flash backup', before, FLASH_SIZE, BEFORE_FLASH_SHA)
    check_bytes('session rollback block', old, BLOCK_SIZE, BEFORE_BLOCK_SHA)
    check_bytes('session candidate block', after, BLOCK_SIZE, AFTER_BLOCK_SHA)
    if before[BLOCK_BASE:BLOCK_BASE + BLOCK_SIZE] != old:
        raise ValueError('Saved block and full-flash baseline disagree')
    proposed = before[:BLOCK_BASE] + after + before[BLOCK_BASE + BLOCK_SIZE:]
    if meta != manifest(before, proposed):
        raise ValueError('Saved manifest or proposed flash tampered')
    return before, proposed, old, after


def verify_outside_block(observed, baseline):
    if observed[:BLOCK_BASE] != baseline[:BLOCK_BASE] or observed[BLOCK_BASE + BLOCK_SIZE:] != baseline[BLOCK_BASE + BLOCK_SIZE:]:
        raise ValueError('Protected flash differs; automatic restoration prohibited')


def write_one_block(hw, loader, payload_path):
    if payload_path.stat().st_size != BLOCK_SIZE or payload_path.suffix != '.bin':
        raise ValueError('Write payload must be exactly 64 KiB .bin')
    command = hw.jtag_cmd(loader, 100) + ['-f', '--verify', '--offset', str(BLOCK_BASE), str(payload_path)]
    # Production adapter must translate only disk-file arguments at .exe boundary.
    hw.call(command, timeout=600)


def phase(directory, state):
    path = directory / 'state.json'
    tmp = directory / 'state.json.tmp'
    with tmp.open('w', encoding='ascii', newline='\n') as f:
        json.dump({'format': FORMAT, 'phase': state}, f, sort_keys=True)
        f.write('\n')
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)


def read_full(hw, loader):
    return hw.read_region(loader, 100, 0, FLASH_SIZE)


def restore(hw, loader, directory):
    before, _, old, _ = verify_session(directory)
    observed = read_full(hw, loader)
    verify_outside_block(observed, before)
    phase(directory, 'RESTORE_STARTED')
    write_one_block(hw, loader, directory / 'v60-rollback-block-060000.bin')
    block = hw.read_region(loader, 100, BLOCK_BASE, BLOCK_SIZE)
    if block != old:
        raise ValueError('Restored v60 block readback mismatch')
    check_bytes('restored complete v60 flash', read_full(hw, loader), FLASH_SIZE, BEFORE_FLASH_SHA)
    phase(directory, 'V60_RESTORED_FULL_FLASH_VERIFIED')
    print('[PASS] Exact v60 full-flash image restored; v41 sector unchanged')


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    mode = ap.add_mutually_exclusive_group()
    mode.add_argument('--read-only', action='store_true', help='Read entire current flash; no writes')
    mode.add_argument('--install', action='store_true', help='Explicitly install one 64 KiB A/B block')
    mode.add_argument('--restore-session', type=Path, metavar='DIR', help='Explicitly restore exact v60 block from saved session')
    ap.add_argument('--candidate', type=Path, help='Exact .bit from your real v63c PACK-ONLY directory')
    ap.add_argument('--v60-primary', type=Path, default=SRC)
    ap.add_argument('--v60-region', type=Path, default=V60_REGION)
    ap.add_argument('--loader', type=Path, default=LOADER)
    ap.add_argument('--confirm', default='')
    args = ap.parse_args(argv)
    try:
        if args.install and args.confirm != INSTALL_ACK:
            raise ValueError('Install blocked: requires exact --confirm ' + INSTALL_ACK)
        if args.restore_session and args.confirm != RESTORE_ACK:
            raise ValueError('Restore blocked: requires exact --confirm ' + RESTORE_ACK)
        if not (args.install or args.restore_session) and args.confirm:
            raise ValueError('Confirmation disallowed for read-only or offline mode')
        if args.candidate is None:
            raise ValueError('Explicit --candidate path is required (original real-gmpack v63c .bit)')
        base = args.v60_primary.read_bytes()
        cand = args.candidate.read_bytes()
        region = args.v60_region.read_bytes()
        old, new = inspect_candidate(base, cand, region)
        print('[PASS] Exact pinned v60 baseline and 3-byte v63c change; single 64 KiB block only', flush=True)
        if not (args.install or args.read_only or args.restore_session):
            print('[OFFLINE PASS] No hardware access or flash write. Candidate not yet physically qualified.')
            return 0
        hw = hw_adapter()
        hw.check_loader(args.loader)
        hw.detect(args.loader, 100)
        if args.restore_session:
            directory = args.restore_session.resolve()
            if directory.parent != BUILD.resolve():
                raise ValueError('Session must be direct child of bootloader-serv/build-ulx5m-gs')
            hw.windows_file_argument(directory)
            restore(hw, args.loader, directory)
            return 0
        live = read_full(hw, args.loader)
        if args.read_only:
            if sha(live) == BEFORE_FLASH_SHA:
                qualify_live(live, region, old, new)
                print('[PASS] Physical 4 MiB flash is original installed v60 + v41; no writes')
            else:
                if live[:BLOCK_BASE] != region[:BLOCK_BASE] or live[BLOCK_BASE + BLOCK_SIZE:REGION_SIZE] != region[BLOCK_BASE + BLOCK_SIZE:]:
                    raise ValueError('Installed flash not the pinned v60 region outside A/B block')
                # Read-only case: report v63c candidate when the expected one-block delta is proven.
                proposed = bytearray(live)
                proposed[BLOCK_BASE:BLOCK_BASE + BLOCK_SIZE] = old
                base_flash = bytes(proposed)
                proposed_full = qualify_live(base_flash, region, old, new)
                if live != proposed_full:
                    raise ValueError('Physical flash neither exact v60 nor exact v63c candidate')
                print('[PASS] Physical 4 MiB flash is exact v63c A/B candidate; no writes')
            return 0
        proposed = qualify_live(live, region, old, new)
        directory = new_session()
        hw.windows_file_argument(directory.parent)
        save_session(directory, live, proposed, old, new)
        print('[RECOVERY] Exact full-chip backup and v60 rollback saved: %s' % directory, flush=True)
        try:
            phase(directory, 'V60_VERIFIED_WRITE_STARTING')
            write_one_block(hw, args.loader, directory / 'v63c-candidate-block-060000.bin')
            if hw.read_region(args.loader, 100, BLOCK_BASE, BLOCK_SIZE) != new:
                raise ValueError('Candidate 64 KiB independent readback mismatch')
            if read_full(hw, args.loader) != proposed:
                raise ValueError('Candidate full-chip independent readback mismatch')
            phase(directory, 'V63C_FLASH_VERIFIED_HARDWARE_HANDOFF_UNTESTED')
            print('[PASS] Exact v63c A/B candidate installed and 4 MiB verified; secondary takeover not yet tested')
            print('[RECOVERY] Preserve session: %s' % directory)
            return 0
        except (Exception, KeyboardInterrupt) as exc:
            print('[WRITE FAILED] %s. Attempting exact v60 restoration.' % exc, file=sys.stderr, flush=True)
            try:
                restore(hw, args.loader, directory)
            except (Exception, KeyboardInterrupt) as restore_exc:
                phase(directory, 'CRITICAL_RESTORE_UNVERIFIED')
                print('[CRITICAL] Restoration NOT verified: %s' % restore_exc, file=sys.stderr)
                print('[CRITICAL] Do not cold-boot SPI-active; preserve %s' % directory, file=sys.stderr)
            return 1
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as exc:
        print('[FAIL] %s' % exc, file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
