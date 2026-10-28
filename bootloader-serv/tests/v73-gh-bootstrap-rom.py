#!/usr/bin/env python3
"""Write/check full-SERV command, derived from v63c packed configuration.

The archived 446729-byte full-SERV v63c packed bitstream yields this exact
27-byte ROM through the TinyDFU transformation. Unlike the minimal v72 ROM,
this matches the FIRST packed full-SERV v73 pass reported on 2026-10-28.
It is an initial ROM hypothesis, never a substitute for verifying the FINAL
packed v73 image. No hardware access or flash writes.
"""
import argparse
import hashlib
from pathlib import Path
import sys

# Exact command independently derived from the archived full-SERV v63c image.
# Reference bitstream SHA256:
# 689f17a6b2e5ba1669e8f7652da4163b2d824ec91878b767e202ca1b33b9d4a2
FRAME_HEX = (
    'DB 0C B8 7E 17 10 00 21 C7 01 00 00 00 00 00 00 '
    '63 58 00 00 00 00 33 00 00 00 00'
)
FRAME = bytes.fromhex(FRAME_HEX)
SHA256 = 'aab512b6714eafa14fc96458fdf3852e7881642b26c9ac891082a58209f33468'


def output_text():
    if len(FRAME) != 27 or hashlib.sha256(FRAME).hexdigest() != SHA256:
        raise ValueError('full-SERV command reference changed or corrupted')
    return ''.join('%02X\n' % b for b in FRAME)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    try:
        text = output_text()
        if args.check:
            if args.output.read_text(encoding='ascii') != text:
                raise ValueError('bootstrap command differs from frozen full-SERV reference')
        else:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(text, encoding='ascii')
        print('[PASS] v73 full-SERV ROM seed 27 bytes: ' + SHA256)
        print('[LIMIT] Seed only; derive and verify command from FINAL v73 packed image')
    except (OSError, ValueError) as exc:
        print('[FAIL] ' + str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
