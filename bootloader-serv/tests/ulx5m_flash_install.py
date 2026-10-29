#!/usr/bin/env python3
"""Guarded ULX5M-GS primary flash installer. Run from bootloader-serv.

Never writes without an explicit confirmation. Uses a locally qualified,
image-derived PACK-ONLY bitstream, two identical full-chip backups, and
whole-chip post-write verification. Secondary/factory sectors are untouched.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build-ulx5m-gs'
RUN = BUILD / 'bootloader'
BIT = RUN / 'top_ulx5m_gs_bootloader-PACK-ONLY.bit'
STAMP = RUN / 'build.ok'
FLASH_SIZE = 0x400000
PRIMARY_SIZE = 0x80000
FLASH_READ_CHUNK = 0x20000
SECONDARY = 0x201000
CONFIRM_INSTALL = 'I_AUTHORIZE_ULX5M_PRIMARY_512K_WITH_VERIFIED_ROLLBACK'
CONFIRM_RESTORE = 'I_AUTHORIZE_ULX5M_PRIMARY_512K_ROLLBACK'
PROGRAMMER = (ROOT / '../bin/openFPGALoader.exe').resolve()


def digest(data):
    return hashlib.sha256(data).hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def candidate():
    stamp = json.loads(STAMP.read_text(encoding='ascii'))
    seed = stamp['seed']
    require(type(seed) is int and seed >= 0, 'invalid build seed')
    image = BIT.read_bytes()
    require(10000 <= len(image) <= PRIMARY_SIZE,
            'packed bitstream does not fit the 512 KiB primary partition')
    require(stamp['sha256'] == digest(image), 'candidate does not match build.ok')
    # Invoke the existing canonical qualifier (includes command ROM, timing,
    # source fingerprints and flash pinout). Never substitute sweep results.
    subprocess.run(['make', '-f', 'Makefile.ulx5m-gs', 'qualify',
                    'SEED=%d' % seed], cwd=ROOT, check=True)
    return image, seed


def expected_flash(original, image):
    require(len(original) == FLASH_SIZE, 'expected 4 MiB pre-install dump')
    require(10000 <= len(image) <= PRIMARY_SIZE, 'invalid primary size')
    require(any(b != 0xff for b in original[SECONDARY:SECONDARY + 256]),
            'secondary at 0x201000 appears erased; refusing primary update')
    return image.ljust(PRIMARY_SIZE, b'\xff') + original[PRIMARY_SIZE:]


def safe_session(path):
    session = Path(path).resolve()
    require(session.parent == BUILD.resolve() and session.name.startswith('flash-install-'),
            'recovery session must be directly under build-ulx5m-gs/flash-install-*')
    return session


def load_backups(session):
    meta = json.loads((session / 'manifest.json').read_text(encoding='ascii'))
    a = (session / 'flash-before-a.bin').read_bytes()
    b = (session / 'flash-before-b.bin').read_bytes()
    require(len(a) == FLASH_SIZE and a == b, 'full-chip recovery backups differ')
    require(digest(a) == meta['original_sha256'], 'recovery backup checksum mismatch')
    return a, meta


def winpath(path):
    return subprocess.check_output(['wslpath', '-w', str(path.resolve())],
                                   text=True).strip()


def jtag(*options):
    require(PROGRAMMER.is_file(), 'Windows openFPGALoader.exe missing: %s' % PROGRAMMER)
    cmd = [str(PROGRAMMER), '-c', 'tigard', '--freq', '1000k', *options]
    print('[JTAG]', ' '.join(cmd), flush=True)
    subprocess.run(cmd, cwd=ROOT, check=True)


def detect():
    require(PROGRAMMER.is_file(), 'openFPGALoader.exe is missing')
    cmd = [str(PROGRAMMER), '-c', 'tigard', '--freq', '1000k', '--detect']
    result = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True,
                            check=True)
    print(result.stdout, end='')
    require('0x20000001' in (result.stdout + result.stderr).lower(),
            'incorrect/missing GateMate JTAG IDCODE; do not write flash')


def dump(path):
    # openFPGALoader v1.2.0 uses two variable-length stack buffers for a
    # single SPI read. A full-chip dump can exhaust the Windows stack.
    # Read bounded, offset-addressed chunks and publish the result only
    # after every chunk has the expected length.
    part = path.with_name(path.name + '.partial')
    chunk = path.with_name(path.name + '.chunk')
    for temp in (part, chunk):
        if temp.exists():
            temp.unlink()
    if path.exists():
        path.unlink()
    try:
        with part.open('wb') as out:
            for offset in range(0, FLASH_SIZE, FLASH_READ_CHUNK):
                length = min(FLASH_READ_CHUNK, FLASH_SIZE - offset)
                try:
                    jtag('--dump-flash', '--file-size', str(length), '-o', str(offset),
                         winpath(chunk))
                except subprocess.CalledProcessError as exc:
                    raise ValueError('flash dump failed at offset 0x%06x (exit %d)' %
                                     (offset, exc.returncode)) from exc
                require(chunk.is_file() and chunk.stat().st_size == length,
                        'flash read failed at offset 0x%06x: expected %d bytes' %
                        (offset, length))
                with chunk.open('rb') as source:
                    data = source.read()
                require(len(data) == length,
                        'short flash read at offset 0x%06x' % offset)
                out.write(data)
                chunk.unlink()
                if (offset + length) % 0x100000 == 0 or offset + length == FLASH_SIZE:
                    print('[READ] %d/%d flash bytes' % (offset + length, FLASH_SIZE),
                          flush=True)
            out.flush()
            os.fsync(out.fileno())
        require(part.stat().st_size == FLASH_SIZE,
                'incomplete 4 MiB flash backup: %s' % path)
        part.replace(path)
        return path.read_bytes()
    finally:
        for temp in (part, chunk):
            if temp.exists():
                temp.unlink()


def program(path):
    require(path.stat().st_size == PRIMARY_SIZE,
            'refusing to write anything other than exactly 512 KiB')
    jtag('-f', '-o', '0', winpath(path))


def unique_session():
    name = 'flash-install-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    session = BUILD / name
    session.mkdir(parents=True, exist_ok=False)
    return session


def backup(session):
    a = dump(session / 'flash-before-a.bin')
    b = dump(session / 'flash-before-b.bin')
    require(a == b, 'the two complete flash reads differ; no write performed')
    require(any(v != 0xff for v in a[:256]), 'primary appears erased; do not install')
    print('[PASS] matching 4 MiB pre-install dumps:', digest(a))
    return a


def save_manifest(session, original, image, seed):
    record = {
        'flash_bytes': FLASH_SIZE,
        'primary_bytes': PRIMARY_SIZE,
        'secondary_address': SECONDARY,
        'seed': seed,
        'image_bytes': len(image),
        'image_sha256': digest(image),
        'original_sha256': digest(original),
        'state': 'BACKED_UP_NOT_WRITTEN',
    }
    (session / 'manifest.json').write_text(
        json.dumps(record, indent=2, sort_keys=True) + '\n', encoding='ascii')
    return record


def state(session, record, value):
    record['state'] = value
    (session / 'manifest.json').write_text(
        json.dumps(record, indent=2, sort_keys=True) + '\n', encoding='ascii')


def install():
    image, seed = candidate()
    detect()
    session = unique_session()
    print('[RECOVERY] Session:', session, flush=True)
    original = backup(session)
    expected = expected_flash(original, image)
    record = save_manifest(session, original, image, seed)
    payload = session / 'primary-new.bin'
    payload.write_bytes(expected[:PRIMARY_SIZE])
    require(payload.stat().st_size == PRIMARY_SIZE, 'incomplete primary payload')
    print('[READY] Only 0x000000..0x07ffff may change; flash at/after 0x080000 is protected')
    print('[READY] New image: %d bytes SHA256 %s' % (len(image), digest(image)))
    print('[READY] Recovery backups are retained at', session, flush=True)
    state(session, record, 'WRITE_ATTEMPTED')
    try:
        program(payload)
        after = dump(session / 'flash-after.bin')
        if after == expected:
            state(session, record, 'INSTALLED_FULL_CHIP_VERIFIED')
            print('[PASS] Full 4 MiB readback matches expected; non-primary bytes unchanged')
            print('[PASS] Primary SHA256:', digest(after[:PRIMARY_SIZE]))
            print('[RECOVERY] Backup:', session)
            return
        if after[PRIMARY_SIZE:] != original[PRIMARY_SIZE:]:
            state(session, record, 'RECOVERY_REQUIRED_PROTECTED_REGION_CHANGED')
            print('[CRITICAL] Protected flash region changed; refusing any further automatic writes',
                  file=sys.stderr)
            raise RuntimeError('Protected region differs; recovery requires separate analysis: %s' % session)
        raise ValueError('primary verification mismatch; attempting primary-only rollback')
    except (subprocess.CalledProcessError, OSError, ValueError) as exc:
        print('[FAIL] install incomplete:', exc, file=sys.stderr, flush=True)
        print('[RECOVERY] Attempting rollback of original 512 KiB primary', flush=True)
        old = session / 'primary-original.bin'
        old.write_bytes(original[:PRIMARY_SIZE])
        try:
            detect()
            program(old)
            recovered = dump(session / 'flash-rollback-check.bin')
            require(recovered == original, 'full-chip recovery verification mismatch')
            state(session, record, 'ROLLED_BACK_FULL_CHIP_VERIFIED')
            print('[PASS] Full 4 MiB flash restored and verified')
        except (subprocess.CalledProcessError, OSError, ValueError) as restore_exc:
            state(session, record, 'RECOVERY_REQUIRED')
            raise ValueError('INSTALL FAILED; AUTOMATIC ROLLBACK FAILED: %s; '
                             'recovery files at %s' % (restore_exc, session)) from restore_exc
        raise ValueError('install failed but original flash was restored: %s' % exc) from exc


def restore(session):
    session = safe_session(session)
    original, record = load_backups(session)
    detect()
    now = dump(session / 'flash-before-restore.bin')
    if now == original:
        print('[PASS] Original 4 MiB flash already installed; no write needed')
        return
    require(now[PRIMARY_SIZE:] == original[PRIMARY_SIZE:],
            'protected flash differs from backup; refusing primary-only restore')
    old = session / 'primary-original.bin'
    old.write_bytes(original[:PRIMARY_SIZE])
    state(session, record, 'ROLLBACK_WRITE_ATTEMPTED')
    program(old)
    recovered = dump(session / 'flash-rollback-check.bin')
    require(recovered == original, 'rollback full-chip readback mismatch; recovery still required')
    state(session, record, 'ROLLED_BACK_FULL_CHIP_VERIFIED')
    print('[PASS] Original 4 MiB flash restored byte-for-byte')


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    modes = p.add_subparsers(dest='mode', required=True)
    modes.add_parser('preflight', help='Offline qualify local bitstream, no hardware access')
    install_parser = modes.add_parser('install', help='Back up, guarded-write, verify and roll back on failure')
    install_parser.add_argument('--confirm', required=True)
    restore_parser = modes.add_parser('restore', help='Restore from retained full-chip backups')
    restore_parser.add_argument('--session', required=True)
    restore_parser.add_argument('--confirm', required=True)
    args = p.parse_args(argv)
    try:
        if args.mode == 'preflight':
            image, seed = candidate()
            print('[PASS] Offline-qualified seed %d: %d bytes; SHA256 %s' %
                  (seed, len(image), digest(image)))
            print('[SAFETY] No hardware was accessed')
        elif args.mode == 'install':
            require(args.confirm == CONFIRM_INSTALL, 'explicit install authorization missing')
            install()
        else:
            require(args.confirm == CONFIRM_RESTORE, 'explicit rollback authorization missing')
            restore(args.session)
    except (OSError, ValueError, subprocess.CalledProcessError, KeyError,
            TypeError, RuntimeError) as exc:
        print('[FAIL]', exc, file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
