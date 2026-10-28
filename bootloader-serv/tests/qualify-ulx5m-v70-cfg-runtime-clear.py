#!/usr/bin/env python3
"""Read-only, fail-closed TinyDFU-derived runtime bank-release probe qualifier.

The successful v67 hardware packed 0x17 and bank bit 0; the failed v68 sent
0x1f at runtime. Patrick's TinyDFU ULX5M mkcmd.py clears CFG_CPE_CFG too,
and enables PLL autonomous clock bits. This hardware behavior is unproven
in v70. This module never programs an FPGA or flash.
"""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import re
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
RTL = ROOT / 'rtl' / 'top-ulx5m-gs-v70-cfg-runtime-clear-probe.v'
STREAM = ROOT / 'rtl' / 'ulx5m_cfg_bank_command_stream.v'
MAKEFILE = ROOT / 'Makefile.ulx5m-v70-cfg-runtime-clear-probe'

# Recomputed using CRC-16/X-25, the same framing as gmpack.
STATUS = bytes.fromhex('17 10 00 20 04 01 00 00 00 00 00 00')
FRAME = bytes.fromhex(
    'db 0c b8 7e 17 10 00 20 04 01 00 00 00 00 00 00 '
    '5d 31 00 00 00 00 33 00 00 00 00'
)
FINGERPRINT = hashlib.sha256(FRAME).hexdigest()
PINMAP = {
    'flash_cs_n': 'IO_WA_A8', 'flash_sck': 'IO_WA_B8',
    'flash_io': 'IO_WA_B7', 'flash_io_1': 'IO_WA_A7',
    'flash_io_2': 'IO_WA_B6', 'flash_io_3': 'IO_WA_A6',
}


PINNED_SOURCES = {
    'rtl/top-ulx5m-gs-v70-cfg-runtime-clear-probe.v': 'c6d3aeb76b40b83a598837676e006fcbc7b480fab0955affb8c20a23746f344e',
    'rtl/ulx5m_cfg_bank_command_stream.v': '72e3f2645e2e2f96b32fd41ea790c54d02d231c61f55f2973dd5fef9cad49e21',
    'Makefile.ulx5m-v70-cfg-runtime-clear-probe': 'a5d6d60a4d1068ed7b11d56cd22dc9b12d74757e5e255aaa17037ab2e938a7d2',
    'data/top-ulx5m-gs-v66-cfg-pin-sense-probe.ccf': 'eefa9d9536740acf7ad34638280739aad2ba6daad1ceac9e318e59f873fd3631',
    'data/top-ulx5m-gs-v66-cfg-pin-sense-probe.sdc': '65d3d8e7e67a142c090209ebd2e8a724814497c0771607afff64808cecee3343',
}


def require_pinned_sources():
    for rel, digest in PINNED_SOURCES.items():
        if hashlib.sha256((ROOT / rel).read_bytes()).hexdigest() != digest:
            raise ValueError('Local source drift: ' + rel)


def load(module_name, pathname):
    spec = importlib.util.spec_from_file_location(module_name, pathname)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def validate_frame():
    parser = load('v70_packer', HERE / 'qualify-ulx5m-v65-multiboot-probe.py')
    if parser.QUALIFIER_REVISION != 'v65c-20261027-accept-17-or-1f':
        raise ValueError('v65c known-good packer parser missing')
    if len(FRAME) != 27 or FRAME[4:16] != STATUS:
        raise ValueError('Unexpected frame payload')
    if parser.command_end(FRAME, 0, 0xdb, 12) != 18:
        raise ValueError('Frame CRC failed')
    if FRAME[18:] != bytes.fromhex('00 00 00 00 33 00 00 00 00'):
        raise ValueError('Execute trailer failed')
    # Independently implement the TinyDFU mkcmd status transformation.
    # Validate all four bit operations instead of trusting a literal frame.
    orig = bytearray(bytes.fromhex('1f 10 08 20 04 01 00 00 00 00 00 00'))
    orig[0] &= ~0x08     # CFG_CPE_CFG: clear reconfig-enable
    orig[2] &= ~0x08     # release configuration bank GPIO
    orig[4] |= 0x04     # PLL_AUTN
    orig[5] |= 0x01     # AUTN_CT_I
    if bytes(orig) != STATUS:
        raise ValueError('Runtime status differs from TinyDFU transformation')
    return parser


def check_source():
    require_pinned_sources()
    parser = validate_frame()
    rtl = RTL.read_text(encoding='ascii')
    stream = STREAM.read_text(encoding='ascii')
    make = MAKEFILE.read_text(encoding='ascii')
    # The byte order matters: v63b helper emits index zero at bits [7:0].
    expected_le = FRAME[::-1].hex()
    if ('216\'h' + expected_le) not in rtl:
        raise ValueError('RTL command frame differs from independently verified 27 bytes')
    required = [
        '.COMMAND_LEN(CFG_COMMAND_LEN)', '.COMMAND_BYTES(',
        '.normal_mode(1\'b1)', '.spi_released(1\'b1)',
        '.CLK(cfg_clk)', '.EN(cfg_en)', '.DATA(cfg_data)',
        '.VALID(cfg_valid)', '.RECFG(recfg)',
        'input  wire [3:0] flash_io', 'input  wire flash_cs_n',
        'input  wire flash_sck', 'if (stream_done && !recfg)',
    ]
    if any(token not in rtl for token in required):
        raise ValueError('RTL expected I/O or gated byte-stream wiring missing')
    if 'COMMAND_LEN = 0' not in stream or 'S_LEAD' not in stream or 'S_TAIL' not in stream:
        raise ValueError('v63b timing helper unexpectedly changed')
    if '--bootaddr 2101248' not in make or '$(GMPACK) --reconfig --bootaddr' not in make:
        raise ValueError('Expected bootaddr-only gmpack operation missing')
    if any(x in make for x in ['openFPGALoader', '--install', '-f --', 'flash-write']):
        raise ValueError('Unexpected hardware programming command in Makefile')
    if 'data/top-ulx5m-gs-v66-cfg-pin-sense-probe.ccf' not in make:
        raise ValueError('Must reuse exact v66 pin constraints')
    return parser


def check_candidate(bit, log):
    parser = check_source()
    b = bit.read_bytes()
    info = parser.inspect(b)
    status = bytes.fromhex(info['status'])
    # The original frame must keep the West-A bank in user I/O mode at pack
    # time. Clearing that bit at pack time would merely repeat v67.
    if status[0] != 0x1f or not status[2] & 0x08:
        raise ValueError('Expected reconfig-enabled user-I/O bank at PACK TIME; NOT a runtime test')
    fmax = parser.check_timing(log.read_text(encoding='utf-8'))
    txt = log.read_text(encoding='utf-8')
    for signal, pad in PINMAP.items():
        aliases = [signal]
        if signal == 'flash_io':
            aliases.append('flash_io_0')
        names = '(?:' + '|'.join(map(re.escape, aliases)) + ')'
        pattern = r"Constraining '[^']*\." + names + r"' to pad '" + pad + r"'\."
        if not re.search(pattern, txt):
            raise ValueError('Expected input-only %s missing on %s' % (signal, pad))
    return info, fmax


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('bit', type=Path)
    p.add_argument('--pnr-log', type=Path, required=True)
    args = p.parse_args()
    try:
        info, fmax = check_candidate(args.bit, args.pnr_log)
    except (OSError, AttributeError, ValueError) as e:
        print('[FAIL] %s' % e, file=sys.stderr)
        return 1
    print('[PASS] v70 pack-time West-A user-I/O mode retained, 6 input-only pins placed')
    print('[PASS] 27-byte CRC-valid TinyDFU-style status (CFG_CPE_CFG=0, uCIO=0, PLL autonomous); RECFG sequenced')
    print('[PASS] CRC-valid --bootaddr 0x201000; final routing %s MHz (25 MHz constraint)' % fmax)
    print('[INFO] Candidate %d bytes, SHA-256 %s' % (info['bytes'], info['sha256']))
    print('[INFO] runtime frame SHA-256 %s' % FINGERPRINT)
    print('[BLOCK] PACK-ONLY: no flash write, no DFU; corrected runtime mode release NOT physically proven')
    return 0

if __name__ == '__main__':
    sys.exit(main())
