#!/usr/bin/env python3
"""ULX5M-GS v72c: guarded 64KiB *registered config-bank command* isolated flash A/B.

Read-only by default. The v72 registered command probe deliberately has NO USB DFU recovery.
Only use after v72b local build and RTL simulation qualification and v67 multiboot hardware proof.
Experimentally replaces flash [0,65536) and preserves all [65536,4MiB), notably 0x201000.
Restores the EXACT current v63c flash (not older v60) using saved data.
A successful flash readback is NOT successful FPGA secondary takeover.
Do NOT use openFPGALoader directly on the PACK-ONLY image; only this guarded A/B has safety gates.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import sys

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[1]
ROOT = PROJECT / 'bootloader-serv'
BUILD = ROOT / 'build-ulx5m-gs'
V72_BIT = BUILD / 'v72-registered-probe' / 'top_ulx5m_gs_v72_cfg_registered_probe-seed302-PACK-ONLY.bit'
V72_PNR_LOG = BUILD / 'v72-registered-probe' / 'pnr-seed302.log'
V60_PRIMARY = BUILD / 'normal-boot-dfu-hw-native' / 'spi-secondary-spi-primary-seed302.bit'
V60_REGION = BUILD / 'v62-spi-update-20261027T034513196538Z-1776' / 'v60-candidate-region-000000-06ffff.bin'
LOADER = PROJECT / 'bin' / 'openFPGALoader-v1.2.0.exe'
BLOCK_BYTES = 65536
FLASH_BYTES = 4194304
APP_OFFSET = 0x201000
APP_LENGTH = 0x1000
FORMAT = 'ULX5M-GS-V72C-REGISTERED-CFG-BANK-ONE-BLOCK-V1'
INSTALL_ACK = 'I_ACCEPT_V72C_NO_DFU_JTAG_RESTORE_RISK'
RESTORE_ACK = 'I_ACCEPT_V72C_RESTORE_EXACT_V63C_FIRST_64K'
SOURCE_SHA = {
    'rtl/top-ulx5m-gs-v72-cfg-registered-probe.v': 'c0be0b4ffdd410f704c99d040e8377367b3d007525394fda752934646a8547ac',
    'Makefile.ulx5m-v72-cfg-registered-probe': 'd5c0ead71487b1c8176b4f9ed8a41aa3596170d046c19f10e6a0a4847e115311',
    'data/top-ulx5m-gs-v66-cfg-pin-sense-probe.ccf': 'eefa9d9536740acf7ad34638280739aad2ba6daad1ceac9e318e59f873fd3631',
    'data/top-ulx5m-gs-v66-cfg-pin-sense-probe.sdc': '65d3d8e7e67a142c090209ebd2e8a724814497c0771607afff64808cecee3343',
    'tests/tb_ulx5m_v72_cfg_registered.v': 'ba44aa2f33498bcc95f982b3ac6a088db14561c147fede082fe003fbb523c981',
    'tests/mk-ulx5m-v72-cmd.py': 'd16747e0abc7b9b373e0d2de8567f32af65aaed41ace552aeded94bda7065dd6',
    'tests/qualify-ulx5m-v72-cfg-registered.py': 'a0239adbfeb72255cf5eea0d5738a0ac31fff99c93df0efdbfaa619eefd0c066',
    'tests/qualify-ulx5m-v65-multiboot-probe.py': '807c9dc52a5581dab90a91c58916b646e9affa0576259002ac01b237e6d5b14f',
    'tests/audit-ulx5m-v70-tinydfu-compat.py': '3e2266a98409656ba1472619d7d912607ac2d442038b923e935481096a25cf89',
    'tests/test-ulx5m-v72-cfg-registered.py': '751725a44483649189c2c061372ed50cda51287c809df3ce6118abb02e17e8d3',
    'tests/qualify-ulx5m-serv-jtag-write.py': '9dbe4ee6630f9a30641504a8afdd24ad04fda6d7a0e775303bfd1d6544f275d8',
    'tests/qualify-ulx5m-v64-reconfig-ab.py': 'd5df8806e1f579ea9e8d273c4657afadfe10daf47b6a22a734eb950a019b2d41',
    'tests/qualify-ulx5m-v63c-reconfig-primary.py': '0aa1aa615ff3c7f7821c46c8a5be264dd327df8e8c0fd8161ebcae64565ce8db',
}
# Candidate SHA is pinned from the user-qualified locally built v72b image.
# It MUST be supplied verbatim for --install; this installer does not build or pack.
EXPECTED_V72_SHA = '839696d7c8a4ecdf63dff904c01ce85aea280bd885eda4309c7e5d25800e3aa0'
EXPECTED_V72_BYTES = 14987
V72_ROM = BUILD / 'v72-registered-probe' / 'cmd.hex'
V72_NETLIST = BUILD / 'v72-registered-probe' / 'top_ulx5m_gs_v72_cfg_registered_probe.json'
V72_SOURCE_SHA = BUILD / 'v72-registered-probe' / 'source.sha256'
EXPECTED_PHYSICAL_V63C_SHA = '644c7c1b26e4cc2ba419a59a53ca8ffbbc02e808920d68336e84ac886d81cb02'



def sha(data):
    return hashlib.sha256(data).hexdigest()


def file_bytes(path):
    return path.read_bytes()


def load_py(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise ValueError('Cannot import ' + str(path))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def hw_adapter():
    return load_py('v66b_hw', HERE / 'qualify-ulx5m-serv-jtag-write.py')


def v64_module():
    return load_py('v66b_v64', HERE / 'qualify-ulx5m-v64-reconfig-ab.py')


def check_source():
    for relative, expected in SOURCE_SHA.items():
        p = ROOT / relative
        observed = sha(file_bytes(p))
        if observed != expected:
            raise ValueError('Changed pinned v72 source/qualifier: %s (SHA256 %s)' % (relative, observed))


def check_candidate(candidate, pnr, expected_sha=None):
    # Pin every dependency before any physical USB/JTAG access.
    check_source()
    if expected_sha is not None and not re.fullmatch(r'[0-9a-f]{64}', expected_sha):
        raise ValueError('Candidate SHA-256 must be exactly 64 lowercase hex characters')
    if candidate.resolve() != V72_BIT.resolve() or pnr.resolve() != V72_PNR_LOG.resolve():
        raise ValueError('Refusing alternate candidate or PNR artifact paths')
    v72 = load_py('v72_qualifier', HERE / 'qualify-ulx5m-v72-cfg-registered.py')
    info, fmax, command_sha = v72.qualify(
        candidate, V72_ROM, pnr, V72_NETLIST, V72_SOURCE_SHA)
    data = file_bytes(candidate)
    digest = sha(data)
    if (digest != EXPECTED_V72_SHA or info['sha256'] != EXPECTED_V72_SHA or
            len(data) != EXPECTED_V72_BYTES or info['bytes'] != EXPECTED_V72_BYTES):
        raise ValueError('Candidate differs from exactly qualified v72b user build SHA/length')
    if command_sha != '8fbec9715a209dac2dc35dc6b517972b9d64dcdc5a7b4437fac7731a0d2849e4':
        raise ValueError('Unexpected registered-command ROM SHA')
    if expected_sha is not None and digest != expected_sha:
        raise ValueError('Candidate SHA-256 differs from explicit user acknowledgement')
    if len(data) > BLOCK_BYTES:
        raise ValueError('Primary is larger than one 64KiB block')
    block = data + b'\xff' * (BLOCK_BYTES - len(data))
    print('[PASS] Exact v72b user-qualified registered ROM, 6 West-A inputs and routed 25MHz timing (%sMHz)' % fmax, flush=True)
    print('[INFO] Experimental v72 primary: %d bytes, SHA256 %s; first 64KiB padded FF' % (len(data), digest), flush=True)
    return block, digest


def pinned_v63c_state(v60_primary=None, v60_region=None):
    v64 = v64_module()
    src = file_bytes(v60_primary or V60_PRIMARY)
    region = file_bytes(v60_region or V60_REGION)
    v63c = load_py('v66b_v63c', HERE / 'qualify-ulx5m-v63c-reconfig-primary.py')
    cand = v63c.predict_variant(src)
    old_64k, new_64k = v64.inspect_candidate(src, cand, region)
    expected_region = cand + region[len(src):]
    return v64, region, expected_region, old_64k, new_64k


def verify_physical_v63c(live, pinned):
    v64, region, expected_region, old_64k, new_64k = pinned
    if len(live) != FLASH_BYTES:
        raise ValueError('Flash size is not exactly 4MiB')
    if live[:len(expected_region)] != expected_region:
        raise ValueError('Physical flash does not have exactly the v63c primary + padding')
    v60 = bytearray(live)
    v60[v64.BLOCK_BASE:v64.BLOCK_BASE + v64.BLOCK_SIZE] = old_64k
    expected_v63c = v64.qualify_live(bytes(v60), region, old_64k, new_64k)
    if live != expected_v63c:
        raise ValueError('Flash is not the full protected v63c baseline (factory/secondary changed)')
    if live[APP_OFFSET:APP_OFFSET + APP_LENGTH] != bytes(v60[APP_OFFSET:APP_OFFSET + APP_LENGTH]):
        raise ValueError('Application changed unexpectedly')
    if sha(live) != EXPECTED_PHYSICAL_V63C_SHA:
        raise ValueError('Physical flash differs from known v63c full-chip SHA-256')
    return sha(live)


def proposed_image(before, new_first_block):
    if len(before) != FLASH_BYTES or len(new_first_block) != BLOCK_BYTES:
        raise ValueError('Incorrect flash or block size')
    return new_first_block + before[BLOCK_BYTES:]


def xwrite(path, data):
    with path.open('xb') as f:
        f.write(data)
        f.flush()
        os.fsync(f.fileno())


def new_session():
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    return BUILD / ('v72c-registered-ab-%s-%d' % (stamp, os.getpid()))


def manifest(before, after, candidate_sha, candidate_len):
    return {
        'format': FORMAT,
        'description': 'SPI-PRIMARY dynamic bank-release command; JTAG-RESTORABLE; NO DFU IN V72',
        'base': 0, 'length': BLOCK_BYTES, 'flash_bytes': FLASH_BYTES,
        'before_sha256': sha(before), 'after_sha256': sha(after),
        'rollback_first_block_sha256': sha(before[:BLOCK_BYTES]),
        'candidate_first_block_sha256': sha(after[:BLOCK_BYTES]),
        'v72_bit_sha256': candidate_sha, 'v72_bit_bytes': candidate_len,
        'application_sector_sha256': sha(before[APP_OFFSET:APP_OFFSET + APP_LENGTH]),
        'protected_suffix_sha256': sha(before[BLOCK_BYTES:]),
    }


def save_session(directory, before, after, candidate_sha, candidate_len):
    directory.mkdir(parents=False, exist_ok=False)
    xwrite(directory / 'v63c-full-flash-before.bin', before)
    xwrite(directory / 'v63c-first-64k-rollback.bin', before[:BLOCK_BYTES])
    xwrite(directory / 'v72-first-64k-candidate.bin', after[:BLOCK_BYTES])
    xwrite(directory / 'manifest.json', (json.dumps(manifest(before, after, candidate_sha, candidate_len), indent=2, sort_keys=True) + '\n').encode('ascii'))
    if hasattr(os, 'sync'):
        os.sync()
    verify_session(directory)


def verify_session(directory):
    meta = json.loads((directory / 'manifest.json').read_text(encoding='ascii'))
    if meta.get('format') != FORMAT:
        raise ValueError('Wrong or altered v72c session metadata')
    before = file_bytes(directory / 'v63c-full-flash-before.bin')
    rollback = file_bytes(directory / 'v63c-first-64k-rollback.bin')
    candidate = file_bytes(directory / 'v72-first-64k-candidate.bin')
    if len(before) != FLASH_BYTES or len(rollback) != BLOCK_BYTES or len(candidate) != BLOCK_BYTES:
        raise ValueError('Session data length changed')
    if rollback != before[:BLOCK_BYTES]:
        raise ValueError('Rollback block differs from full saved flash')
    # The saved preimage is independently checked against the *pinned* v63c
    # state, not merely SHA-256 values supplied by the session manifest.
    pinned = pinned_v63c_state()
    verify_physical_v63c(before, pinned)
    after = proposed_image(before, candidate)
    if meta != manifest(before, after, meta.get('v72_bit_sha256'), meta.get('v72_bit_bytes')):
        raise ValueError('Session manifest mismatch')
    # Verify the complete saved candidate, including its mandatory FF padding.
    n = meta['v72_bit_bytes']
    if not isinstance(n, int) or isinstance(n, bool) or not 1 <= n <= BLOCK_BYTES:
        raise ValueError('Session candidate length invalid')
    if sha(candidate[:n]) != meta['v72_bit_sha256'] or candidate[n:] != b'\xff' * (BLOCK_BYTES - n):
        raise ValueError('Session candidate bytes do not match image SHA or FF padding')
    if not re.fullmatch('[0-9a-f]{64}', str(meta['v72_bit_sha256'])):
        raise ValueError('Session candidate hash malformed')
    return before, after, rollback, candidate


def phase(directory, state):
    tmp = directory / 'state.json.tmp'
    with tmp.open('w', encoding='ascii', newline='\n') as f:
        json.dump({'format': FORMAT, 'phase': state}, f, sort_keys=True)
        f.write('\n')
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, directory / 'state.json')


def check_protected_suffix(got, before):
    if len(got) != FLASH_BYTES or got[BLOCK_BYTES:] != before[BLOCK_BYTES:]:
        raise ValueError('Protected flash outside 0x000000..0x00ffff differs; auto restore prohibited')


def write_block(hw, loader, path):
    if path.suffix != '.bin' or path.stat().st_size != BLOCK_BYTES:
        raise ValueError('Refusing malformed first 64KiB write payload')
    # Adapter automatically wslpath -w translates just the native .exe file arg.
    hw.call(hw.jtag_cmd(loader, 100) + ['-f', '--verify', '--offset', '0', str(path)], timeout=600)


def read_full(hw, loader):
    return hw.read_region(loader, 100, 0, FLASH_BYTES)


def restore(hw, loader, directory):
    before, after, rollback, candidate = verify_session(directory)
    observed = read_full(hw, loader)
    check_protected_suffix(observed, before)
    phase(directory, 'V63C_RESTORE_STARTED')
    write_block(hw, loader, directory / 'v63c-first-64k-rollback.bin')
    got = hw.read_region(loader, 100, 0, BLOCK_BYTES)
    if got != rollback:
        raise ValueError('v63c first-block rollback readback mismatch')
    if read_full(hw, loader) != before:
        raise ValueError('v63c full-chip rollback readback mismatch')
    phase(directory, 'EXACT_V63C_FULL_FLASH_RESTORED')
    print('[PASS] EXACT pre-test v63c full-flash image restored; DFU cold boot still requires physical test', flush=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument('--read-only', action='store_true')
    modes.add_argument('--install', action='store_true')
    modes.add_argument('--restore-session', type=Path, metavar='DIR')
    parser.add_argument('--candidate-sha256', help='Exact SHA256 printed by local v72 pack-only verification')
    parser.add_argument('--confirm', default='')
    args = parser.parse_args(argv)
    try:
        if args.install:
            if args.confirm != INSTALL_ACK or not args.candidate_sha256:
                raise ValueError('Flash write BLOCKED; require candidate SHA256 and exact --confirm ' + INSTALL_ACK)
        elif args.restore_session:
            if args.confirm != RESTORE_ACK or args.candidate_sha256:
                raise ValueError('Restore BLOCKED; exact --confirm ' + RESTORE_ACK + ' without candidate SHA')
        elif args.confirm:
            raise ValueError('No acknowledgments accepted in offline or read-only mode')

        if args.restore_session:
            directory = args.restore_session.resolve()
            if directory.parent != BUILD.resolve() or not directory.name.startswith('v72c-registered-ab-'):
                raise ValueError('Restore session must be direct v72c child of build-ulx5m-gs')
            # Verify saved backup BEFORE attaching to hardware, even if
            # source has since been rebuilt/replaced. No candidate .bit needed.
            verify_session(directory)
            hw = hw_adapter()
            hw.check_loader(LOADER)
            hw.detect(LOADER, 100)
            restore(hw, LOADER, directory)
            return 0

        block, digest = check_candidate(V72_BIT, V72_PNR_LOG, args.candidate_sha256)
        pinned = pinned_v63c_state()
        print('[PASS] Pinned v60/v63c baseline source and exact v41 secondary expected', flush=True)
        if not (args.read_only or args.install):
            print('[OFFLINE PASS] No JTAG or flash access. Candidate is NOT yet hardware-qualified.')
            return 0
        hw = hw_adapter()
        hw.check_loader(LOADER)
        hw.detect(LOADER, 100)
        live = read_full(hw, LOADER)
        before_sha = verify_physical_v63c(live, pinned)
        print('[PASS] Exact current v63c 4MiB physical baseline: %s' % before_sha, flush=True)
        if args.read_only:
            print('[READ-ONLY PASS] No flash writes. First 64KiB candidate digest: ' + sha(block))
            return 0
        # Detect USB/JTAG read instability before entering the destructive path.
        if read_full(hw, LOADER) != live:
            raise ValueError('Two independent complete pre-write flash reads differ; no write authorized')
        print('[PASS] Second independent 4MiB pre-write read matches current v63c', flush=True)
        after = proposed_image(live, block)
        directory = new_session()
        hw.windows_file_argument(directory.parent)
        save_session(directory, live, after, digest, V72_BIT.stat().st_size)
        print('[RECOVERY] Preserved exact v63c 4MiB and 64KiB rollback: %s' % directory, flush=True)
        try:
            phase(directory, 'WRITE_FIRST_64K_STARTED')
            write_block(hw, LOADER, directory / 'v72-first-64k-candidate.bin')
            if hw.read_region(LOADER, 100, 0, BLOCK_BYTES) != block:
                raise ValueError('First 64KiB readback differs')
            if read_full(hw, LOADER) != after:
                raise ValueError('Whole-flash readback differs from strict one-block candidate')
            phase(directory, 'V72_SPI_PRIMARY_VERIFIED_RUNTIME_UNTESTED')
            print('[PASS] V72 flash candidate 4MiB independently verified; runtime bank release NOT YET TESTED', flush=True)
            print('[RECOVERY] Session: %s' % directory, flush=True)
            print('[WARNING] No BTN2/DFU recovery in v72. Use JTAG to restore exact v63c.', flush=True)
            return 0
        except (Exception, KeyboardInterrupt) as exc:
            print('[WRITE ERROR] %s; attempting JTAG restore from saved v63c block' % exc, file=sys.stderr, flush=True)
            try:
                restore(hw, LOADER, directory)
            except (Exception, KeyboardInterrupt) as restore_exc:
                phase(directory, 'CRITICAL_RESTORE_UNVERIFIED')
                print('[CRITICAL] v63c restore not proven: %s; preserve recovery session' % restore_exc, file=sys.stderr)
            return 1
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as exc:
        print('[FAIL] %s' % exc, file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
