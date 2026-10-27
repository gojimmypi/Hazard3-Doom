#!/usr/bin/env python3
"""Read-only, fail-closed audit of the *installed* ULX5M-GS v60 primary.

This validates the frozen v60 image and v62 installation artifacts and
identifies the missing configuration-bank transfer; it does NOT generate a
replacement image, operate CC_CFG_CTRL, or access any programmer/flash device.

The optional --current-flash path is a pre-existing local 4 MiB dump. It is
read only; no flash read is performed by this script.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build-ulx5m-gs'
SESSION = BUILD / 'v62-spi-update-20261027T034513196538Z-1776'
PRIMARY = BUILD / 'normal-boot-dfu-hw-native' / 'spi-secondary-spi-primary-seed302.bit'
REGION_FILE = SESSION / 'v60-candidate-region-000000-06ffff.bin'
ROLLBACK_FILE = SESSION / 'v55-rollback-region-000000-06ffff.bin'
MANIFEST = SESSION / 'manifest.json'
SECONDARY_FILE = BUILD / 'fwtn-jtag-201000-tailfix-4096.bin'
RTL = ROOT / 'rtl/ulx5m_spi_active_reboot_wb.v'
MAKEFILE = ROOT / 'Makefile.ulx5m-spi-secondary'

PRIMARY_BYTES = 446729
PRIMARY_SHA = '5a0c926ae560810800ccc9d864a970c8942863dfba22a42b8a53f519c1914b75'
REGION_BYTES = 0x70000
REGION_SHA = '5c72c39516f5e2b4fb2d39b8a153fb55eeeb12f9a5917799dc793ce006e61aee'
ROLLBACK_SHA = '1f754fffca317d02df5f831d79afc174492fc7b6aa200fab2a3755b65a99e8d5'
APP_OFFSET = 0x201000
APP_BYTES = 0x1000
APP_SHA = '28b1e5cbfa45a319600ec38c81207a36d9889c3179e8055f5a663c616ef97bee'
FLASH_BYTES = 0x400000
FLASH_SHA = 'a2a29d6fab3291d14f37b8ec4ce1a07d0a58729172c4dd629a877a4c1874e0e2'
ERASED_END = 0x6e000
EXPECTED_STATUS = bytes.fromhex('17 10 08 21 c3 00 00 00 00 00 00 00')
EXPECTED_EPILOGUE = bytes.fromhex('00 00 00 00 33 00 00 00 00')


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def checked(path, length, digest, description):
    """Fail before reading oversized/unexpected evidence files."""
    if not path.is_file() or path.stat().st_size != length:
        raise ValueError('%s: missing or unexpected file size: %s' % (description, path))
    data = path.read_bytes()
    if sha256(data) != digest:
        raise ValueError('%s: SHA-256 mismatch: %s' % (description, path))
    return data


def crc16_x25(data):
    crc = 0xFFFF
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = (crc >> 1) ^ (0x8408 if crc & 1 else 0)
    return crc ^ 0xFFFF


def block(data, pos, opcode, length, label):
    end = pos + 6 + length
    if pos < 0 or end > len(data) or data[pos:pos + 2] != bytes((opcode, length)):
        raise ValueError('%s: wrong command header' % label)
    header_crc = int.from_bytes(data[pos + 2:pos + 4], 'little')
    full_crc = int.from_bytes(data[end - 2:end], 'little')
    if header_crc != crc16_x25(data[pos:pos + 2]):
        raise ValueError('%s: wrong header CRC' % label)
    if full_crc != crc16_x25(data[pos:end - 2]):
        raise ValueError('%s: wrong payload CRC' % label)
    return data[pos + 4:end - 2], end


def check_terminal(primary):
    """Only interpret the pinned terminal record, NOT the entire bitstream."""
    if len(primary) != PRIMARY_BYTES or sha256(primary) != PRIMARY_SHA:
        raise ValueError('primary identity must be pinned before terminal decoding')
    pos = len(primary) - 46
    payload, pos = block(primary, pos, 0xDB, 12, 'CMD_CHG_STATUS')
    if payload != EXPECTED_STATUS:
        raise ValueError('primary CMD_CHG_STATUS differs from observed 0x17 0x10')
    if primary[pos:pos + 9] != EXPECTED_EPILOGUE:
        raise ValueError('unexpected status execute/padding bytes')
    pos += 9
    reset, pos = block(primary, pos, 0xC3, 1, 'CMD_CFGRST')
    if reset != b'\x00':
        raise ValueError('CMD_CFGRST payload differs')
    jump, pos = block(primary, pos, 0xDA, 4, 'CMD_JUMP')
    if int.from_bytes(jump, 'little') != APP_OFFSET:
        raise ValueError('CMD_JUMP is not the v41 secondary address')
    if primary[pos:] != b'\x00\x00':
        raise ValueError('unexpected CMD_JUMP padding')
    return {'status_offset': len(primary) - 46, 'status': payload[0],
            'reconfig_flag_observed': bool(payload[0] & 0x08),
            'jump_address': APP_OFFSET}


def check_source(rtl, makefile):
    """Report what the frozen primary does, not a speculative bank-mode fix."""
    required = ('.CLK(1\'b0)', '.EN(1\'b0)', '.DATA(8\'b0)',
                '.VALID(1\'b0)', '.RECFG(recfg)')
    if any(fragment not in rtl for fragment in required):
        raise ValueError('CC_CFG_CTRL wiring has changed; re-audit actual RTL')
    if '--bootaddr $(SPI_SECONDARY_ADDR)' not in makefile:
        raise ValueError('gmpack --bootaddr invocation changed')
    if '--reconfig' in makefile:
        raise ValueError('primary gmpack --reconfig option changed; re-audit')
    return 'RECFG-only (configuration byte channel tied low)'


def audit(primary, region, rollback, secondary, manifest, rtl, makefile,
          current_flash=None):
    result = check_terminal(primary)
    result['cfg_ctrl'] = check_source(rtl, makefile)
    if len(region) != REGION_BYTES or sha256(region) != REGION_SHA:
        raise ValueError('installed v60 region does not match v62 pinned installation')
    if len(rollback) != REGION_BYTES or sha256(rollback) != ROLLBACK_SHA:
        raise ValueError('v55 backup region missing/corrupt')
    if len(secondary) != APP_BYTES or sha256(secondary) != APP_SHA:
        raise ValueError('v41 secondary sector missing/corrupt')
    if region[:PRIMARY_BYTES] != primary:
        raise ValueError('v60 installation region does not begin with pinned primary')
    if region[PRIMARY_BYTES:ERASED_END] != b'\xff' * (ERASED_END - PRIMARY_BYTES):
        raise ValueError('v60 installation region should have erased padding')
    if region[ERASED_END:] != rollback[ERASED_END:]:
        raise ValueError('v60 installation changed the preserved factory tail')
    expected_manifest = {
        'format': 'ULX5M-GS-V62-V60-SEED302-INSTALL-V1',
        'candidate_region_sha256': REGION_SHA,
        'primary_sha256': PRIMARY_SHA,
        'v55_rollback_region_sha256': ROLLBACK_SHA,
        'expected_candidate_flash_sha256': FLASH_SHA,
        'region_offset': 0, 'region_length': REGION_BYTES,
        'secondary_offset': APP_OFFSET,
    }
    if not isinstance(manifest, dict) or any(manifest.get(k) != v for k, v in expected_manifest.items()):
        raise ValueError('v62 installation manifest conflicts with frozen evidence')
    if current_flash is not None:
        if len(current_flash) != FLASH_BYTES or sha256(current_flash) != FLASH_SHA:
            raise ValueError('supplied current-flash dump does not match installed v60 whole-flash SHA')
        if current_flash[:REGION_BYTES] != region:
            raise ValueError('supplied flash dump differs from verified primary region')
        if current_flash[APP_OFFSET:APP_OFFSET + APP_BYTES] != secondary:
            raise ValueError('supplied flash dump differs from verified secondary sector')
    result.update({'primary_sha256': PRIMARY_SHA,
                   'installed_region_sha256': REGION_SHA,
                   'secondary_sector_sha256': APP_SHA,
                   'expected_installed_flash_sha256': FLASH_SHA,
                   'supplied_flash_dump_verified': current_flash is not None,
                   'bank_command_verified': False,
                   'normal_mode_secondary_takeover_verified': False})
    return result


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--current-flash', type=Path,
                   help='optional EXISTING 4 MiB read-only dump; no hardware calls')
    args = p.parse_args(argv)
    try:
        result = audit(
            checked(PRIMARY, PRIMARY_BYTES, PRIMARY_SHA, 'primary'),
            checked(REGION_FILE, REGION_BYTES, REGION_SHA, 'installed region'),
            checked(ROLLBACK_FILE, REGION_BYTES, ROLLBACK_SHA, 'v55 rollback'),
            checked(SECONDARY_FILE, APP_BYTES, APP_SHA, 'secondary sector'),
            json.loads(MANIFEST.read_text(encoding='ascii')),
            RTL.read_text(encoding='ascii'), MAKEFILE.read_text(encoding='ascii'),
            checked(args.current_flash, FLASH_BYTES, FLASH_SHA, 'current flash')
            if args.current_flash else None,
        )
        print('[PASS] Exact installed v60 primary, v62 candidate region, v55 rollback and v41 sector')
        print('[PASS] CRC-valid gmpack CMD_CHG_STATUS 0x17, CMD_CFGRST, CMD_JUMP 0x201000')
        print('[PASS] Primary release region contains erased padding and preserved factory tail')
        print('[INFO] CC_CFG_CTRL configuration channel: ' + result['cfg_ctrl'])
        print('[INFO] Whole-flash physical state: ' +
              ('SUPPLIED DUMP VERIFIED' if result['supplied_flash_dump_verified']
               else 'NOT READ; reference digest only'))
        print('[BLOCK] No vendor-confirmed config-bank command or SPI resume protocol')
        print('[BLOCK] DO NOT reuse the v55-to-v60 installer for a v60-to-new upgrade')
        print('[BLOCK] No flash writes or normal-mode takeover authorized by this audit')
        return 0
    except (OSError, UnicodeError, ValueError, TypeError, json.JSONDecodeError) as exc:
        print('[REJECT] ' + str(exc), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
