#!/usr/bin/env python3
"""Offline, fail-closed packed-image and independent-clock qualifier."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
HERE = Path(__file__).resolve().parent
FILES = (
    'rtl/ulx5m_cfg_autoboot_25.v',
    'rtl/top-ulx5m-gs-flash-read.v',
    'build-ulx5m-gs/normal-boot-dfu-hw-native/fw_ulx5m_flash_read.hex',
    'Makefile.ulx5m-gs',
)
PINMAP = {
    'flash_phy_i.g_io[0].pad_i': 'IO_WA_B7',
    'flash_phy_i.g_io[1].pad_i': 'IO_WA_A7',
    'flash_phy_i.g_io[2].pad_i': 'IO_WA_B6',
    'flash_phy_i.g_io[3].pad_i': 'IO_WA_A6',
    'flash_phy_i.g_cs[0].cs_pad_i': 'IO_WA_A8',
    'flash_phy_i.sck_pad_i': 'IO_WA_B8',
}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def load(filename, name):
    spec = importlib.util.spec_from_file_location(name, HERE / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def qualify(bit, cmd, netlist, log, source_sha):
    lines = source_sha.read_text(encoding='ascii').splitlines()
    if len(lines) != len(FILES):
        raise ValueError('incorrect source fingerprint length')
    for line, filename in zip(lines, FILES):
        parts = line.split()
        if len(parts) != 2 or parts[1] != filename or digest((ROOT / filename).read_bytes()) != parts[0]:
            raise ValueError('source or firmware changed since synthesis: ' + filename)
    packed = bit.read_bytes()
    if not 10000 <= len(packed) <= 0x80000:
        raise ValueError('packed primary is outside approved 10KiB..512KiB layout')
    generator = load('derive-ulx5m-cfg-cmd.py', 'cfg_cmd')
    frame = generator.derive(packed)
    if cmd.read_text(encoding='ascii') != ''.join('%02X\n' % x for x in frame):
        raise ValueError('command ROM is not derived from FINAL packed primary')
    data = json.loads(netlist.read_text(encoding='utf-8'))
    cells = [(name, cell) for module in data['modules'].values()
             for name, cell in module.get('cells', {}).items()]
    cfg = [(name, cell) for name, cell in cells if cell['type'] == 'CC_CFG_CTRL']
    if len(cfg) != 1:
        raise ValueError('expected exactly one CC_CFG_CTRL')
    if not cfg[0][0].startswith('cfg25_i.'):
        raise ValueError('unexpected configuration controller hierarchy')
    top = data['modules']['top_ulx5m_gs_flash_read']
    clk_net = cfg[0][1]['connections']['CLK']
    clk_name = [name for name, obj in top.get('netnames', {}).items()
                if 'clk25' in name and clk_net[0] in obj.get('bits', [])]
    if not clk_name:
        raise ValueError('CC_CFG_CTRL is NOT clocked from 25 MHz reference')
    if sum(cell['type'] in ('CC_BRAM_20K', 'CC_BRAM_40K') for _, cell in cells) < 4:
        raise ValueError('SERV/USB BRAM structure missing')
    pnrtxt = log.read_text(encoding='utf-8')
    if not re.search(r"constraining clock net 'clk25' to 25\.00 MHz", pnrtxt):
        raise ValueError('missing board oscillator clock constraint')
    clocks = [(float(f), float(r)) for f, r in re.findall(
        r"Max frequency for clock .*?:\s*([0-9.]+) MHz \(PASS at ([0-9.]+) MHz\)", pnrtxt)]
    if not clocks or any(f < r for f, r in clocks) or not any(r >= 48 for _, r in clocks):
        raise ValueError('missing or failing routed 48 MHz and 25 MHz timing')
    for signal, pad in PINMAP.items():
        if not re.search(r"Constraining '" + re.escape(signal) +
                         r"' to pad '" + re.escape(pad) + r"'", pnrtxt):
            raise ValueError('wrong or missing flash pad: ' + signal)
    return len(packed), digest(packed), digest(frame), clocks


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bit', required=True, type=Path)
    parser.add_argument('--hex', required=True, type=Path)
    parser.add_argument('--json', required=True, type=Path)
    parser.add_argument('--pnr-log', required=True, type=Path)
    parser.add_argument('--source-sha', required=True, type=Path)
    args = parser.parse_args()
    try:
        size, sha, command, clocks = qualify(args.bit, args.hex, args.json,
                                              args.pnr_log, args.source_sha)
    except (OSError, ValueError, KeyError) as exc:
        print('[FAIL] %s' % exc, file=sys.stderr)
        return 1
    print('[PASS] packed primary %d bytes, SHA256 %s' % (size, sha))
    print('[PASS] image-derived 27-byte ROM SHA256 %s' % command)
    print('[PASS] exactly one CC_CFG_CTRL on 25 MHz oscillator; SERV stays at 48 MHz')
    print('[PASS] timing: %s' % ', '.join('%.2f / %.2f MHz' % c for c in clocks))
    print('[LIMIT] DFU firmware remains a native 4KiB test profile, not a complete user-image DFU updater.')
    print('[BLOCK] OFFLINE PACK ONLY. No installation permission or physical success claim.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
