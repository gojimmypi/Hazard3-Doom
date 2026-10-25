#!/usr/bin/env python3
"""Offline byte-level GateMate --bootaddr 0x201000 trailer check.

The trailer shape is pinned to the archived v43 gmpack candidate. A match
checks packaging, not execution or whether SPI-active primary boot occurred.
No programmer, SPI or flash operations are implemented.
"""
import argparse
import hashlib
from pathlib import Path

EXPECTED_BOOTADDR = 0x201000
# The exact, previously archived gmpack --bootaddr 0x201000 command suffix.
EXPECTED_TRAILER = bytes.fromhex(
    'c3 01 0c fe 00 cc c6 da 04 28 eb 00 10 20 00 29 51 00 00'
)


def inspect(path):
    raw = Path(path).read_bytes()
    if len(raw) <= len(EXPECTED_TRAILER):
        raise ValueError('configuration too short for --bootaddr trailer')
    if len(raw) >= EXPECTED_BOOTADDR:
        raise ValueError('primary configuration overlaps 0x201000 secondary slot')
    tail = raw[-len(EXPECTED_TRAILER):]
    if tail != EXPECTED_TRAILER:
        raise ValueError('bootaddr command trailer does not match pinned '
                         'v43 gmpack --bootaddr 0x201000 record')
    return len(raw), hashlib.sha256(raw).hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('primary', help='gmpack --bootaddr primary .bit file')
    args = p.parse_args()
    try:
        size, sha = inspect(args.primary)
    except (OSError, ValueError) as exc:
        p.exit(1, '[FAIL] ' + str(exc) + '\n')
    print('[PASS] exact gmpack --bootaddr 0x201000 trailer')
    print('Primary bytes:', size)
    print('Primary SHA-256:', sha)
    print('Flash zero protected: CHECK EXTERNALLY (this only reads a file)')
    print('SPI-active takeover: NOT VERIFIED')


if __name__ == '__main__':
    main()
