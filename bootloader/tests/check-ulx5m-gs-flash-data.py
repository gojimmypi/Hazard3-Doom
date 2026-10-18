#!/usr/bin/env python3
"""Static safety and pin guards for the standalone 25 MHz SPI content reader."""
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent
rtl = (root / "rtl/top-ulx5m-gs-flash-data.v").read_text(encoding="ascii")
ccf = (root / "data/top-ulx5m-gs-flash-data.ccf").read_text(encoding="ascii")
sdc = (root / "data/top-ulx5m-gs-flash-data.sdc").read_text(encoding="ascii")
make = (root / "Makefile.ulx5m-gs").read_text(encoding="ascii")
ref_ccf = (root / "data/top-ulx5m-gs-flash-jedec.ccf").read_text(encoding="ascii")


def require(condition, reason):
    if not condition:
        raise SystemExit("[FAIL] " + reason)


def pins(text):
    return sorted(re.findall(r'^Pin_\w+\s+"([^"]+)"\s+Loc\s*=\s*"([^"]+)"', text, re.M))


require(pins(ccf) == pins(ref_ccf), "pinout differs from hardware-tested JEDEC diagnostic")
require(len(pins(ccf)) == 17, "expected 17 FPGA pins")
require('create_clock -name clk25 -period 40.000' in sdc, "missing 25 MHz timing constraint")
require("8'h03" in rtl and 'HEADER_BITS = 32' in rtl and 'DATA_BYTES = 32' in rtl,
        "incorrect opcode, address width or byte count")
require("bit_count == TOTAL_BITS - 1" in rtl and "cs_n <= 1'b1" in rtl,
        "missing termination or chip-select release")
require("output reg  done" in rtl and "assign display = !done" in rtl,
        "data must not display before capture completes")
require("io1 (" in rtl and ".T(1'b1), .Y(spi_miso)" in rtl, "MISO not input-only")
for name in ("io2", "io3"):
    require(re.search(rf'{name}\s*\(\s*\.IO\(flash_io\[\d\]\),\s*\.A\(1\'b1\),\s*\.T\(1\'b0\)', rtl),
            "WP_N/HOLD_N must be driven high")
require("JEDEC_TOP := top_ulx5m_gs_flash_jedec" in make,
        "known-good JEDEC target missing")
require("FLASH_DATA_TOP := top_ulx5m_gs_flash_data" in make,
        "new flash-data target missing")
require("module top_ulx5m_gs_flash_data" in rtl, "top-level module missing")
for forbidden in ("8'h06", "8'h02", "8'h20", "8'hd8", "8'hc7", "8'h60"):
    require(forbidden not in rtl.lower(), "forbidden flash write/erase opcode: " + forbidden)
for name in ("picorv32", "usb_phy", "qspi_master_wb", "sysmgr_gatemate"):
    require(name not in rtl, "standalone reader unexpectedly includes " + name)

print("[PASS] flash-data pinout matches hardware-tested JEDEC diagnostic")
print("[PASS] SPI 0x03, 24-bit address, 32-byte bounded read, no write operations")
print("[PASS] 25 MHz timing target and independent build target")
