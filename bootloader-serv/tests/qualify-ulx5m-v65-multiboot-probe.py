#!/usr/bin/env python3
"""v65: read-only gmpack sanity gate for the deliberately minimal probe.

The .bit is NOT a DFU/recovery image. Passing this check never authorizes
flash installation or a claim that the GateMate will execute CMD_JUMP.
"""
import argparse
import hashlib
import re
from pathlib import Path
import sys

QUALIFIER_REVISION = "v65c-20261027-accept-17-or-1f"
BOOTADDR = 0x201000
MAX_PRIMARY_LEN = 65536
# CRC-pinned gmpack --bootaddr 0x201000 terminal records.
# Status payload bytes [2..11] are fabric-/configuration-dependent.
# In particular the LED-only primary does not have the SERV primary's
# 0x08 0x21 c3 ... settings. Do not hard-code SERV status bytes.
TRAILER = bytes.fromhex('c3 01 0c fe 00 cc c6 da 04 28 eb 00 10 20 00 29 51 00 00')
EXEC = bytes.fromhex('00 00 00 00 33 00 00 00 00')


def crc16_x25(blob):
    crc = 0xffff
    for byte in blob:
        crc ^= byte
        for _ in range(8):
            crc = (crc >> 1) ^ (0x8408 if crc & 1 else 0)
    return crc ^ 0xffff


def command_end(blob, offset, opcode, length):
    if offset < 0 or offset + length + 6 > len(blob):
        raise ValueError('short command')
    if blob[offset:offset + 2] != bytes([opcode, length]):
        raise ValueError('unexpected command opcode/length')
    if blob[offset + 2:offset + 4] != crc16_x25(blob[offset:offset + 2]).to_bytes(2, 'little'):
        raise ValueError('header CRC mismatch')
    end = offset + 4 + length
    if blob[end:end + 2] != crc16_x25(blob[offset:end]).to_bytes(2, 'little'):
        raise ValueError('data CRC mismatch')
    return end + 2


def inspect(data):
    if not 100 <= len(data) <= MAX_PRIMARY_LEN:
        raise ValueError('primary does not fit one 64KiB block or is unexpectedly short')
    if data[:4] != bytes.fromhex('d9 01 ed 96'):
        raise ValueError('unexpected GateMate CMD_PATH prefix')
    if not data.endswith(TRAILER):
        raise ValueError('wrong --bootaddr 0x201000 terminal commands')
    tail = len(data) - len(TRAILER)
    reset = command_end(data, tail, 0xc3, 1)
    jump = command_end(data, reset, 0xda, 4)
    if reset != tail + 7 or jump != len(data) - 2:
        raise ValueError('bad reset/jump command lengths')
    if data[reset + 4:reset + 8] != BOOTADDR.to_bytes(4, 'little'):
        raise ValueError('wrong jump address')

    status_candidates = []
    # Scan only the last 128 bytes before the known-good command trailer.
    # Validate both command CRCs and the exact required execute/padding bytes.
    # Do not interpret arbitrary configuration/fabric payload as status commands.
    for p in range(max(0, tail - 128), tail):
        if data[p:p + 2] != b'\xdb\x0c':
            continue
        try:
            end = command_end(data, p, 0xdb, 12)
        except ValueError:
            continue
        if data[end:tail] != EXEC:
            continue
        status = data[p + 4:end - 2]
        # Require the boot-address bit (0x04), plus the ordinary 0x13
        # status baseline. The 0x08 reconfiguration bit is DESIGN-dependent:
        # the genuine CRC-verified v43 --bootaddr small primary uses 0x1f,
        # while the 446729-byte SERV primary uses 0x17. Reject unknown high
        # bits; both variants must retain the 0x10 command mode byte.
        if status[0] not in (0x17, 0x1f) or status[1] != 0x10:
            continue
        status_candidates.append((p, status))
    if len(status_candidates) != 1:
        raise ValueError('missing/ambiguous CRC-valid bootaddr status/execute record '
                         '(expected 0x17/0x1f, 0x10; run v65c tests and check source hashes)')
    status_pos, status = status_candidates[0]
    return {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(),
            'status_offset': status_pos, 'status': status.hex(),
            'jump_address': BOOTADDR}


def check_timing(log):
    matches = re.findall(
        r"Max frequency for clock '[^']+':\s*([0-9.]+) MHz "
        r"\((PASS|FAIL) at 25\.00 MHz\)", log)
    if not matches or matches[-1][1] != 'PASS' or float(matches[-1][0]) < 25.0:
        raise ValueError('final nextpnr timing does not PASS at 25.00 MHz')
    return matches[-1][0]


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('bit', type=Path, help='locally built v65 PACK-ONLY .bit')
    ap.add_argument('--pnr-log', type=Path, required=True, help='required local routed timing evidence')
    args = ap.parse_args()
    try:
        info = inspect(args.bit.read_bytes())
        fmax = check_timing(args.pnr_log.read_text(encoding='utf-8'))
    except (OSError, ValueError) as exc:
        print('[FAIL] ' + str(exc), file=sys.stderr)
        return 1
    print('[INFO] GateMate pack qualifier: ' + QUALIFIER_REVISION)
    print('[PASS] Final nextpnr timing: %s MHz (>=25.00 MHz)' % fmax)
    print('[PASS] CRC-valid gmpack primary status and 0x201000 jump; <=64 KiB')
    print('[INFO] primary length=%d SHA-256=%s' % (info['bytes'], info['sha256']))
    print('[INFO] status offset=0x%x payload=%s' % (info['status_offset'], info['status']))
    print('[BLOCK] PACK-ONLY; do NOT overwrite flash zero with this probe')
    return 0


if __name__ == '__main__':
    sys.exit(main())
