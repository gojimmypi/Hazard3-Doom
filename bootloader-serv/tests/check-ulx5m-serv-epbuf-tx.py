#!/usr/bin/env python3
"""Independently check real EP RAM -> DATA packet transmit waveforms."""
import argparse
import importlib.util
from pathlib import Path

DECODER = Path(__file__).with_name('check-ulx5m-serv-tx-waveform.py')
spec = importlib.util.spec_from_file_location('usb_tx_wave_decoder', DECODER)
wave = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wave)
LENGTHS = (8, 16, 18, 64, 18, 8, 18, 0)


def payload_byte(which, idx):
    value = (idx * 29 + 7 + 17 * which) & 255
    if idx % 11 == 0:
        value = 255
    if idx % 13 == 1:
        value = 0
    return value


def expected_packet(which):
    payload = bytes(payload_byte(which, i) for i in range(LENGTHS[which]))
    crc = wave.crc16_usb(payload)
    pid = 0xc3 if which % 2 == 0 else 0x4b
    return bytes((0x80, pid)) + payload + bytes((crc & 255, crc >> 8))


def verify(samples, which):
    return wave.verify_one(samples, which, expected=expected_packet(which))


def selftest():
    # Independent digital waveform generator for the expected packets.
    for which in range(len(LENGTHS)):
        packet = expected_packet(which)
        ones = 0
        stuffed = []
        for bit in wave.bits_from_bytes(packet):
            stuffed.append(bit)
            ones = ones + 1 if bit else 0
            if ones == 6:
                stuffed.append(0)
                ones = 0
        level = 'J'
        syms = ['J']
        for bit in stuffed:
            if not bit:
                level = 'K' if level == 'J' else 'J'
            syms.append(level)
        syms.extend(('0', '0', 'J'))
        levels = {'J': (1, 0), 'K': (0, 1), '0': (0, 0)}
        samples = [(i, 0, 1, 0) for i in range(10)]
        for sym in syms:
            dp, dn = levels[sym]
            for _ in range(4):
                samples.append((len(samples), 1, dp, dn))
        for _ in range(10):
            samples.append((len(samples), 0, 1, 0))
        verify(samples, which)
        corrupt = list(samples)
        first = next(i for i, (_, en, _, _) in enumerate(corrupt) if en)
        for i in range(first + 48, first + 52):
            cyc, en, dp, dn = corrupt[i]
            corrupt[i] = (cyc, en, dn, dp)
        try:
            verify(corrupt, which)
        except ValueError:
            pass
        else:
            raise AssertionError('Could not detect corrupted byte stream')
    print('[PASS] EP RAM waveform checker selftest (8 packets and corruption)')


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('csv', nargs='?', type=Path)
    ap.add_argument('--selftest', action='store_true')
    args = ap.parse_args()
    if args.selftest:
        selftest()
        return
    if args.csv is None:
        ap.error('CSV path required unless --selftest')
    groups = wave.read_csv(args.csv, packet_count=len(LENGTHS))
    if set(groups) != set(range(len(LENGTHS))):
        raise ValueError('Missing TX packets: ' + str(sorted(groups)))
    for which, length in enumerate(LENGTHS):
        cycles, stuffed, phase = verify(groups[which], which)
        print('[PASS] EP RAM -> DATA%s len=%d CRC/payload/EOP (cycles=%d, stuffed=%d, phase=%d)' %
              ('0' if which % 2 == 0 else '1', length, cycles, stuffed, phase))


if __name__ == '__main__':
    main()
