#!/usr/bin/env python3
"""Read-only v72 pack, ROM, IO and routing qualifier (NOT hardware proof)."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
RTL = ROOT / 'rtl/top-ulx5m-gs-v72-cfg-registered-probe.v'
MAKE = ROOT / 'Makefile.ulx5m-v72-cfg-registered-probe'
PINMAP = {
    'flash_cs_n': 'IO_WA_A8', 'flash_sck': 'IO_WA_B8',
    'flash_io_0': 'IO_WA_B7', 'flash_io_1': 'IO_WA_A7',
    'flash_io_2': 'IO_WA_B6', 'flash_io_3': 'IO_WA_A6',
}


def load(filename, name):
    spec = importlib.util.spec_from_file_location(name, HERE / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def qualify(bit, cmd, log, netlist, source_sha):
    generator = load('mk-ulx5m-v72-cmd.py', 'v72_generator')
    parser = load('qualify-ulx5m-v65-multiboot-probe.py', 'v65_qualifier')
    data = bit.read_bytes()
    actual = generator.derive(data)
    expected = ''.join('%02X\n' % x for x in actual)
    if expected != cmd.read_text(encoding='ascii'):
        raise ValueError('ROM/packed candidate fixed point FAILED')
    if len(actual) != 27:
        raise ValueError('bad command length')
    if hashlib.sha256(data).hexdigest() in (
            '04ef3119762d0d8549f2df1b49b46a18795fa10e8a304ba98d5c7b2a26c811a6',
            'b1801ff866a1eb8fe8b96983299cb97910294763af97b90d655d4d23dfc4d8a6'):
        raise ValueError('old v70/v68 failed hardware image is not v72')
    built = json.loads(netlist.read_text(encoding='utf-8'))
    top = built.get('modules', {}).get('top_ulx5m_gs_v72_cfg_registered_probe')
    if not top or sum(c.get('type') == 'CC_CFG_CTRL' for c in top.get('cells', {}).values()) != 1:
        raise ValueError('netlist missing unique v72 configuration controller')
    source_record = source_sha.read_text(encoding='ascii').split()
    if len(source_record) != 2 or source_record[0] != hashlib.sha256(RTL.read_bytes()).hexdigest() or source_record[1] != 'rtl/top-ulx5m-gs-v72-cfg-registered-probe.v':
        raise ValueError('v72 source changed after synthesis')
    info = parser.inspect(data)
    status = bytes.fromhex(info['status'])
    if status[0] != 0x1f or status[1] != 0x10 or not status[2] & 8:
        raise ValueError('candidate must retain user ownership at PACK TIME')
    timing = parser.check_timing(log.read_text(encoding='utf-8'))
    source = RTL.read_text(encoding='ascii')
    make = MAKE.read_text(encoding='ascii')
    if not all(x in source for x in (
            'reg cfg_en =', 'reg cfg_valid =', 'reg [7:0] cfg_data =',
            'reg recfg =', 'S_TAIL:', 'S_WAIT:',
            'if (cfg_wait == 4\'d7)', 'if (&cfg_wait)',
            '$readmemh("build-ulx5m-gs/v72-registered-probe/cmd.hex", cmd_rom)',
            '.EN(cfg_en)', '.DATA(cfg_data)', '.VALID(cfg_valid)', '.RECFG(recfg)')):
        raise ValueError('v72 registered/tail/wait structure unexpectedly changed')
    for pad_name in ('flash_io', 'flash_sck', 'flash_cs_n'):
        if not re.search(r'input\s+wire.*\b' + pad_name + r'\b', source):
            raise ValueError('not input-only: ' + pad_name)
        if re.search(r'assign\s+' + pad_name + r'\s*=', source):
            raise ValueError('fabric drives flash pad: ' + pad_name)
    if '--reconfig --bootaddr 2101248' not in make or 'V72_SEED ?= 302' not in make:
        raise ValueError('incorrect pack flags or seed')
    if 'openFPGALoader' in make or '-f --' in make or 'flash-write' in make:
        raise ValueError('unexpected flashing in makefile')
    routed = log.read_text(encoding='utf-8')
    for signal, pad in PINMAP.items():
        name = r'flash_io(?:_0)?' if signal == 'flash_io_0' else signal
        pattern = r"Constraining '[^']*\." + name + r"' to pad '" + pad + r"'\."
        if not re.search(pattern, routed):
            raise ValueError('unverified flash pad: %s / %s' % (signal, pad))
    return info, timing, hashlib.sha256(actual).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--bit', required=True, type=Path)
    ap.add_argument('--hex', required=True, type=Path)
    ap.add_argument('--pnr-log', required=True, type=Path)
    ap.add_argument('--json', required=True, type=Path)
    ap.add_argument('--source-sha', required=True, type=Path)
    args = ap.parse_args()
    try:
        info, timing, digest = qualify(args.bit, args.hex, args.pnr_log, args.json, args.source_sha)
    except (OSError, ValueError) as exc:
        print('[FAIL] ' + str(exc), file=sys.stderr)
        return 1
    print('[PASS] v72 image-derived 27-byte command fixed point:', digest)
    print('[PASS] v72 0x201000 jump; CRCs; six input-only flash pins; pack-time uCIO')
    print('[PASS] 25 MHz routed timing: %s MHz' % timing)
    print('[INFO] candidate size=%d, SHA-256=%s' % (info['bytes'], info['sha256']))
    print('[BLOCK] PACK ONLY: NO HARDWARE VALIDATION; NEVER FLASH THIS IMAGE')
    return 0


if __name__ == '__main__':
    sys.exit(main())
