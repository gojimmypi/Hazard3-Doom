#!/usr/bin/env python3
"""Guarded ULX5M-GS v55 -> v60 seed-302 SPI-primary replacement.

Default is offline; --read-only reads flash without modifying it. Installation
requires an explicit acknowledgement and verifies all 4 MiB before and after
writing seven bounded 64 KiB blocks. Failed installation attempts to restore
v55, not the original factory primary. Requires existing v54 JTAG helpers.
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
PRIMARY = BUILD / 'normal-boot-dfu-hw-native' / 'spi-secondary-spi-primary-seed302.bit'
V55_REGION = BUILD / 'v52-spi-primary-prep' / 'PROPOSED-primary-000000-06ffff.bin'
ACK = 'I_ACCEPT_V60_SEED302_FLASH_ZERO_448K_INSTALL_AND_V55_ROLLBACK_RISK'
RESTORE_ACK = 'I_ACCEPT_V55_SPI_PRIMARY_RESTORE_RISK'
BLOCK = 0x10000
REGION = 0x70000
SECTOR = 0x1000
SECONDARY = 0x201000
PADDING_END = 0x6e000
PRIMARY_BYTES = 446729
PRIMARY_SHA = '5a0c926ae560810800ccc9d864a970c8942863dfba22a42b8a53f519c1914b75'
V55_REGION_SHA = '1f754fffca317d02df5f831d79afc174492fc7b6aa200fab2a3755b65a99e8d5'
V55_FLASH_SHA = 'bf0db6395ac728aa51c424052087e627b51163941530b5419e2f5c41e490fc28'
FORMAT = 'ULX5M-GS-V62-V60-SEED302-INSTALL-V1'


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    obj = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(obj)
    return obj


hw = load('v62_jtag_hw', HERE / 'qualify-ulx5m-serv-jtag-write.py')
inspector = load('v62_primary_inspector', HERE / 'inspect-ulx5m-v47-primary.py')


def sha(data):
    return hashlib.sha256(data).hexdigest()


def assert_equal(name, actual, expected):
    if actual != expected:
        raise ValueError('%s mismatch: expected SHA-256 %s, got %s' %
                         (name, sha(expected), sha(actual)))
    print('[PASS] %s, %d bytes, SHA-256 %s' % (name, len(actual), sha(actual)), flush=True)


def unique_session_dir():
    dt = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    return BUILD / ('v62-spi-update-%s-%d' % (dt, os.getpid()))


def prepare_evidence(primary_path, v55_region_path, backup_dir, sector_path, loader):
    # All evidence is pinned before any hardware access or session creation.
    factory, backup_sha = hw.verified_backup(backup_dir)
    app_sector = hw.verified_app_sector(sector_path)
    bit = primary_path.read_bytes()
    count, primary_sha = inspector.inspect(primary_path)
    if count != PRIMARY_BYTES or primary_sha != PRIMARY_SHA:
        raise ValueError('Candidate primary is not the pinned local v60 seed-302 build')
    if PADDING_END != (PRIMARY_BYTES + SECTOR - 1) // SECTOR * SECTOR:
        raise ValueError('Primary erase padding calculation changed')
    if PADDING_END > REGION or REGION != BLOCK * 7 or REGION >= SECONDARY:
        raise ValueError('Unsafe primary region geometry')
    v55 = v55_region_path.read_bytes()
    if len(v55) != REGION or sha(v55) != V55_REGION_SHA:
        raise ValueError('v55 rollback-region size/SHA-256 mismatch')
    if v55[0x64000:] != factory[0x64000:REGION]:
        raise ValueError('v55 preserved factory tail mismatch')
    if bit[:4] != bytes.fromhex('d901ed96'):
        raise ValueError('Invalid GateMate primary header')
    # The new bitstream extends past v55's 0x64000 erasure boundary.
    # Erase/pad up to 0x6e000; retain factory data from 0x6e000 to 0x70000.
    candidate = bit + b'\xff' * (PADDING_END - len(bit)) + factory[PADDING_END:REGION]
    if len(candidate) != REGION or candidate[PADDING_END:] != factory[PADDING_END:REGION]:
        raise ValueError('Unsafe candidate or factory tail length')
    base = bytearray(hw.expected_current_flash(factory, app_sector))
    base[:REGION] = v55
    current = bytes(base)
    if sha(current) != V55_FLASH_SHA:
        raise ValueError('Factory backup, app and v55 image disagree with installed flash digest')
    base[:REGION] = candidate
    proposed = bytes(base)
    if proposed[REGION:] != current[REGION:] or proposed[SECONDARY:SECONDARY + SECTOR] != app_sector:
        raise ValueError('Candidate would modify protected flash or the secondary application')
    hw.check_loader(loader)
    print('[PASS] pinned v60 seed-302 primary: %d bytes, SHA-256 %s' %
          (len(bit), primary_sha), flush=True)
    print('[PASS] proposed 448 KiB region: SHA-256 %s' % sha(candidate), flush=True)
    print('[PASS] expected full flash after update: SHA-256 %s' % sha(proposed), flush=True)
    return {
        'primary': candidate, 'rollback_region': v55,
        'current_flash_expected': current, 'candidate_flash_expected': proposed,
        'backup_sha': backup_sha, 'primary_sha': primary_sha, 'app_sector': app_sector,
    }


def block_write_cmd(loader, offset, payload):
    if offset < 0 or offset >= REGION or offset % BLOCK or payload.stat().st_size != BLOCK:
        raise ValueError('Refusing unaligned/out-of-bounds flash block write')
    if payload.suffix != '.bin':
        raise ValueError('Flash block must be a raw .bin file')
    return hw.jtag_cmd(loader, 100) + ['-f', '--verify', '--offset', str(offset), str(payload)]


def write_create_only(path, data):
    with path.open('xb') as f:
        f.write(data)
        f.flush()
        os.fsync(f.fileno())


def ensure_blocks_dir(directory, name):
    dest = directory / name
    dest.mkdir(exist_ok=True)
    return dest


def write_region(loader, target, data):
    if len(data) != REGION:
        raise ValueError('Refusing write outside pinned 448 KiB primary region')
    for offset in range(0, REGION, BLOCK):
        part = data[offset:offset + BLOCK]
        path = target / ('block-%06x.bin' % offset)
        if path.is_file():
            assert_equal('stored block %06x' % offset, path.read_bytes(), part)
        else:
            write_create_only(path, part)
        print('[WRITE] 0x%06x..0x%06x' % (offset, offset + BLOCK - 1), flush=True)
        hw.call(block_write_cmd(loader, offset, path), timeout=600)
        got = hw.read_region(loader, 100, offset, BLOCK)
        assert_equal('block %06x readback' % offset, got, part)


def session_record(evidence):
    return {
        'format': FORMAT,
        'backup_sha256': evidence['backup_sha'],
        'primary_sha256': evidence['primary_sha'],
        'v55_rollback_region_sha256': sha(evidence['rollback_region']),
        'candidate_region_sha256': sha(evidence['primary']),
        'expected_v55_flash_sha256': sha(evidence['current_flash_expected']),
        'expected_candidate_flash_sha256': sha(evidence['candidate_flash_expected']),
        'region_offset': 0, 'region_length': REGION,
        'secondary_offset': SECONDARY,
    }


def save_session(directory, evidence):
    directory.mkdir(parents=False, exist_ok=False)
    write_create_only(directory / 'v55-rollback-region-000000-06ffff.bin', evidence['rollback_region'])
    write_create_only(directory / 'v60-candidate-region-000000-06ffff.bin', evidence['primary'])
    write_create_only(directory / 'manifest.json',
                      (json.dumps(session_record(evidence), indent=2, sort_keys=True) + '\n').encode('ascii'))
    if hasattr(os, 'sync'):
        os.sync()
    print('[SAVED] v55 rollback images and manifest: %s' % directory, flush=True)


def verify_session(directory, evidence):
    meta = json.loads((directory / 'manifest.json').read_text(encoding='ascii'))
    if meta != session_record(evidence):
        raise ValueError('Saved session manifest mismatch')
    assert_equal('saved v55 rollback', (directory / 'v55-rollback-region-000000-06ffff.bin').read_bytes(),
                 evidence['rollback_region'])
    assert_equal('saved v60 candidate', (directory / 'v60-candidate-region-000000-06ffff.bin').read_bytes(),
                 evidence['primary'])


def verify_whole_flash(loader, expected, label):
    actual = hw.read_region(loader, 100, 0, hw.FLASH_BYTES)
    assert_equal(label, actual, expected)


def report_phase(directory, value):
    tmp = directory / 'state.json.tmp'
    with tmp.open('w', encoding='ascii', newline='\n') as f:
        json.dump({'phase': value, 'format': FORMAT}, f, sort_keys=True)
        f.write('\n')
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, directory / 'state.json')


def restore_v55(loader, directory, evidence):
    verify_session(directory, evidence)
    print('[RESTORE] v55 primary 0x000000..0x06ffff', flush=True)
    write_region(loader, ensure_blocks_dir(directory, 'v55-restore-blocks'), evidence['rollback_region'])
    verify_whole_flash(loader, evidence['current_flash_expected'], 'restored full v55 flash')
    report_phase(directory, 'V55_PRIMARY_RESTORED_AND_FULL_FLASH_VERIFIED')
    print('[PASS] v55 primary restored; v41 secondary preserved', flush=True)


def install(loader, evidence):
    directory = unique_session_dir()
    save_session(directory, evidence)
    verify_session(directory, evidence)
    hw.windows_file_argument(directory)
    hw.detect(loader, 100)
    verify_whole_flash(loader, evidence['current_flash_expected'], 'installed v55 full flash before update')
    report_phase(directory, 'V55_FULL_FLASH_VERIFIED_NO_WRITE_YET')
    print('[RECOVERY] Preserve v55 rollback session: %s' % directory, flush=True)
    try:
        report_phase(directory, 'V60_PRIMARY_WRITE_STARTED')
        write_region(loader, ensure_blocks_dir(directory, 'v60-primary-blocks'), evidence['primary'])
        verify_whole_flash(loader, evidence['candidate_flash_expected'], 'installed v60 full flash')
        report_phase(directory, 'V60_INSTALLED_AND_FULL_FLASH_VERIFIED')
        print('[PASS] v60 PRIMARY INSTALLED; cold SPI-active boot and BTN2 recovery NOT YET TESTED')
        print('[RECOVERY] Preserve: %s' % directory)
        return 0
    except (OSError, ValueError, KeyboardInterrupt) as exc:
        print('[WRITE FAILED] %s. Attempting v55 restoration.' % exc, file=sys.stderr, flush=True)
        try:
            report_phase(directory, 'V55_RESTORATION_STARTED')
            restore_v55(loader, directory, evidence)
            print('[FAIL] v60 installation failed; v55 primary restored and verified', file=sys.stderr)
        except (OSError, ValueError, KeyboardInterrupt) as restore_exc:
            report_phase(directory, 'CRITICAL_V55_RESTORE_UNVERIFIED')
            print('[CRITICAL] v55 restoration NOT verified: %s' % restore_exc, file=sys.stderr)
            print('[CRITICAL] Do not cold boot SPI-active. Preserve session: %s' % directory,
                  file=sys.stderr)
        return 1


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    mode = ap.add_mutually_exclusive_group()
    mode.add_argument('--read-only', action='store_true', help='Read-only full-chip flash comparison')
    mode.add_argument('--install', action='store_true', help='Replace v55 primary in first 448 KiB')
    mode.add_argument('--restore-session', type=Path, metavar='DIR',
                      help='Restore v55 from a saved v62 session')
    ap.add_argument('--confirm', default='', help='Exact explicit acknowledgement for writing modes')
    ap.add_argument('--primary', type=Path, default=PRIMARY)
    ap.add_argument('--v55-region', type=Path, default=V55_REGION)
    ap.add_argument('--backup-dir', type=Path)
    ap.add_argument('--sector-dump', type=Path, default=BUILD / 'fwtn-jtag-201000-tailfix-4096.bin')
    ap.add_argument('--loader', type=Path, default=ROOT / 'bin' / 'openFPGALoader-v1.2.0.exe')
    args = ap.parse_args(argv)
    try:
        if args.install and args.confirm != ACK:
            raise ValueError('Installation blocked. Explicit --confirm %s required' % ACK)
        if args.restore_session and args.confirm != RESTORE_ACK:
            raise ValueError('Restoration blocked. Explicit --confirm %s required' % RESTORE_ACK)
        if not (args.install or args.restore_session) and args.confirm:
            raise ValueError('Unexpected confirmation in non-writing mode')
        if args.backup_dir is None:
            args.backup_dir = hw.discover_backup(ROOT)
        evidence = prepare_evidence(args.primary, args.v55_region, args.backup_dir,
                                    args.sector_dump, args.loader)
        print('[PASS] Verified pinned v60 primary, v55 baseline, dual backup, and v41 secondary',
              flush=True)
        if not (args.read_only or args.install or args.restore_session):
            print('[DRY RUN] No hardware accessed or flash modified. Use --read-only for JTAG preflight.')
            return 0
        if args.install or args.restore_session:
            hw.windows_file_argument(BUILD)
        hw.detect(args.loader, 100)
        if args.read_only:
            live = hw.read_region(args.loader, 100, 0, hw.FLASH_BYTES)
            if live == evidence['current_flash_expected']:
                print('[PASS] Current SPI flash is known v55 plus v41 application')
            elif live == evidence['candidate_flash_expected']:
                print('[PASS] Current SPI flash is known v60 seed-302 plus v41 application')
            else:
                raise ValueError('Flash matches neither approved image; no write permitted')
            return 0
        if args.restore_session:
            directory = args.restore_session.resolve()
            if not directory.is_dir() or directory.parent != BUILD.resolve():
                raise ValueError('Restore session must be directly under project build-ulx5m-gs')
            verify_session(directory, evidence)
            # A recovery may have an incomplete/erased primary block, but no
            # write is allowed if anything outside our primary region changed.
            live = hw.read_region(args.loader, 100, 0, hw.FLASH_BYTES)
            if live[REGION:] != evidence['current_flash_expected'][REGION:]:
                raise ValueError('Protected flash changed; v55 restore refused')
            restore_v55(args.loader, directory, evidence)
            return 0
        return install(args.loader, evidence)
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as exc:
        print('[FAIL] %s' % exc, file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
