#!/usr/bin/env python3
"""Read-only, fail-closed A/B packer qualification of the frozen v60 seed-302 primary.

The input bitstream and routed implementation are SHA pinned. A real local
'gmpack --reconfig --bootaddr' must reproduce the independent, CRC-correct
predicted byte delta exactly. There is NO flash/programmer access in this file.
Success is NOT evidence that secondary handoff works on silicon.
"""

from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
BUILD = ROOT / 'build-ulx5m-gs' / 'normal-boot-dfu-hw-native'
IMPLEMENTATION = BUILD / 'spi-secondary-seed302.txt'
BASELINE = BUILD / 'spi-secondary-spi-primary-seed302.bit'
MAKE = ROOT / 'Makefile.ulx5m-spi-secondary'
OUTPUT_ROOT = ROOT / 'build-ulx5m-gs'
IMPLEMENTATION_SHA = '006f0d02cdce6f7749ff29baa72e1350724b4822437fa61da11c7ca84dbbdd7c'
BASELINE_SHA = '5a0c926ae560810800ccc9d864a970c8942863dfba22a42b8a53f519c1914b75'
BASELINE_LEN = 446729
STATUS_OFFSET = 0x6D0DB
STATUS_DATA_LEN = 12
BOOTADDR = 0x201000
BOOTADDR_TAIL = bytes.fromhex('c3 01 0c fe 00 cc c6 da 04 28 eb 00 10 20 00 29 51 00 00')
STATUS_PAYLOAD_REMAINDER = bytes.fromhex('10 08 21 c3 00 00 00 00 00 00 00')
STATUS_EXEC_TAIL = bytes.fromhex('00 00 00 00 33 00 00 00 00')


def digest(data):
    return hashlib.sha256(data).hexdigest()


def x25(data):
    crc = 0xFFFF
    for val in data:
        crc ^= val
        for _ in range(8):
            crc = (crc >> 1) ^ (0x8408 if crc & 1 else 0)
    return crc ^ 0xFFFF


def check_command(data, offset, opcode, length):
    if data[offset:offset + 2] != bytes((opcode, length)):
        raise ValueError('wrong command/length')
    header = data[offset:offset + 2]
    if data[offset + 2:offset + 4] != x25(header).to_bytes(2, 'little'):
        raise ValueError('bad header CRC')
    end = offset + 4 + length
    if data[end:end + 2] != x25(data[offset:end]).to_bytes(2, 'little'):
        raise ValueError('bad body CRC')
    return end + 2


def assert_frozen(data, implementation, makefile):
    if len(data) != BASELINE_LEN or digest(data) != BASELINE_SHA:
        raise ValueError('wrong/rebuilt installed v60 seed-302 primary')
    if digest(implementation) != IMPLEMENTATION_SHA:
        raise ValueError('routed implementation differs from frozen seed-302 input')
    if ('$(GMPACK) --bootaddr $(SPI_SECONDARY_ADDR)' not in makefile or
            'SPI_SECONDARY_ADDR := 2101248' not in makefile or
            '--reconfig' in makefile):
        raise ValueError('production Makefile has changed; do not run this A/B')
    p = STATUS_OFFSET
    end = check_command(data, p, 0xDB, STATUS_DATA_LEN)
    if data[p + 4:end - 2] != b'\x17' + STATUS_PAYLOAD_REMAINDER:
        raise ValueError('unexpected v60 status payload')
    if data[end:end + len(STATUS_EXEC_TAIL)] != STATUS_EXEC_TAIL:
        raise ValueError('unexpected status execution padding')
    if data[-len(BOOTADDR_TAIL):] != BOOTADDR_TAIL:
        raise ValueError('wrong primary bootaddr trailer')
    check_command(data, len(data) - len(BOOTADDR_TAIL), 0xC3, 1)
    check_command(data, len(data) - len(BOOTADDR_TAIL) + 7, 0xDA, 4)


def predict_variant(baseline):
    """Independent gmpack result prediction, not an installable bitstream generator."""
    out = bytearray(baseline)
    pos = STATUS_OFFSET
    out[pos + 4] = 0x1F  # Set observed reconfig flag, retain bootaddr flag.
    end = pos + 4 + STATUS_DATA_LEN
    out[end:end + 2] = x25(out[pos:end]).to_bytes(2, 'little')
    check_command(out, pos, 0xDB, STATUS_DATA_LEN)
    return bytes(out)


def validate_variant(baseline, proposed):
    expected = predict_variant(baseline)
    if proposed != expected:
        wrong = next((i for i, (a, b) in enumerate(zip(proposed, expected)) if a != b), None)
        raise ValueError('gmpack output differs from ONLY reconfig/CRC delta; first offset %r, '
                         'expected size %d, observed %d' % (wrong, len(expected), len(proposed)))
    pos = STATUS_OFFSET
    end = check_command(proposed, pos, 0xDB, STATUS_DATA_LEN)
    if proposed[pos + 4:end - 2] != b'\x1F' + STATUS_PAYLOAD_REMAINDER:
        raise ValueError('wrong combined reconfig + bootaddr flags')
    if proposed[-len(BOOTADDR_TAIL):] != BOOTADDR_TAIL:
        raise ValueError('gmpack modified the jump address')
    changed = [i for i, (a, b) in enumerate(zip(baseline, proposed)) if a != b]
    permitted = {STATUS_OFFSET + 4, STATUS_OFFSET + 4 + STATUS_DATA_LEN,
                 STATUS_OFFSET + 5 + STATUS_DATA_LEN}
    if not changed or set(changed) - permitted:
        raise ValueError('packer unexpectedly changed bytes outside the status/CRC')
    return {'size': len(proposed), 'sha256': digest(proposed),
            'changed_offsets': ['0x%06x' % i for i in changed],
            'baseline_status': '0x17', 'candidate_status': '0x1f',
            'jump_address': '0x%06x' % BOOTADDR}


def qualify(baseline_path=BASELINE, implementation_path=IMPLEMENTATION,
            makefile_path=MAKE, output_root=OUTPUT_ROOT, packer=None,
            save=True):
    baseline = baseline_path.read_bytes()
    impl = implementation_path.read_bytes()
    assert_frozen(baseline, impl, makefile_path.read_text(encoding='ascii'))
    binary = packer or shutil.which('gmpack')
    if not binary:
        raise RuntimeError('gmpack not found in PATH; activate pinned OSS CAD Suite')
    with tempfile.TemporaryDirectory(prefix='ulx5m-v63c-pack-only-') as tmp:
        output = Path(tmp) / 'RECONFIG-EXPERIMENT-NOT-FOR-FLASH.bit'
        subprocess.run([str(binary), '--reconfig', '--bootaddr', str(BOOTADDR),
                        str(implementation_path.resolve()), str(output)],
                       check=True, timeout=120)
        candidate = output.read_bytes()
        result = validate_variant(baseline, candidate)
    if not save:
        return result
    directory = output_root / ('v63c-reconfig-PACK-ONLY-%s-%d' %
                               (datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ'), os.getpid()))
    directory.mkdir(parents=True, exist_ok=False)
    manifest = {
        'purpose': 'OFFLINE PACKER COMPARISON ONLY; NO FLASH OR SILICON AUTHORIZATION',
        'baseline_primary_sha256': BASELINE_SHA,
        'implementation_sha256': IMPLEMENTATION_SHA,
        'command': 'gmpack --reconfig --bootaddr 2101248 <frozen seed302 .txt> <candidate .bit>',
        'real_gmpack': str(binary),
        'reconfiguration_command_for_bank_restore': 'UNKNOWN',
        'spi_resume_address_verified_on_hardware': False,
        'secondary_takeover_verified_on_hardware': False,
        'candidate': result,
    }
    name = directory / 'EXPERIMENTAL-NOT-FOR-FLASH.bit'
    with name.open('xb') as f:
        f.write(candidate)
    with (directory / 'manifest.json').open('x', encoding='ascii') as f:
        json.dump(manifest, f, indent=2, sort_keys=True)
        f.write('\n')
    print('[SAVED] %s' % directory)
    return result


def main():
    print('[INFO] v63c pinned seed-302 dual-flag gmpack experiment: flash untouched')
    try:
        result = qualify()
    except (AssertionError, OSError, ValueError, RuntimeError,
            subprocess.CalledProcessError, subprocess.TimeoutExpired) as exc:
        print('[FAIL] %s' % exc, file=sys.stderr)
        return 1
    print('[PASS] real local gmpack matches expected isolated reconfig/CRC delta')
    print('[PASS] 0x201000 jump trailer unchanged; all non-status fabric bytes identical')
    print('[INFO] candidate: %d bytes, SHA-256 %s' % (result['size'], result['sha256']))
    print('[INFO] changed offsets: %s' % ', '.join(result['changed_offsets']))
    print('[BLOCK] No config-bank restoration command or physical SPI resume confirmation')
    print('[BLOCK] DO NOT program/flash this experimental file')
    return 0


if __name__ == '__main__':
    sys.exit(main())
