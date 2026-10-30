#!/usr/bin/env python3
"""Guarded secondary-only ULX5M-GS USB DFU updater (no JTAG operations).

Preflight is offline by default. --probe reads flash without modifying it.
--execute requires an exact confirmation and an explicitly opt-in FWTF
firmware profile; golden FWTN is never writable here.
The update is in-place, NOT atomic. Hold BTN2 on reboot to recover an aborted
or corrupt secondary; do not assume normal boot is safe after interruption.
"""
import argparse
import hashlib
from pathlib import Path
import struct
import sys
import time
import zlib

from cfgcmd_codec import parse_commands, CMD_CHG_STATUS, CMD_JUMP

START = 0x201000
MAX_BYTES = 0x400000 - START
TOKEN = 0xc01d2042
CONFIRM = 'REPLACE-SECONDARY-0x201000'
VID, PID = 0x1d50, 0x614b


def check_image(image):
    if not 256 <= len(image) <= MAX_BYTES:
        raise ValueError('secondary must be 256..%d bytes' % MAX_BYTES)
    if image[:4] != bytes.fromhex('d901ed96'):
        raise ValueError('missing native GateMate image synchronization')
    commands = parse_commands(image)
    if len(commands) < 2:
        raise ValueError('truncated or empty packed GateMate command stream')
    if commands[-1][1] == CMD_JUMP:
        raise ValueError('image ends with a reconfiguration JUMP, not a secondary')
    if commands[-1][1] != CMD_CHG_STATUS or len(commands[-1][2]) != 12:
        raise ValueError('secondary must end in a 12-byte CHG_STATUS command')
    return zlib.crc32(image) & 0xffffffff


def status(device):
    result = bytes(device.ctrl_transfer(0xc0, 0x5d, 0, 0, 24, timeout=30000))
    if len(result) != 24 or result[:4] != b'FWTF':
        raise ValueError('device is not the full-image FWTF profile; refuse write')
    return struct.unpack_from('<5I', result, 4)


def checked_status(device, phase, size=None, crc=None):
    values = status(device)
    if values[0] != phase or values[4] != 0:
        raise ValueError('FWTF phase/error %d/%d (expected %d)' %
                         (values[0], values[4], phase))
    if size is not None and (values[1], values[2]) != (size, crc):
        raise ValueError('FWTF image length/checksum not acknowledged')
    return values


def dfu_getstatus(device):
    deadline = time.monotonic() + 30.0
    while True:
        result = bytes(device.ctrl_transfer(0xa1, 3, 0, 0, 6, timeout=30000))
        if len(result) != 6 or result[0] != 0:
            raise ValueError('DFU block rejected (status/state %r)' % (result,))
        if result[4] == 5:  # dfuDNLOAD_IDLE: page write is complete
            return
        if result[4] != 4:  # dfuDNBUSY: foreground flash write outstanding
            raise ValueError('unexpected DFU block state %r' % (result,))
        if time.monotonic() >= deadline:
            raise ValueError('DFU block programming timed out; secondary is not qualified')
        delay_ms = result[1] | (result[2] << 8) | (result[3] << 16)
        time.sleep(min(max(delay_ms / 1000.0, 0.001), 0.1))


def verify_flash(device, image, progress=None):
    # Only vendor-to-host IN requests. Safe with the installed FWTN primary.
    readback = hashlib.sha256()
    for offset in range(0, len(image), 32):
        address = START + offset
        chunk = image[offset:offset + 32]
        result = bytes(device.ctrl_transfer(0xc0, 0x5b, address & 0xffff,
                                            address >> 16, len(chunk), timeout=30000))
        if result != chunk:
            raise ValueError('independent flash readback mismatch at 0x%06x' % address)
        readback.update(result)
        if progress and ((offset // 32) % 4096 == 0 or offset + len(chunk) == len(image)):
            progress('Verified %d/%d bytes' % (offset + len(chunk), len(image)))
    if readback.digest() != hashlib.sha256(image).digest():
        raise ValueError('host readback SHA256 mismatch')
    return readback.hexdigest()


def probe(device, image, progress=None):
    # No OUT requests, ARM, FINISH, or set_configuration() in probe mode.
    report = bytes(device.ctrl_transfer(0xc0, 0x5d, 0, 0, 24, timeout=30000))
    if len(report) != 24 or report[:4] not in (b'FWTN', b'FWTF'):
        raise ValueError('unexpected DFU writer profile; refusing probe')
    jedec = bytes(device.ctrl_transfer(0xc0, 0x5a, 0, 0, 8, timeout=30000))
    if len(jedec) != 8 or jedec[:7] != b'A251\x1f\x42\x16' or jedec[7] & 3:
        raise ValueError('wrong AT25QL321 JEDEC or flash busy/write-enabled')
    if progress:
        progress('Device profile %s; AT25QL321 identified; read-only verification' %
                 report[:4].decode('ascii'))
    return verify_flash(device, image, progress)


def update(device, image, progress=None):
    length = len(image)
    crc = check_image(image)
    checked_status(device, 0)
    jedec = bytes(device.ctrl_transfer(0xc0, 0x5a, 0, 0, 8, timeout=30000))
    if len(jedec) != 8 or jedec[:7] != b'A251\x1f\x42\x16' or jedec[7] & 3:
        raise ValueError('wrong AT25QL321 JEDEC or flash busy/write-enabled')
    arm = b'U5WF' + struct.pack('<III', length, crc, TOKEN)
    device.ctrl_transfer(0x40, 0x5c, 1, 0x2000, arm, timeout=30000)
    checked_status(device, 1, length, crc)
    for offset in range(0, length, 64):
        chunk = image[offset:offset + 64]
        device.ctrl_transfer(0x21, 1, offset // 64, 0, chunk, timeout=30000)
        dfu_getstatus(device)
        if progress and ((offset // 64) % 2048 == 0 or offset + len(chunk) == length):
            progress('Transferred %d/%d bytes' % (offset + len(chunk), length))
    values = checked_status(device, 1, length, crc)
    if values[3] != length:
        raise ValueError('device received %d/%d bytes' % (values[3], length))
    device.ctrl_transfer(0x40, 0x5e, 0x5afe, 0x2026, b'', timeout=30000)
    deadline = time.monotonic() + 180.0
    while True:
        values = status(device)
        if values[1:4] != (length, crc, length):
            raise ValueError('device FINISH length/checksum/progress mismatch')
        if values[0] == 2 and values[4] == 0:
            break
        if values[0] == 3 or values[4]:
            raise ValueError('device verification failed (phase/error %d/%d)' %
                             (values[0], values[4]))
        if values[0] != 4:
            raise ValueError('unexpected FINISH phase %d' % values[0])
        if time.monotonic() >= deadline:
            raise ValueError('device verification timed out; secondary is not qualified')
        time.sleep(0.02)
    # Independent host-controlled byte-for-byte readback via separate SPI READ.
    return verify_flash(device, image, progress)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--image', type=Path, required=True)
    parser.add_argument('--execute', action='store_true',
                        help='actually replace the secondary image over USB')
    parser.add_argument('--probe', action='store_true',
                        help='read-only USB verification of the current secondary flash image')
    parser.add_argument('--confirm', default='',
                        help='required with --execute: ' + CONFIRM)
    args = parser.parse_args(argv)
    if args.probe and args.execute:
        parser.error('--probe and --execute are mutually exclusive')
    write_attempted = False
    try:
        image = args.image.read_bytes()
        crc = check_image(image)
        print('[PREFLIGHT] native secondary length=%d CRC32=%08x SHA256=%s' %
              (len(image), crc, hashlib.sha256(image).hexdigest()))
        print('[PREFLIGHT] target 0x%06x..0x%06x; protected below 0x201000' %
              (START, START + len(image) - 1))
        if not args.execute and not args.probe:
            print('[SAFE] preflight only; no USB or flash access')
            return 0
        if args.execute and args.confirm != CONFIRM:
            raise ValueError('destructive update requires --confirm ' + CONFIRM)
        try:
            import usb.core
        except ImportError as exc:
            raise ValueError('pyusb and a working libusb backend are required') from exc
        dev = usb.core.find(idVendor=VID, idProduct=PID)
        if dev is None:
            raise ValueError('ULX5M-GS USB DFU not found; check BTN2 and USB connection')
        if args.probe:
            digest = probe(dev, image, progress=print)
            print('[PASS] read-only flash comparison SHA256 ' + digest)
            print('[SAFE] no ARM, erase, program, FINISH, or RECFG issued')
            return 0
        dev.set_configuration()
        write_attempted = True
        digest = update(dev, image, progress=print)
        print('[PASS] full-image firmware and independent host flash readback SHA256 ' + digest)
        print('[NOTE] no FPGA RECFG issued; normal cold boot is a separate hardware test')
        return 0
    except (OSError, ValueError, TypeError) as exc:
        print('[FAIL] %s' % exc, file=sys.stderr)
        if write_attempted:
            print('[RECOVERY] Hold BTN2 before power-up and reflash a valid secondary; '
                  'do not try normal boot after a failed update.', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
