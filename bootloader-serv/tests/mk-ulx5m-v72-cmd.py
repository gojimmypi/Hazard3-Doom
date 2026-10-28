#!/usr/bin/env python3
"""Generate/check v72 CC_CFG_CTRL ROM from an actual packed GateMate image.

Source algorithm: pu-cc/tinydfu-bootloader boards/ulx5m/mkcmd.py.
Requires CRC-valid terminal CHG_STATUS/CFGRST/JUMP at 0x201000.
No hardware access, subprocesses, or flash writes.
"""
import argparse
import hashlib
import importlib.util
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
V70_SHA256 = '04ef3119762d0d8549f2df1b49b46a18795fa10e8a304ba98d5c7b2a26c811a6'
BOOTADDR = 0x201000


def audit_module():
    path = HERE / 'audit-ulx5m-v70-tinydfu-compat.py'
    spec = importlib.util.spec_from_file_location('v71a_audit', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def derive(bit, bootstrap=False):
    audit = audit_module()
    if bootstrap and hashlib.sha256(bit).hexdigest() != V70_SHA256:
        raise ValueError('v70 bootstrap bitstream SHA-256 mismatch')
    status, frame, records = audit.derived_tinydfu_frame(bit)
    if records[-1][2] != BOOTADDR.to_bytes(4, 'little'):
        raise ValueError('not a --bootaddr 0x201000 primary')
    if records[-2][2] != b'\x00':
        raise ValueError('unexpected CFGRST payload')
    if status[0] & 8 or status[2] & 8 or not status[4] & 4 or not status[5] & 1:
        raise ValueError('invalid transformed status')
    return frame


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bit', required=True, type=Path)
    parser.add_argument('--hex', required=True, type=Path)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--write', action='store_true')
    mode.add_argument('--check', action='store_true')
    parser.add_argument('--bootstrap-v70', action='store_true')
    args = parser.parse_args()
    try:
        frame = derive(args.bit.read_bytes(), bootstrap=args.bootstrap_v70)
        encoded = ''.join('%02X\n' % byte for byte in frame)
        if args.check:
            if args.hex.read_text(encoding='ascii') != encoded:
                raise ValueError('ROM does not match final packed image')
        else:
            args.hex.parent.mkdir(parents=True, exist_ok=True)
            args.hex.write_text(encoded, encoding='ascii')
        print('[PASS] %s 27-byte image-derived ROM: %s' % (
            'verified' if args.check else 'generated', hashlib.sha256(frame).hexdigest()))
    except (OSError, ValueError) as exc:
        print('[FAIL] %s' % exc, file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
