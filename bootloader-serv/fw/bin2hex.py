#!/usr/bin/env python3
# -----------------------------------------------------------------------------
# File:        bin2hex.py
# Path:        bootloader/fw/bin2hex.py
#
# Project:     Hazard3-Doom
# Purpose:     Convert packed binary firmware words to hexadecimal initialization text.
#
# Original author(s):    Sylvain Munaut (smunaut)
#
# Upstream:    HAD2019 / ULX3S / ULX4M DFU bootloader
# Upstream license: No file-level license notice was present in this
#                   imported upstream file; do not infer one here.
#
# This file contains third-party material and is not relicensed by
# Hazard3-Doom. Preserve its upstream history and provenance.
# See LICENSES/HAD2019-Bootloader-NOTICE.md for provenance and licensing.
# See LICENSING.md for project licensing policy and scope.
# -----------------------------------------------------------------------------

import struct
import sys


def main(argv0, in_name, out_name):
	with open(in_name, 'rb') as in_fh, open(out_name, 'w') as out_fh:
		while True:
			b = in_fh.read(4)
			if len(b) < 4:
				break
			out_fh.write('%08x\n' % struct.unpack('<I', b))

if __name__ == '__main__':
	main(*sys.argv)
