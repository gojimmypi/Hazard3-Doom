#!/usr/bin/env python3
"""Static guards for ULX5M-GS RAM-only bring-up (no HDL tools required)."""
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1]
sources = {
    "top": root / "rtl/top-ulx5m-gs-bringup.v",
    "clock": root / "rtl/sysmgr_gatemate.v",
    "usb": root / "cores/usb/rtl/usb_phy.v",
    "ccf": root / "data/top-ulx5m-gs-bringup.ccf",
    "sdc": root / "data/top-ulx5m-gs-bringup.sdc",
    "make": root / "Makefile.ulx5m-gs",
}
errors = []
for name, path in sources.items():
    if not path.is_file():
        errors.append(f"missing file: {path}")
if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
text = {name: path.read_text(encoding="utf-8") for name, path in sources.items()}

for name, content in text.items():
    if not content.isascii():
        errors.append(f"non-ASCII content in {name}")
    if "\r" in content:
        errors.append(f"CR in {name}; expected LF")

ports = dict(re.findall(r'^Pin_(?:in|out|inout)\s+"([^"]+)"\s+Loc\s*=\s*"([^"]+)"', text["ccf"], re.M))
expected = {"clk25", "btn0_n"} | {f"led_n[{i}]" for i in range(8)}
if set(ports) != expected:
    errors.append(f"CCF ports mismatch: missing={expected-set(ports)}, unexpected={set(ports)-expected}")
if len(set(ports.values())) != len(ports):
    errors.append("duplicate device pin locations in CCF")
if ports.get("clk25") != "IO_SB_A8" or ports.get("btn0_n") != "IO_EA_B4":
    errors.append("clock/button pin mapping changed")
if ".REF_CLK(25.0)" not in text["clock"] or ".OUT_CLK(48.0)" not in text["clock"]:
    errors.append("clock frequency settings changed")
for primitive in ("CC_IBUF", "CC_PLL", "CC_BUFG", "CC_USR_RSTN"):
    if primitive not in text["clock"]:
        errors.append(f"missing clock primitive {primitive}")
for primitive in ("CC_IOBUF", "CC_IDDR"):
    if primitive not in text["usb"]:
        errors.append(f"missing USB GateMate primitive {primitive}")
if 'TARGET == "GATEMATE"' not in text["usb"]:
    errors.append("missing GateMate USB PHY target")
for primitive in ("EHXPLLL", "TRELLIS_IO", "ecppack", "ecpmulti", "ecpbram"):
    if primitive.lower() in text["clock"].lower() or primitive.lower() in text["top"].lower() or primitive.lower() in text["make"].lower():
        errors.append(f"ECP5-specific reference in active bringup path: {primitive}")
if re.search(r"\b(?:flash|dfu):\s*\n\s*\t.*(?:gmpack|openFPGALoader|fujprog|dfu-util)", text["make"], re.I):
    errors.append("unexpected flash programming rule")
if 'flash dfu:' not in text["make"] or "@exit 1" not in text["make"]:
    errors.append("no explicit flash/dfu safety gate")
if "-period 40.000" not in text["sdc"]:
    errors.append("external 25 MHz timing constraint missing")

if errors:
    for error in errors:
        print(f"[FAIL] {error}", file=sys.stderr)
    sys.exit(1)
print("[PASS] ULX5M-GS RAM-only bring-up static checks")
print(f"[PASS] {len(ports)} constrained pins; no flash/USB hardware pins used")
