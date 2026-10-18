#!/usr/bin/env python3
"""Static guards for the standalone ULX5M-GS read-only JEDEC diagnostic."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
top = (root / "rtl/top-ulx5m-gs-flash-jedec.v").read_text(encoding="ascii")
ccf = (root / "data/top-ulx5m-gs-flash-jedec.ccf").read_text(encoding="ascii")
sdc = (root / "data/top-ulx5m-gs-flash-jedec.sdc").read_text(encoding="ascii")
make = (root / "Makefile.ulx5m-gs").read_text(encoding="ascii")

pins = re.findall(r'^Pin_\w+\s+"([^"]+)"\s+Loc = "([^"]+)"', ccf, re.M)
assert len(pins) == 17, f"expected 17 assigned pins, got {len(pins)}"
assert len(set(pin for _, pin in pins)) == len(pins), "duplicate physical pad"
expected = {
    "clk25": "IO_SB_A8", "btn0_n": "IO_EA_B4", "btn1_n": "IO_EA_A4",
    **{f"led_n[{i}]": p for i, p in enumerate((
        "IO_SB_A0", "IO_SB_B0", "IO_SB_A1", "IO_SB_B1",
        "IO_SB_A2", "IO_SB_B2", "IO_SB_A3", "IO_SB_B3"))},
    **{f"flash_io[{i}]": p for i, p in enumerate((
        "IO_WA_B7", "IO_WA_A7", "IO_WA_B6", "IO_WA_A6"))},
    "flash_cs_n": "IO_WA_A8", "flash_sck": "IO_WA_B8",
}
assert dict(pins) == expected, "unexpected flash/LED/power-bank pin map"
assert 'create_clock -name clk25 -period 40.000' in sdc
assert "8'h9f" in top and "bit_count == 31" in top
assert 'CC_IOBUF #(.V_IO("1.8")' in top
assert 'spi_sck' not in ccf or 'IO_WA_B8' in ccf
assert "flash-jedec: $(JEDEC_BIT)" in make
assert "rtl/top-ulx5m-gs-flash-jedec.v" in make
assert not any(name in top for name in (
    "qspi_master_wb", "picorv32", "usb #(", "spi_flash_write", "flash_erase")), \
    "read-only JEDEC test unexpectedly includes SoC or write logic"
print("[PASS] ULX5M 25 MHz JEDEC pinout, SPI ID-only logic, and build guards")
