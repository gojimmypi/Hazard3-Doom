#!/usr/bin/env python3
"""ULX5M-GS v67: ONLY toggle suspected config-bank user-IO status byte.

NO programmer, no flash writes, no source rebuild. The generator requires the
exact physically tested v66 input-only primary and its pinned source/PNR.
The changed bit is a hypothesis, NOT a documented bank-mode command.
"""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
BUILD = ROOT / 'build-ulx5m-gs'
SRC = BUILD / 'v66-cfg-pin-sense' / 'top_ulx5m_gs_v66_cfg_pin_sense_probe-seed302-PACK-ONLY.bit'
PNR = BUILD / 'v66-cfg-pin-sense' / 'pnr-seed302.log'
OUTPUT = BUILD / 'v67-bank-mode-ab' / 'v66-input-only-ucio-bit-cleared-PACK-ONLY.bit'
MANIFEST = OUTPUT.with_suffix('.json')
V66_LEN = 8892
V66_SHA = '450c8a95e99ab8d8ff231ad4db3686bdef6788cb5c681ef67ecd7702af820474'
OLD_STATUS = bytes.fromhex('17 10 08 20 04 01 00 00 00 00 00 00')
NEW_STATUS = bytes.fromhex('17 10 00 20 04 01 00 00 00 00 00 00')
FORMAT = 'ULX5M-GS-V67-BANK-MODE-BIT-A-B-OFFLINE-V1'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def v65():
    mod = load('v67_v65c', HERE / 'qualify-ulx5m-v65-multiboot-probe.py')
    if mod.QUALIFIER_REVISION != 'v65c-20261027-accept-17-or-1f':
        raise ValueError('Missing verified v65c command parser')
    return mod


def derive(original, strict=True):
    """Checks CRC-valid complete trailer before/after and exactly three edits."""
    if strict and (len(original) != V66_LEN or sha(original) != V66_SHA):
        raise ValueError('v66 primary bytes/size differ from hardware-verified v66')
    mod = v65()
    src_info = mod.inspect(original)
    p = src_info['status_offset']
    if original[p+4:p+16] != OLD_STATUS:
        raise ValueError('v66 CRC-valid status is not the expected 12-byte bank-mode record')
    if original[p:p+2] != b'\xdb\x0c':
        raise ValueError('Wrong status command opcode')
    new = bytearray(original)
    new[p+4:p+16] = NEW_STATUS
    # CRC16/X25 covers the opcode, length, header CRC, and complete status.
    body_end = p + 4 + 12
    new[body_end:body_end+2] = mod.crc16_x25(new[p:body_end]).to_bytes(2, 'little')
    result = bytes(new)
    out_info = mod.inspect(result)
    if out_info['jump_address'] != 0x201000 or out_info['status'] != NEW_STATUS.hex():
        raise ValueError('Invalid destination jump or mutated status')
    diffs = [i for i, (a, b) in enumerate(zip(original, result)) if a != b]
    if diffs != [p+6, p+16, p+17]:
        raise ValueError('Expected precisely status bank-mode bit + two CRC bytes; got %s' % diffs)
    if result[:p+6] != original[:p+6] or result[p+18:] != original[p+18:]:
        raise ValueError('Fabric or command trailer accidentally changed')
    return result, {'format': FORMAT, 'source_sha256': sha(original),
                    'candidate_sha256': sha(result), 'size': len(result),
                    'status_offset': p, 'changed_offsets': diffs,
                    'old_status': OLD_STATUS.hex(), 'new_status': NEW_STATUS.hex(),
                    'jump_address': 0x201000,
                    'warning': 'Experimental pack-only, not firmware; no DFU recovery'}


def verify_local():
    v66b = load('v67_v66b', HERE / 'qualify-ulx5m-v66b-cfg-bank-ab.py')
    # Check original RTL, exact routed pad constraints and timing, original CRC.
    v66b.check_candidate(SRC, PNR, V66_SHA)
    variant, manifest = derive(SRC.read_bytes())
    return variant, manifest


def verify_generated():
    variant, manifest = verify_local()
    if not OUTPUT.is_file() or OUTPUT.read_bytes() != variant:
        raise ValueError('v67 candidate absent or differs from exact 3-byte transformation')
    if not MANIFEST.is_file() or json.loads(MANIFEST.read_text()) != manifest:
        raise ValueError('v67 output manifest absent or invalid')
    return variant, manifest


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if argv not in ([], ['--verify']):
        print('[FAIL] Supported options: none, --verify. No write-to-flash mode.', file=sys.stderr)
        return 2
    try:
        if argv == ['--verify']:
            variant, meta = verify_generated()
        else:
            variant, meta = verify_local()
            OUTPUT.parent.mkdir(parents=True, exist_ok=True)
            if OUTPUT.exists() and OUTPUT.read_bytes() != variant:
                raise ValueError('Output exists with unexpected bytes; refusing overwrite')
            if MANIFEST.exists() and json.loads(MANIFEST.read_text()) != meta:
                raise ValueError('Manifest exists with unexpected data; refusing overwrite')
            # Both output paths are experimental, never used as production builds.
            if not OUTPUT.exists():
                with OUTPUT.open('xb') as f:
                    f.write(variant)
                    f.flush(); os.fsync(f.fileno())
            if not MANIFEST.exists():
                with MANIFEST.open('x', encoding='ascii', newline='\n') as f:
                    json.dump(meta, f, sort_keys=True, indent=2); f.write('\n')
                    f.flush(); os.fsync(f.fileno())
            verify_generated()
        print('[PASS] Exact v66 -> v67 3-byte status/CRC transformation')
        print('[PASS] No fabric, --bootaddr, route, or flash-suffix bytes changed')
        print('[INFO] candidate %d bytes sha256 %s' % (len(variant), meta['candidate_sha256']))
        print('[INFO] changed offsets: ' + ', '.join(hex(i) for i in meta['changed_offsets']))
        print('[BLOCK] PACK-ONLY. Do not flash this candidate without separate JTAG rollback qualification.')
        return 0
    except (ValueError, OSError, KeyError) as exc:
        print('[FAIL] %s' % exc, file=sys.stderr)
        return 1

if __name__ == '__main__':
    sys.exit(main())
