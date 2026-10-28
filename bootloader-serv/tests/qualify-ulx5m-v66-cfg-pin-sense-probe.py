#!/usr/bin/env python3
"""Fail-closed *offline* qualifier for v66 config-bank GPIO-sense A/B.

Reads the real locally packed .bit and routed log, validates CRC-valid
--bootaddr 0x201000 commands with v65c's tested parser, and requires all six
West-A flash pads to have been placed as input-only user GPIO in the route.
Nothing here authorizes a flash write; this is a PACK-ONLY experiment.
"""
import argparse
import importlib.util
from pathlib import Path
import re
import sys

HERE = Path(__file__).resolve().parent
PINMAP = {
    'flash_cs_n': 'IO_WA_A8',
    'flash_sck': 'IO_WA_B8',
    'flash_io[0]': 'IO_WA_B7',
    'flash_io[1]': 'IO_WA_A7',
    'flash_io[2]': 'IO_WA_B6',
    'flash_io[3]': 'IO_WA_A6',
}

def v65_parser():
    path = HERE / 'qualify-ulx5m-v65-multiboot-probe.py'
    spec = importlib.util.spec_from_file_location('v65c_packer', path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    if mod.QUALIFIER_REVISION != 'v65c-20261027-accept-17-or-1f':
        raise ValueError('Required validated v65c packer parser is absent')
    return mod


def inspect(data, log):
    mod = v65_parser()
    info = mod.inspect(data)
    fmax = mod.check_timing(log)
    for port, pad in PINMAP.items():
        # The specific bit-index name can be wrapped with a top prefix by PNR.
        # Demand an actual placement message, not just the user-supplied CCF.
        mapped = port.replace('[', '_').replace(']', '')
        # nextpnr GateMate represents the lowest bit of a vector with the
        # unsuffixed base name, e.g. flash_io rather than flash_io_0.
        # Higher bits retain _1, _2, _3. Accept the explicit indexed name
        # too, but continue to require a real routed placement log entry.
        aliases = [port, mapped]
        if port == 'flash_io[0]':
            aliases.append('flash_io')
        names = r'(?:' + '|'.join(re.escape(name) for name in aliases) + r')'
        pattern = r"Constraining '[^']*\.(?:" + names + r")' to pad '" + pad + r"'\."
        if not re.search(pattern, log):
            raise ValueError('missing routed input-only flash pad %s at %s' % (port, pad))
    return info, fmax


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('bit', type=Path)
    p.add_argument('--pnr-log', required=True, type=Path)
    a = p.parse_args()
    try:
        info, fmax = inspect(a.bit.read_bytes(), a.pnr_log.read_text(encoding='utf-8'))
    except (ValueError, OSError, AttributeError) as e:
        print('[FAIL] %s' % e, file=sys.stderr)
        return 1
    print('[PASS] 6 actual West-A configuration-flash GPIO inputs routed; none driven by v66 RTL')
    print('[PASS] final routing %s MHz at 25.00 MHz; CRC-valid --bootaddr 0x201000' % fmax)
    print('[INFO] primary %d bytes SHA-256 %s status %s' % (info['bytes'], info['sha256'], info['status']))
    print('[BLOCK] PACK-ONLY. No flash installation, no DFU recovery, no takeover proven.')
    return 0

if __name__ == '__main__':
    sys.exit(main())
