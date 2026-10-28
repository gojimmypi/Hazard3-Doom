#!/usr/bin/env python3
"""Read-only, fail-closed audit of v70 packed status vs its CC_CFG_CTRL ROM.

Protocol decoding follows the public pu-cc/tinydfu-bootloader boards/ulx5m/mkcmd.py
observed 2026-10-28. This verifies bytes, not hardware acceptance or timing.
No subprocesses, flash writes, or programming commands.
"""
import argparse
import hashlib
from pathlib import Path
import re
import sys

EXPECTED_BIT_SHA256 = '04ef3119762d0d8549f2df1b49b46a18795fa10e8a304ba98d5c7b2a26c811a6'
EXPECTED_BIT_LEN = 16123
CMD_FRAM = 0xD2
CMD_CFGRST = 0xC3
CMD_JUMP = 0xDA
CMD_CHG_STATUS = 0xDB


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def crc16(data, crc=0xffff):
    for b in data:
        crc ^= b
        for _ in range(8):
            crc = ((crc >> 1) ^ 0x8408) if (crc & 1) else (crc >> 1)
    return crc


def packet(cmd, data):
    if len(data) > 255:
        raise ValueError('Only compact config commands supported here')
    header = bytes([cmd, len(data)])
    c1 = crc16(header)
    header += bytes([~c1 & 0xff, (~c1 >> 8) & 0xff])
    c2 = crc16(header + data)
    return header + data + bytes([~c2 & 0xff, (~c2 >> 8) & 0xff])


def parse_commands(bit):
    """TinyDFU-compatible frame parsing; CRC-check terminal status/reset/jump.

    Interior configuration records may contain reserved/zero CRC fields.
    Only the final three configuration commands use the compact CRC rules
    required for the runtime handoff. Check those strictly.
    """
    i, records = 0, []
    while i < len(bit):
        cmd = bit[i]
        if cmd in (0x00, 0x33):
            i += 1
            continue
        header_len = 3 if cmd == CMD_FRAM else 2
        if i + header_len + 4 > len(bit):
            raise ValueError('Truncated command header at 0x%x' % i)
        size = bit[i+1] | (bit[i+2] << 8 if cmd == CMD_FRAM else 0)
        start = i + header_len + 2
        end = start + size
        if end + 2 > len(bit):
            raise ValueError('Truncated command at 0x%x' % i)
        # Other configuration commands have command-specific CRC formats.
        # Audit only the terminal status/reset/jump records here.
        records.append((i, cmd, bit[start:end]))
        i = end + 2
    # Intermediate CHG_STATUS packets can be non-compact configuration records.
    # CRC-check only the terminal CHG_STATUS/CFGRST/JUMP packets, exactly as
    # the packed runtime handoff requires. Offsets and payload bounds above
    # were checked for every command, including the intermediate packets.
    if len(records) >= 3 and [c for _, c, _ in records[-3:]] == [
            CMD_CHG_STATUS, CMD_CFGRST, CMD_JUMP]:
        for offset, cmd, payload in records[-3:]:
            header = bit[offset:offset + 2]
            header_crc = bit[offset + 2:offset + 4]
            calc_h = crc16(header)
            expected_h = bytes([~calc_h & 0xff, (~calc_h >> 8) & 0xff])
            if header_crc != expected_h:
                raise ValueError('Header CRC mismatch at 0x%x' % offset)
            frame = bit[offset:offset + 4 + len(payload)]
            data_crc = bit[offset + 4 + len(payload):offset + 6 + len(payload)]
            calc_d = crc16(frame)
            expected_d = bytes([~calc_d & 0xff, (~calc_d >> 8) & 0xff])
            if data_crc != expected_d:
                raise ValueError('Compact-command data CRC mismatch at 0x%x' % offset)
    return records


def derived_tinydfu_frame(bit):
    commands = parse_commands(bit)
    if len(commands) < 3 or [t[1] for t in commands[-3:]] != [CMD_CHG_STATUS, CMD_CFGRST, CMD_JUMP]:
        raise ValueError('No terminal CHG_STATUS, CFGRST, JUMP sequence')
    status = bytearray(commands[-3][2])
    if len(status) != 12:
        raise ValueError('Unexpected terminal status length: %d' % len(status))
    if not (status[0] & 0x08 and status[2] & 0x08):
        raise ValueError('Unexpected initial status bits; need --reconfig and user flash GPIO')
    status[0] &= ~0x08
    status[2] &= ~0x08
    status[4] |= 0x04
    status[5] |= 0x01
    frame = packet(CMD_CHG_STATUS, bytes(status)) + b'\x00'*4 + b'\x33' + b'\x00'*4
    if len(frame) != 27:
        raise ValueError('Expected 27-byte frame')
    return status, frame, commands[-3:]


def extract_rom(source):
    found = re.findall(r"216\s*'h([0-9a-fA-F_]+)", source)
    if len(found) != 1:
        raise ValueError('Need exactly one 216-bit ROM literal, found %d' % len(found))
    data = int(found[0].replace('_', ''), 16).to_bytes(27, 'little')
    return data


def audit(bit, source):
    if len(bit) != EXPECTED_BIT_LEN or sha256(bit) != EXPECTED_BIT_SHA256:
        raise ValueError('Not the exact locally qualified v70 bitstream: size or SHA mismatch')
    status, expected_frame, tail = derived_tinydfu_frame(bit)
    actual = extract_rom(source)
    print('[INFO] v70 bitstream SHA-256:', sha256(bit))
    print('[INFO] terminal records:', ' '.join('%02x@0x%04x' % (cmd, offset) for offset, cmd, _ in tail))
    print('[INFO] TinyDFU-derived target status:', status.hex(' '))
    print('[INFO] TinyDFU-derived command SHA-256:', sha256(expected_frame))
    print('[INFO] v70 RTL command SHA-256:', sha256(actual))
    if expected_frame != actual:
        differences = [(i, a, b) for i, (a, b) in enumerate(zip(expected_frame, actual)) if a != b]
        print('[FAIL] Runtime ROM differs from source-derived TinyDFU frame:', differences)
        raise ValueError('Runtime ROM not equivalent to source-derived TinyDFU command')
    print('[PASS] v70 runtime bytes match TinyDFU mkcmd.py data transform and CRC')
    if not re.search(r"if\s*\(after_stream\s*==\s*3'd3\)", source):
        raise ValueError('Unexpected v70 RECFG settle code: manual timing comparison required')
    print('[DIFF] v70 asserts RECFG after a short 4-count top-level wait')
    print('[DIFF] TinyDFU holds cfg_en low for a 16-count S_WAIT before RECFG')
    print('[LIMIT] Differences are hypotheses, NOT proof of why v70 failed')
    print('[LIMIT] This does NOT prove CC_CFG_CTRL timing or physical command acceptance')
    print('[BLOCK] READ ONLY: do NOT reflash v70 as a result of this audit')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--bit', type=Path,
                   default=Path('build-ulx5m-gs/v70-runtime-clear/top_ulx5m_gs_v70_cfg_runtime_clear_probe-seed302-PACK-ONLY.bit'))
    p.add_argument('--source', type=Path,
                   default=Path('rtl/top-ulx5m-gs-v70-cfg-runtime-clear-probe.v'))
    args = p.parse_args()
    try:
        audit(args.bit.read_bytes(), args.source.read_text(encoding='utf-8'))
    except (OSError, ValueError) as exc:
        print('[FAIL]', exc, file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
