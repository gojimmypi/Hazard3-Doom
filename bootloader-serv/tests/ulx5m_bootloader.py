#!/usr/bin/env python3
"""Single offline ULX5M-GS command/manifest/timing qualification tool.

Subcommands: bootstrap, derive, fingerprint, stamp, qualify.
No tool in this file accesses JTAG, USB, SPI, flash or FPGA hardware.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

from cfgcmd_codec import derived_tinydfu_frame

ROOT = Path(__file__).resolve().parents[1]
BOOTADDR = 0x201000
# Frozen bootstrap ROM: used ONLY to seed iterative packing; the final ROM
# MUST be derived from and verified against the packed primary image.
BOOTSTRAP = bytes.fromhex(
    'DB 0C B8 7E 17 10 00 21 C7 01 00 00 00 00 00 00 '
    '63 58 00 00 00 00 33 00 00 00 00'
)
BOOTSTRAP_SHA = 'aab512b6714eafa14fc96458fdf3852e7881642b26c9ac891082a58209f33468'
PINMAP = {
    'flash_phy_i.g_io[0].pad_i': 'IO_WA_B7',
    'flash_phy_i.g_io[1].pad_i': 'IO_WA_A7',
    'flash_phy_i.g_io[2].pad_i': 'IO_WA_B6',
    'flash_phy_i.g_io[3].pad_i': 'IO_WA_A6',
    'flash_phy_i.g_cs[0].cs_pad_i': 'IO_WA_A8',
    'flash_phy_i.sck_pad_i': 'IO_WA_B8',
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def rom_text(data):
    if len(data) != 27:
        raise ValueError('expected exactly 27 CFG command bytes')
    return ''.join('%02X\n' % b for b in data)


def derive_image(packed):
    status, frame, records = derived_tinydfu_frame(packed)
    if records[-1][2] != BOOTADDR.to_bytes(4, 'little'):
        raise ValueError('packed primary has an unexpected boot address')
    if records[-2][2] != b'\x00':
        raise ValueError('packed primary has unexpected CFGRST payload')
    if status[0] & 8 or status[2] & 8 or not status[4] & 4 or not status[5] & 1:
        raise ValueError('invalid transformed CFG status')
    if len(frame) != 27:
        raise ValueError('invalid packed primary CFG command length')
    return frame


def input_names(inputs):
    names = list(inputs)
    if not names or len(names) != len(set(names)):
        raise ValueError('empty or duplicate source inputs')
    for name in names:
        path = Path(name)
        if path.is_absolute() or '..' in path.parts or not (ROOT / path).is_file():
            raise ValueError('missing/unsafe source input: ' + name)
    return names


def fingerprint(inputs):
    return ''.join('%s  %s\n' % (sha((ROOT / name).read_bytes()), name)
                   for name in input_names(inputs))


def validate_manifest(manifest, inputs):
    if manifest != fingerprint(inputs):
        raise ValueError('source/firmware/constraint/command changed since build')


def cells_by_type(data, type_name):
    return [(name, c) for module in data['modules'].values()
            for name, c in module.get('cells', {}).items()
            if c['type'] == type_name]


def pin(c, name):
    return c['connections'][name]


def check_clock_topology(data):
    cfg = cells_by_type(data, 'CC_CFG_CTRL')
    ibufs = cells_by_type(data, 'CC_IBUF')
    bufgs = cells_by_type(data, 'CC_BUFG')
    plls = cells_by_type(data, 'CC_PLL')
    if len(cfg) != 1 or len(plls) != 1 or len(bufgs) < 2 or len(bufgs) > 4:
        raise ValueError('invalid CC_CFG_CTRL / PLL / global clock buffer structure')
    if not cfg[0][0].startswith('cfg25_i.'):
        raise ValueError('CFG controller hierarchy changed unexpectedly')
    cfg_clk = pin(cfg[0][1], 'CLK')
    cfg_global = [(name, cell) for name, cell in bufgs if pin(cell, 'O') == cfg_clk]
    if len(cfg_global) != 1:
        raise ValueError('25 MHz CC_CFG_CTRL clock is not supplied by CC_BUFG')
    ref = pin(cfg_global[0][1], 'I')
    if not any(pin(cell, 'Y') == ref for _, cell in ibufs):
        raise ValueError('25 MHz global clock is not fed by CC_IBUF')
    if pin(plls[0][1], 'CLK_REF') != ref:
        raise ValueError('PLL and 25 MHz CFG clock do not share one input buffer')
    if not any(pin(cell, 'I') == pin(plls[0][1], 'CLK0')
               for _, cell in bufgs):
        raise ValueError('PLL 48 MHz output does not feed a global buffer')
    return True


def check_timing(pnrtxt):
    if not re.search(r"constraining clock net 'clk25' to 25\.00 MHz", pnrtxt, re.I):
        raise ValueError('25 MHz external oscillator constraint missing')
    rows = re.findall(
        r'Max frequency for clock\s+[^:\n]+:\s*([0-9.]+) MHz\s*\((PASS|FAIL) at ([0-9.]+) MHz\)',
        pnrtxt, re.I)
    clocks = [(float(actual), result.upper(), float(required))
              for actual, result, required in rows]
    if len(clocks) < 2:
        raise ValueError('missing two independently constrained clock domains')
    if any(result != 'PASS' or actual + 1e-6 < required
           for actual, result, required in clocks):
        raise ValueError('routed clock timing failed')
    if not any(abs(required - 25.0) < 0.01 for _, _, required in clocks):
        raise ValueError('25 MHz configuration clock timing absent')
    if not any(abs(required - 48.0) < 0.01 for _, _, required in clocks):
        raise ValueError('48 MHz SERV/USB clock timing absent')
    for signal, pad in PINMAP.items():
        if not re.search(r"Constraining '" + re.escape(signal) +
                         r"' to pad '" + re.escape(pad) + r"'", pnrtxt):
            raise ValueError('flash pad missing or changed: ' + signal)
    return clocks


def qualify(args):
    expected = json.loads(args.stamp.read_text(encoding='ascii'))
    packed = args.bit.read_bytes()
    if expected != {'sha256': sha(packed), 'seed': args.seed}:
        raise ValueError('build stamp missing/stale, or seed/bitstream changed')
    validate_manifest(args.source_sha.read_text(encoding='ascii'), args.inputs)
    if not 10000 <= len(packed) <= 0x80000:
        raise ValueError('packed primary outside 10 KiB..512 KiB limit')
    frame = derive_image(packed)
    if args.hex.read_text(encoding='ascii') != rom_text(frame):
        raise ValueError('ROM does not match packed primary')
    data = json.loads(args.json.read_text(encoding='utf-8'))
    check_clock_topology(data)
    if len(cells_by_type(data, 'CC_BRAM_20K')) + len(cells_by_type(data, 'CC_BRAM_40K')) < 4:
        raise ValueError('SERV/USB BRAM structure missing')
    clocks = check_timing(args.pnr_log.read_text(encoding='utf-8'))
    print('[PASS] %d-byte primary; SHA256 %s' % (len(packed), sha(packed)))
    print('[PASS] image-derived 27-byte ROM SHA256 %s' % sha(frame))
    print('[PASS] one CC_IBUF drives both the 25 MHz CFG global clock and PLL')
    print('[PASS] 25/48 MHz routed timing: %s' %
          ', '.join('%.2f/%.2f MHz' % (a, req) for a, _, req in clocks))
    print('[PASS] flash pinout and complete source manifest')
    print('[LIMIT] Firmware profile is not physically validated by PACK-ONLY qualification')
    print('[BLOCK] PACK-ONLY; no physical automatic-boot confirmation')


def parser_main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest='action', required=True)
    b = sub.add_parser('bootstrap')
    b.add_argument('--output', required=True, type=Path)
    d = sub.add_parser('derive')
    d.add_argument('--bit', required=True, type=Path)
    d.add_argument('--hex', required=True, type=Path)
    choice = d.add_mutually_exclusive_group(required=True)
    choice.add_argument('--write', action='store_true')
    choice.add_argument('--check', action='store_true')
    f = sub.add_parser('fingerprint')
    f.add_argument('--output', required=True, type=Path)
    f.add_argument('--inputs', nargs='+', required=True)
    st = sub.add_parser('stamp')
    st.add_argument('--bit', required=True, type=Path)
    st.add_argument('--output', required=True, type=Path)
    st.add_argument('--seed', type=int, required=True)
    q = sub.add_parser('qualify')
    for flag in ('bit', 'hex', 'json', 'pnr-log', 'source-sha', 'stamp'):
        q.add_argument('--' + flag, required=True, type=Path)
    q.add_argument('--seed', type=int, required=True)
    q.add_argument('--inputs', nargs='+', required=True)
    a = p.parse_args(argv)
    try:
        if a.action == 'bootstrap':
            if len(BOOTSTRAP) != 27 or sha(BOOTSTRAP) != BOOTSTRAP_SHA:
                raise ValueError('bootstrap seed corrupted')
            a.output.parent.mkdir(parents=True, exist_ok=True)
            a.output.write_text(rom_text(BOOTSTRAP), encoding='ascii')
            print('[PASS] seeded command ROM; final-image verification still required')
        elif a.action == 'derive':
            rom = rom_text(derive_image(a.bit.read_bytes()))
            if a.check:
                if a.hex.read_text(encoding='ascii') != rom:
                    raise ValueError('packed image command ROM does not match')
            else:
                a.hex.parent.mkdir(parents=True, exist_ok=True)
                a.hex.write_text(rom, encoding='ascii')
            print('[PASS] %s 27-byte image-derived ROM' %
                  ('verified' if a.check else 'updated'))
        elif a.action == 'fingerprint':
            a.output.write_text(fingerprint(a.inputs), encoding='ascii')
            print('[PASS] captured %d source inputs' % len(a.inputs))
        elif a.action == 'stamp':
            a.output.write_text(json.dumps({'sha256': sha(a.bit.read_bytes()),
                                            'seed': a.seed}, sort_keys=True) + '\n',
                                encoding='ascii')
            print('[PASS] build stamp created (not hardware qualification)')
        else:
            qualify(a)
    except (OSError, ValueError, KeyError, IndexError, TypeError) as exc:
        print('[FAIL] %s' % exc, file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(parser_main())
