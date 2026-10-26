#!/usr/bin/env python3
"""Qualify/optionally install the pinned v50 seed-7 SPI-primary at flash zero.

Default and --read-only never write flash. --install and --restore-session need
explicit acknowledgement. Requires v52 preparation and v54 JTAG readback code.
Never run against a different flash layout, bitstream or JTAG chain.
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
PREP = BUILD / 'v52-spi-primary-prep'
PRIMARY = BUILD / 'normal-boot-dfu-hw-native' / 'spi-secondary-spi-primary-seed7.bit'
ACK = 'I_ACCEPT_FLASH_ZERO_448K_INSTALL_AND_RECOVERY_RISK'
RESTORE_ACK = 'I_ACCEPT_RESTORE_FACTORY_FLASH_ZERO_RISK'
BLOCK = 0x10000
REGION = 0x70000
SECONDARY = 0x201000
FORMAT = 'ULX5M-GS-V55-SPI-PRIMARY-INSTALL-V1'


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    obj = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(obj)
    return obj


hw = load('v55_jtag_hw', HERE / 'qualify-ulx5m-serv-jtag-write.py')
prep = load('v55_primary_prep', HERE / 'prepare-ulx5m-v52-spi-primary.py')
inspector = load('v55_trailer_inspector', HERE / 'inspect-ulx5m-v47-primary.py')


def sha(data):
    return hashlib.sha256(data).hexdigest()


def assert_equal(name, actual, expected):
    if actual != expected:
        raise ValueError('%s mismatch: expected SHA-256 %s, got %s' %
                         (name, sha(expected), sha(actual)))
    print('[PASS] %s, %d bytes, SHA-256 %s' % (name, len(actual), sha(actual)), flush=True)


def unique_session_dir():
    dt = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    return BUILD / ('v55-spi-install-%s-%d' % (dt, os.getpid()))


def prepare_evidence(primary_path, prep_dir, backup_dir, sector_path, loader):
    # Entirely offline: reject stale, unrelated or modified input files.
    factory, backup_sha = hw.verified_backup(backup_dir)
    app_sector = hw.verified_app_sector(sector_path)
    primary_raw = primary_path.read_bytes()
    count, primary_sha = inspector.inspect(primary_path)
    if count != prep.PRIMARY_BYTES or primary_sha != prep.PRIMARY_SHA:
        raise ValueError('Local primary differs from hardware-qualified v50 seed 7')
    proposed, original, expected_manifest = prep.build(primary_raw, factory, factory, app_sector)
    if not prep_dir.is_dir():
        raise ValueError('Missing v52 preparation directory: %s' % prep_dir)
    assert_equal('prepared primary', (prep_dir / 'PROPOSED-primary-000000-06ffff.bin').read_bytes(), proposed)
    assert_equal('prepared restore region', (prep_dir / 'RESTORE-factory-000000-06ffff.bin').read_bytes(), original)
    manifest = json.loads((prep_dir / 'preparation.json').read_text(encoding='ascii'))
    if manifest != expected_manifest:
        raise ValueError('Prepared v52 manifest mismatch; no hardware access')
    if REGION != len(proposed) or REGION != len(original):
        raise ValueError('Unsafe region size')
    live_expected = hw.expected_current_flash(factory, app_sector)
    installed_expected = bytearray(live_expected)
    installed_expected[:REGION] = proposed
    installed_expected = bytes(installed_expected)
    if sha(installed_expected) != manifest['expected_full_flash_sha256_after_controlled_install']:
        raise ValueError('Full-flash expected digest mismatch')
    hw.check_loader(loader)
    return {
        'primary': proposed, 'factory_region': original,
        'factory_flash_expected': live_expected, 'installed_flash_expected': installed_expected,
        'backup_sha': backup_sha, 'primary_sha': primary_sha,
        'app_sector': app_sector,
    }


def block_write_cmd(loader, offset, payload):
    if offset < 0 or offset >= REGION or offset % BLOCK or payload.stat().st_size != BLOCK:
        raise ValueError('Refusing unaligned/out-of-bounds flash block write')
    if payload.suffix != '.bin':
        raise ValueError('Flash block must be a raw .bin file')
    # Only region-limited JTAG-SPI write; never chip erase/unprotect.
    return hw.jtag_cmd(loader, 100) + ['-f', '--verify', '--offset', str(offset), str(payload)]


def write_region(loader, target, data):
    if len(data) != REGION:
        raise ValueError('Refusing write outside pinned 448 KiB primary region')
    # Each command touches exactly one aligned 64 KiB block.  Preserve all
    # 0x064000..0x06ffff factory data inside the final block.
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


def write_create_only(path, data):
    with path.open('xb') as f:
        f.write(data)
        f.flush()
        os.fsync(f.fileno())


def save_session(directory, evidence):
    directory.mkdir(parents=False, exist_ok=False)
    write_create_only(directory / 'factory-region-000000-06ffff.bin', evidence['factory_region'])
    write_create_only(directory / 'primary-region-000000-06ffff.bin', evidence['primary'])
    record = {
        'format': FORMAT,
        'backup_sha256': evidence['backup_sha'],
        'primary_sha256': evidence['primary_sha'],
        'factory_region_sha256': sha(evidence['factory_region']),
        'primary_region_sha256': sha(evidence['primary']),
        'expected_original_flash_sha256': sha(evidence['factory_flash_expected']),
        'expected_installed_flash_sha256': sha(evidence['installed_flash_expected']),
        'region_offset': 0, 'region_length': REGION,
        'secondary_offset': SECONDARY,
    }
    write_create_only(directory / 'manifest.json', (json.dumps(record, indent=2, sort_keys=True) + '\n').encode('ascii'))
    os.sync() if hasattr(os, 'sync') else None
    print('[SAVED] Recovery images and manifest: %s' % directory, flush=True)


def verify_session(directory, evidence):
    meta = json.loads((directory / 'manifest.json').read_text('ascii'))
    expected = {
        'format': FORMAT,
        'backup_sha256': evidence['backup_sha'],
        'primary_sha256': evidence['primary_sha'],
        'factory_region_sha256': sha(evidence['factory_region']),
        'primary_region_sha256': sha(evidence['primary']),
        'expected_original_flash_sha256': sha(evidence['factory_flash_expected']),
        'expected_installed_flash_sha256': sha(evidence['installed_flash_expected']),
        'region_offset': 0, 'region_length': REGION,
        'secondary_offset': SECONDARY,
    }
    if meta != expected:
        raise ValueError('Saved session manifest mismatch')
    assert_equal('saved original', (directory / 'factory-region-000000-06ffff.bin').read_bytes(), evidence['factory_region'])
    assert_equal('saved primary', (directory / 'primary-region-000000-06ffff.bin').read_bytes(), evidence['primary'])


def verify_whole_flash(loader, expected, label):
    actual = hw.read_region(loader, 100, 0, hw.FLASH_BYTES)
    assert_equal(label, actual, expected)


def report_phase(directory, value):
    # Overwrite *only* our state marker; never source or recovery images.
    tmp = directory / 'state.json.tmp'
    final = directory / 'state.json'
    with tmp.open('w', encoding='ascii', newline='\n') as f:
        json.dump({'phase': value, 'format': FORMAT}, f, sort_keys=True)
        f.write('\n')
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, final)


def restore_all(loader, directory, evidence):
    verify_session(directory, evidence)
    print('[RESTORE] Original factory primary region 0x000000..0x06ffff', flush=True)
    write_region(loader, ensure_blocks_dir(directory, 'restore-blocks'), evidence['factory_region'])
    verify_whole_flash(loader, evidence['factory_flash_expected'], 'restored full flash')
    report_phase(directory, 'FACTORY_PRIMARY_RESTORED_VERIFIED')
    print('[PASS] Factory primary restored; v41 secondary preserved')


def ensure_blocks_dir(directory, name):
    dest = directory / name
    dest.mkdir(exist_ok=True)
    return dest


def install(loader, evidence):
    # Save recovery files BEFORE the first flash mutation.
    directory = unique_session_dir()
    save_session(directory, evidence)
    verify_session(directory, evidence)
    hw.windows_file_argument(directory)  # Require Windows-writable storage before mutation.
    hw.detect(loader, 100)
    verify_whole_flash(loader, evidence['factory_flash_expected'], 'unmodified flash before install')
    report_phase(directory, 'ORIGINAL_FULL_FLASH_VERIFIED_NO_WRITE_YET')
    print('[RECOVERY] Restore session: %s' % directory, flush=True)
    try:
        report_phase(directory, 'PRIMARY_WRITE_STARTED')
        write_region(loader, ensure_blocks_dir(directory, 'primary-blocks'), evidence['primary'])
        verify_whole_flash(loader, evidence['installed_flash_expected'], 'installed full flash')
        report_phase(directory, 'PRIMARY_INSTALLED_AND_FULL_FLASH_VERIFIED')
        print('[PASS] PRIMARY INSTALLED; cold SPI-active boot and BTN2 recovery NOT YET TESTED')
        print('[RECOVERY] Preserve: %s' % directory)
        return 0
    except (OSError, ValueError, KeyboardInterrupt) as exc:
        print('[WRITE FAILED] %s. Attempting factory-primary restoration.' % exc, file=sys.stderr, flush=True)
        try:
            report_phase(directory, 'RESTORATION_STARTED')
            restore_all(loader, directory, evidence)
            print('[FAIL] Installation failed; factory primary was restored and verified', file=sys.stderr)
        except (OSError, ValueError, KeyboardInterrupt) as restore_exc:
            report_phase(directory, 'CRITICAL_RESTORE_UNVERIFIED')
            print('[CRITICAL] Restoration NOT verified: %s' % restore_exc, file=sys.stderr)
            print('[CRITICAL] Do not cold boot SPI-active. Preserve session: %s' % directory, file=sys.stderr)
        return 1


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    mode = ap.add_mutually_exclusive_group()
    mode.add_argument('--read-only', action='store_true', help='Full-chip flash comparison; never writes')
    mode.add_argument('--install', action='store_true', help='Modify first 448 KiB of SPI flash')
    mode.add_argument('--restore-session', type=Path, metavar='DIR', help='Restore original factory primary from saved v55 session')
    ap.add_argument('--confirm', default='', help='Exact acknowledgement for --install or --restore-session')
    ap.add_argument('--primary', type=Path, default=PRIMARY)
    ap.add_argument('--prep-dir', type=Path, default=PREP)
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
        evidence = prepare_evidence(args.primary, args.prep_dir, args.backup_dir, args.sector_dump, args.loader)
        print('[PASS] Verified pinned primary, factory backups, secondary and v52 preparation', flush=True)
        if not args.read_only and not args.install and not args.restore_session:
            print('[DRY RUN] No hardware accessed. Use --read-only for full flash comparison.')
            return 0
        if args.install or args.restore_session:
            hw.windows_file_argument(BUILD)
        hw.detect(args.loader, 100)
        if args.read_only:
            live = hw.read_region(args.loader, 100, 0, hw.FLASH_BYTES)
            if live == evidence['factory_flash_expected']:
                print('[PASS] Current flash is factory-primary plus verified v41 application')
            elif live == evidence['installed_flash_expected']:
                print('[PASS] Current flash is installed v55 primary plus verified v41 application')
            else:
                raise ValueError('Current full flash matches neither approved image; no write permitted')
            return 0
        if args.restore_session:
            directory = args.restore_session.resolve()
            if not directory.is_dir() or directory.parent != BUILD.resolve():
                raise ValueError('Restore session must be directly under project build-ulx5m-gs')
            verify_session(directory, evidence)
            ensure_blocks_dir(directory, 'restore-blocks')
            restore_all(args.loader, directory, evidence)
            return 0
        return install(args.loader, evidence)
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as exc:
        print('[FAIL] %s' % exc, file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
