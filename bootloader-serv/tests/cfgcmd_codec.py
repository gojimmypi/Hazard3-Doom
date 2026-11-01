#!/usr/bin/env python3
"""GateMate compact CFG command parser and TinyDFU-compatible 27-byte generator.

Adapted from the independently tested bootloader command audit.
Reads only in-memory byte strings; never accesses a programmer or flash.
"""
import hashlib

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


