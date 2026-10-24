#!/usr/bin/env python3
"""Offline handoff checks. Never programs an FPGA or changes SPI flash."""
from pathlib import Path
import argparse
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def run(*cmd):
    print('+', ' '.join(map(str, cmd)), flush=True)
    subprocess.run([str(c) for c in cmd], cwd=ROOT, check=True)


def static_checks():
    bridge = (ROOT / 'rtl/soc_bridge.v').read_text(encoding='ascii')
    top = (ROOT / 'rtl/top-ulx5m-gs-flash-read.v').read_text(encoding='ascii')
    makefile = (ROOT / 'Makefile.ulx5m-gs').read_text(encoding='ascii')
    firmware = (ROOT / 'fw/fw_ulx5m_flash_read.c').read_text(encoding='ascii')
    assert 'parameter integer WB_DECODE_RDATA = 0' in bridge
    assert 'if (!WB_DECODE_RDATA || wb_cyc[i])' in bridge
    assert '`ifdef ULX5M_ENABLE_CFG_STREAM\n        , .WB_DECODE_RDATA(1)' in top
    fw_make = (ROOT / 'fw/Makefile.ulx5m-flash-read').read_text(encoding='ascii')
    assert 'normal-boot-cfg-offline: $(NORMAL_BOOT_CFG_JSON)' in makefile
    assert 'NORMAL_BOOT_CFG_FW' in makefile
    assert 'CFG_STREAM_ENABLE=1' in makefile
    assert '-DULX5M_SERV_CFG_HANDOFF_OFFLINE -DULX5M_ENABLE_CFG_STREAM' in makefile
    assert 'normal-boot-cfg-offline/fw_ulx5m_flash_read.hex' in top
    assert 'CFG_STREAM_ENABLE requires isolated normal-boot-cfg-offline BUILD_DIR' in fw_make
    assert 'CFLAGS += -DULX5M_ENABLE_CFG_STREAM=1' in fw_make
    assert '$(NORMAL_BOOT_CFG_JSON)' in makefile
    assert 'normal-boot-cfg-offline-synth.log' in makefile
    assert 'const int authorize = 0;' in firmware
    assert 'const int authorize = 1;' in firmware
    print('[PASS] Default branch remains fail-closed; integrated offline opt-in isolated')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check-only', action='store_true',
                        help='Static checks only, for hosts without Icarus')
    args = parser.parse_args()
    static_checks()
    if args.check_only:
        return
    if not shutil.which('iverilog') or not shutil.which('vvp'):
        parser.error('Icarus Verilog is required in WSL; no simulation skipped')
    run('gcc', '-std=c11', '-Wall', '-Wextra', '-Wno-main',
        '-fsyntax-only', '-DBOARD_ULX5M_GS=1', '-DULX5M_SERV_TEST=1',
        '-DULX5M_NORMAL_BOOT_EXPERIMENT=1', '-DULX5M_DFU_STREAM_ONLY=1',
        '-DULX5M_ENABLE_CFG_STREAM=1', '-Ifw',
        'fw/fw_ulx5m_flash_read.c', 'fw/ulx5m_normal_boot.c',
        'fw/ulx5m_normal_image.c')
    with tempfile.TemporaryDirectory(prefix='ulx5m-handoff-') as directory:
        out = Path(directory)
        for enabled in (False, True):
            name = 'enabled' if enabled else 'blocked'
            binary = out / f'cfg-{name}.vvp'
            command = ['iverilog', '-g2012']
            if enabled:
                command.append('-DULX5M_ENABLE_CFG_STREAM')
            run(*command, '-s', 'tb_ulx5m_cfg_stream_wb', '-o', binary,
                'rtl/ulx5m_cfg_stream_wb.v', 'tests/tb_ulx5m_cfg_stream_wb.v')
            run('vvp', binary)
        bridge_binary = out / 'wb-decode.vvp'
        run('iverilog', '-g2012', '-s', 'tb_ulx5m_normal_boot_wb_decode',
            '-o', bridge_binary,
            'rtl/soc_bridge.v', 'tests/tb_ulx5m_normal_boot_wb_decode.v')
        run('vvp', bridge_binary)
    print('[PASS] Offline configuration control and Wishbone isolation tests')


if __name__ == '__main__':
    main()
