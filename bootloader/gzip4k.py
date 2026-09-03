#!/usr/bin/env python3
#
# -----------------------------------------------------------------------------
# File:        gzip4k.py
# Path:        bootloader/gzip4k.py
#
# Project:     Hazard3-Doom
# Purpose:     Compress files with a 4 KiB DEFLATE window for low-memory targets.
#
# Original author(s):    emard
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
#
# gzip-compress file on PC using small block size 4K,
# suitable for unzipping at devices with small RAM,
# micropython friendly

import os, sys, zlib

def gzip4k(fname_src, fname_dst):
  stream = open(fname_src, "rb")
  comp = zlib.compressobj(level=9, wbits=16 + 12)
  with open(fname_dst, "wb") as outf:
    while 1:
      data = stream.read(1024)
      if not data:
        break
      outf.write(comp.compress(data))
    outf.write(comp.flush())

if __name__ == "__main__":
  gzip4k(sys.argv[1], sys.argv[2])
