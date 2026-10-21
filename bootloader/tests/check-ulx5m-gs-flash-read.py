#!/usr/bin/env python3
"""Guards for volatile, read-only ULX5M configuration-flash probe."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
files = {
    p: (root / p).read_text(encoding="ascii") for p in (
        "rtl/top-ulx5m-gs-flash-read.v",
        "rtl/qspi_phy_gatemate.v",
        "data/top-ulx5m-gs-flash-read.ccf",
        "fw/fw_ulx5m_flash_read.c",
        "fw/Makefile.ulx5m-flash-read",
        "Makefile.ulx5m-gs",
        "tests/read-ulx5m-flash.py",
    )
}
for path, text in files.items():
    assert "\r" not in text, path

top = files["rtl/top-ulx5m-gs-flash-read.v"]
ccf = files["data/top-ulx5m-gs-flash-read.ccf"]
firmware = files["fw/fw_ulx5m_flash_read.c"]
make = files["Makefile.ulx5m-gs"]
newpins = dict(re.findall(r'^Pin_(?:in|out|inout) "([^"]+)" Loc = "([^"]+)";', ccf, re.M))
expected = {
    "flash_io[0]": "IO_WA_B7", "flash_io[1]": "IO_WA_A7",
    "flash_io[2]": "IO_WA_B6", "flash_io[3]": "IO_WA_A6",
    "flash_cs_n": "IO_WA_A8", "flash_sck": "IO_WA_B8",
}
assert all(newpins.get(p) == pad for p, pad in expected.items())
assert len(newpins.values()) == len(set(newpins.values()))
assert 'Pin_inout "flash_io[0]"' in ccf
assert '.V_IO("1.8")' in files["rtl/qspi_phy_gatemate.v"]
assert 'flash_master_i' in top and 'flash_phy_i' in top
# The integrated experiment avoids unused UART hardware but preserves slot 1.
assert 'uart_wb' not in top
assert 'wb_ack_uart <= wb_cyc[1] & ~wb_ack_uart;' in top
assert 'assign wb_rdata[1] = 32\'h00000000;' in top
# Hardware-verified single-bit SPI held WP_N and HOLD_N high.
assert ".spi_io_o({2'b11, spi_io_o[1:0]})" in top
assert ".spi_io_t({2'b00, spi_io_t[1:0]})" in top
# The registered BRAM request path is used only by the read-only flash top.
bridge = (root / "rtl/soc_bridge.v").read_text(encoding="ascii")
usb_top = (root / "rtl/top-ulx5m-gs-usb-probe.v").read_text(encoding="ascii")
assert 'parameter integer BRAM_REG = 0' in bridge
assert 'g_bram_reg' in bridge and 'ram_rdy <= pending_q' in bridge
assert '.BRAM_REG(1)' in top
assert '.BRAM_REG(1)' not in usb_top
assert 'test-flash-bram-pipe:' in make
assert '.MC_INIT_FILE("build-ulx5m-gs/usb_trans_mc.hex")' in top
assert 'fw_ulx5m_flash_read.hex' in top
assert 'FW_DFU' not in files["fw/Makefile.ulx5m-flash-read"]
assert 'spi.c' not in files["fw/Makefile.ulx5m-flash-read"]
assert 'fw_ulx5m_flash_read.c' in files["fw/Makefile.ulx5m-flash-read"]
assert 'flash-read-probe: $(FLASH_BIT)' in make
assert 'usb-probe: $(PROBE_BIT)' in make
assert '#define FLASH_BYTES          0x400000u' in firmware
assert 'USB_REQ_FLASH_ID' in firmware and 'USB_REQ_FLASH_READ' in firmware
assert 'case USB_RT_DFU_UPLOAD:' in firmware
assert 'case USB_RT_DFU_DNLOAD:' in firmware
assert 'return USB_FND_ERROR;' in firmware
assert 'flash_send(0x9fu)' in firmware and 'flash_send(0x03u)' in firmware
for unsafe in ('flash_send(0x06u)', 'flash_send(0x02u)', 'flash_send(0x20u)',
               'flash_send(0xd8u)', 'flash_page_program', 'flash_sector_erase'):
    assert unsafe not in firmware, unsafe
assert '0xc0, 0x51' in files["tests/read-ulx5m-flash.py"]
assert '0xc0, 0x52' in files["tests/read-ulx5m-flash.py"]
print('[PASS] ULX5M flash read diagnostic source guards')
print('[PASS] 6 distinct 1.8 V SPI pins, 4 MiB bounds, no write requests')
