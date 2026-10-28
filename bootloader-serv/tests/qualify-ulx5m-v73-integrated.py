#!/usr/bin/env python3
"""Read-only, fail-closed v73 combined SERV image qualifier. Never flashes."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
HERE = Path(__file__).resolve().parent
ROM = 'build-ulx5m-gs/v73-normal-boot-dfu-hw-native/cmd.hex'
FW = 'build-ulx5m-gs/v73-normal-boot-dfu-hw-native/fw_ulx5m_flash_read.hex'
PROVEN_V72 = '839696d7c8a4ecdf63dff904c01ce85aea280bd885eda4309c7e5d25800e3aa0'
# Read-only size sanity for the full SERV primary, not a flash write range.
# A future guarded installer must save/verify every affected erase sector.
MAX_PRIMARY_BYTES = 512 * 1024
MIN_PRIMARY_BYTES = 10000
# Approved 512KiB primary only for the separately pinned v75 seed-228
# installer with full 4MiB v73 baseline and 512KiB rollback. Other
# images still require their own guarded layout approval.
INSTALL_PRIMARY_BYTES = 0x80000
FILES = (
    'rtl/ulx5m_spi_active_reboot_wb.v',
    'rtl/top-ulx5m-gs-flash-read.v',
    FW,
    'Makefile.ulx5m-v73-integrated',
)
PINMAP = {
    'flash_phy_i.g_io[0].pad_i': 'IO_WA_B7',
    'flash_phy_i.g_io[1].pad_i': 'IO_WA_A7',
    'flash_phy_i.g_io[2].pad_i': 'IO_WA_B6',
    'flash_phy_i.g_io[3].pad_i': 'IO_WA_A6',
    'flash_phy_i.g_cs[0].cs_pad_i': 'IO_WA_A8',
    'flash_phy_i.sck_pad_i': 'IO_WA_B8',
}


def load(filename, name):
    spec = importlib.util.spec_from_file_location(name, HERE / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def digest(data):
    return hashlib.sha256(data).hexdigest()


def verify_source(source_sha):
    lines = source_sha.read_text(encoding='ascii').splitlines()
    if len(lines) != len(FILES):
        raise ValueError('missing / extra source-fingerprint entries')
    for line, expected_path in zip(lines, FILES):
        parts = line.split()
        if len(parts) != 2 or parts[1] != expected_path:
            raise ValueError('incorrect source-fingerprint file: ' + expected_path)
        if digest((ROOT / expected_path).read_bytes()) != parts[0]:
            raise ValueError('source or firmware changed after synthesis: ' + expected_path)


def verify_size(data):
    if len(data) > MAX_PRIMARY_BYTES or len(data) < MIN_PRIMARY_BYTES:
        raise ValueError('full SERV primary outside 10 KiB..512 KiB pack-only limit')


def verify_pins(pnrtxt):
    for signal, pad in PINMAP.items():
        if not re.search(r"Constraining '" + re.escape(signal) +
                         r"' to pad '" + re.escape(pad) + r"'", pnrtxt):
            raise ValueError('missing physical flash pad: ' + signal + ' / ' + pad)


def qualify(bit, cmd, log, netlist, source_sha):
    verify_source(source_sha)
    generator = load('mk-ulx5m-v72-cmd.py', 'v72_generator')
    audit = load('audit-ulx5m-v70-tinydfu-compat.py', 'v71_audit')
    data = bit.read_bytes()
    verify_size(data)
    if digest(data) == PROVEN_V72:
        raise ValueError('reused minimal v72 probe is not an integrated SERV build')
    frame = generator.derive(data)
    if cmd.read_text(encoding='ascii') != ''.join('%02X\n' % x for x in frame):
        raise ValueError('ROM and FINAL packed SERV primary are not at fixed point')
    status, frame_again, records = audit.derived_tinydfu_frame(data)
    if frame != frame_again or records[-1][2] != b'\x00\x10\x20\x00':
        raise ValueError('invalid jump address or command CRC')
    if not (status[4] & 4 and status[5] & 1):
        raise ValueError('runtime flash bank release bits missing')
    build = json.loads(netlist.read_text(encoding='utf-8'))
    top = build.get('modules', {}).get('top_ulx5m_gs_flash_read')
    if top is None:
        raise ValueError('wrong synthesized top (SERV missing)')
    all_cells = [cell for module in build.get('modules', {}).values()
                 for cell in module.get('cells', {}).values()]
    if sum(c.get('type') == 'CC_CFG_CTRL' for c in all_cells) != 1:
        raise ValueError('not exactly one CC_CFG_CTRL in combined netlist')
    if sum(c.get('type') in ('CC_BRAM_20K', 'CC_BRAM_40K') for c in all_cells) < 4:
        raise ValueError('combined SERV/USB BRAM structure missing')
    rtl = (ROOT / FILES[0]).read_text(encoding='ascii')
    toprtl = (ROOT / FILES[1]).read_text(encoding='ascii')
    make = (ROOT / FILES[3]).read_text(encoding='ascii')
    for required in (
            '.CLK(clk), .EN(cfg_en), .DATA(cfg_data)',
            'V78_BOOT_DELAY_CYCLES = 128849019',
            '&& v78_boot_ready',
            '.VALID(cfg_valid), .RECFG(recfg)',
            'S_RELEASE:', 'S_EN:', 'S_SEND:', 'S_NEXT:', 'S_TAIL:',
            'S_WAIT:', 'S_RECFG:', 'cfg_count == 6\'d63',
            'cfg_count == 6\'d7', 'cfg_count == 6\'d2',
            'cfg_count == 6\'d15', 'cfg_count == 6\'d31',
            '$readmemh("' + ROM + '", cmd_rom)'):
        if required not in rtl:
            raise ValueError('registered handoff logic missing: ' + required)
    for required in (
            'localparam FW_IMAGE = "' + FW + '";',
            'release_to_config(release_spi_for_config | v76_hardware_boot)',
            '.rst(fw_reset)',
            ".spi_idle(1'b1)",
            'wire usb_core_reset = fw_reset | ~dfu_enable;',
            'assign wb_rdata[0] = wb_cyc[0] ? misc_rdata : 32\'h00000000;',
            '.normal_mode(mode_valid && !dfu_selected)'):
        if required not in toprtl:
            raise ValueError('combined mode gating missing: ' + required)
    for required in (
            'ULX5M_V73_REGISTERED_REBOOT', 'ULX5M_V76_HW_NORMAL_BOOT',
            'ULX5M_V78_V72_STARTUP_DELAY',
            'ULX5M_SERV_SPI_ACTIVE_SECONDARY',
            'ULX5M_SERV_BTN2_DFU_GATE', 'DFU_HW_NATIVE_TEST_ONLY=1',
            'NATIVE_SPI_SECONDARY=1', '--reconfig --bootaddr 2101248',
            'check-ulx5m-oss-cad-suite.sh'):
        if required not in make:
            raise ValueError('v73 build gate missing: ' + required)
    if '.rst(fw_reset | v76_hardware_boot)' in toprtl:
        raise ValueError('fabric SPI reset must not include mode-select signal')
    if re.search(r'\b(openFPGALoader|dfu-util)(?:\.exe)?\b', make):
        raise ValueError('v73 build must not program hardware')
    pnrtxt = log.read_text(encoding='utf-8')
    checks = re.findall(r'Max frequency for clock .*?:\s*([0-9.]+) MHz \(PASS at ([0-9.]+) MHz\)', pnrtxt)
    if not checks or not any(float(required) >= 48.0 for _, required in checks):
        raise ValueError('missing routed 48 MHz clock timing PASS')
    if any(float(freq) < float(required) for freq, required in checks):
        raise ValueError('routed timing failed')
    verify_pins(pnrtxt)
    return len(data), digest(data), digest(frame), checks


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--bit', required=True, type=Path)
    ap.add_argument('--hex', required=True, type=Path)
    ap.add_argument('--json', required=True, type=Path)
    ap.add_argument('--pnr-log', required=True, type=Path)
    ap.add_argument('--source-sha', required=True, type=Path)
    args = ap.parse_args()
    try:
        size, bit_hash, cmd_hash, checks = qualify(args.bit, args.hex,
                                                    args.pnr_log, args.json,
                                                    args.source_sha)
    except (OSError, ValueError) as exc:
        print('[FAIL] ' + str(exc), file=sys.stderr)
        return 1
    print('[PASS] v73 final packed SERV primary and command ROM agree:', cmd_hash)
    print('[PASS] 0x201000 native jump, BTN2 gate, native FW, all six flash pins')
    print('[PASS] routed clock timing:', ', '.join('%s MHz / %s MHz' % t for t in checks))
    print('[INFO] candidate bytes=%d, SHA256=%s' % (size, bit_hash))
    if size > INSTALL_PRIMARY_BYTES:
        print('[BLOCK] IMAGE DOES NOT FIT 512 KiB PRIMARY: '
              '%d bytes over; flash 0x080000..0x3fffff is protected.' %
              (size - INSTALL_PRIMARY_BYTES))
    print('[BLOCK] PACK ONLY. Hardware takeover and retained DFU NOT YET PROVEN.')
    print('[BLOCK] v72c 64 KiB installer is NOT compatible with this full SERV image.')
    print('[BLOCK] Future installer must preserve every affected erase sector and 4 MiB backup.')
    print('[BLOCK] DO NOT FLASH; next step is a separately pinned guarded A/B installer.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
