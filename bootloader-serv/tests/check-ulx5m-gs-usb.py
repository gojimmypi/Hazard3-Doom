#!/usr/bin/env python3
"""Check ULX5M-GS v005 USB monitor CCF and optional KiCad PCB mapping.

Usage:
    python3 tests/check-ulx5m-gs-usb.py
    python3 tests/check-ulx5m-gs-usb.py --pcb ../hardware/ulx5m-gs.kicad_pcb
"""
import argparse
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--pcb", type=Path, help="ULX5M-GS v005 KiCad PCB file")
args = parser.parse_args()
errors = []


def verify(condition, message):
    if not condition:
        errors.append(message)


def get_footprint(pcb, ref):
    match = re.search(r'\(property "Reference" "' + re.escape(ref) + r'"', pcb)
    if match is None:
        raise ValueError("reference not in PCB: " + ref)
    begin = pcb.rfind("\n\t(footprint ", 0, match.start())
    end = pcb.find("\n\t(footprint ", match.end())
    return pcb[begin:end if end >= 0 else len(pcb)]


ccf = (root / "data/top-ulx5m-gs-usb-monitor.ccf").read_text(encoding="utf-8")
top = (root / "rtl/top-ulx5m-gs-usb-monitor.v").read_text(encoding="utf-8")
phy = (root / "cores/usb/rtl/usb_phy.v").read_text(encoding="utf-8")
make = (root / "Makefile.ulx5m-gs").read_text(encoding="utf-8")
sdc = (root / "data/top-ulx5m-gs-usb-monitor.sdc").read_text(encoding="utf-8")
for name, content in (("ccf", ccf), ("top", top), ("phy", phy), ("make", make), ("sdc", sdc)):
    verify(content.isascii() and "\r" not in content, name + " must be ASCII LF")

# Guard against incremental archives omitting build dependencies.
# Read source file lists from the Makefile, so new source files are covered.
for src_var in ("SRC", "USB_SRC"):
    match = re.search(r"^" + src_var + r"\s*:=\s*(.*)$", make, re.M)
    if match is None:
        errors.append("Makefile lacks " + src_var + " source list")
        continue
    for source in match.group(1).split():
        verify((root / source).is_file(),
               "Makefile " + src_var + " references missing file: " + source)
for constraint in ("data/top-ulx5m-gs-bringup.ccf",
                   "data/top-ulx5m-gs-bringup.sdc"):
    verify((root / constraint).is_file(), "missing build constraint: " + constraint)

ports = dict(re.findall(r'^Pin_(?:in|out|inout)\s+"([^"]+)"\s+Loc\s*=\s*"([^"]+)"', ccf, re.M))
expected = {
    "clk25": "IO_SB_A8", "btn0_n": "IO_EA_B4",
    "usb_dp": "IO_EA_A1", "usb_dn": "IO_EA_B1",
    **{f"led_n[{i}]": f"IO_SB_{'A' if i % 2 == 0 else 'B'}{i // 2}" for i in range(8)},
}
verify(ports == expected, "monitor CCF pin mapping mismatch")
verify(len(set(ports.values())) == len(ports), "duplicate CCF locations")
verify("IO_EA_A0" not in ports.values() and "IO_EA_B0" not in ports.values(),
       "duplicate USB data pads must not be constrained")
verify('Pin_inout "usb_dp"' in ccf and 'Pin_inout "usb_dn"' in ccf,
       "USB data pads must be tristate-capable")
verify(".tx_en(1'b0)" in top, "USB pad monitor must not enable TX")
verify(".TARGET(\"GATEMATE\")" in top, "must use GateMate USB PHY")
verify("usb_pull" not in re.sub(r'/\*[\s\S]*?\*/', '', top),
       "USB pad monitor must not drive pullup pads")
verify(".V_IO(\"3.3\")" in phy and phy.count('.V_IO("3.3")') >= 2,
       "GateMate USB I/O must specify V_IO 3.3")
verify("usb-monitor: $(USB_BIT)" in make, "missing isolated USB monitor target")
# usb_phy defaults to ICE40; eager elaboration creates unsupported SB_IO cells.
# Yosys must resolve the top-level TARGET=GATEMATE override first.
verify("read_verilog -defer $(USB_SRC); synth_gatemate -top $(USB_TOP)" in make,
       "USB monitor must defer Verilog elaboration to avoid ICE40 SB_IO")
verify("flash dfu:" in make and "@exit 1" in make,
       "original flash/dfu disabled-target guard missing")
verify("-period 40.000" in sdc, "USB monitor needs 25 MHz SDC")

if args.pcb:
    if not args.pcb.is_file():
        errors.append("PCB not found: " + str(args.pcb))
    else:
        pcb = args.pcb.read_text(encoding="utf-8")
        fp = get_footprint(pcb, "U4")
        pads = re.findall(
            r'\(pad "([^"]+)"[^\n]*[\s\S]*?\(net \d+ "([^\"]+)"\)\s*\(pinfunction "([^\"]+)"',
            fp
        )
        net_by_pin = {pin: net for _, net, pin in pads}
        for pin, net in {
            "IO_EA_A0": "/ethernet/USB25_P",
            "IO_EA_A1": "/ethernet/USB25_P",
            "IO_EA_B0": "/ethernet/USB25_N",
            "IO_EA_B1": "/ethernet/USB25_N",
            "IO_EA_A2": "/ethernet/USB_PULL_P",
            "IO_EA_B2": "/ethernet/USB_PULL_N",
            "VDD_EA": "+3V3",
            "CLK0/IO_SB_A8": "/lvds/CLK_25MHz",
        }.items():
            verify(net_by_pin.get(pin) == net,
                   "PCB U4 mismatch: " + pin + ": expected " + net)
        r58 = get_footprint(pcb, "R58")
        verify("exclude_from_bom dnp" in r58,
               "R58 USB fixed pullup is not DNP in supplied PCB")
        for ref in ("R141", "R142"):
            footprint = get_footprint(pcb, ref)
            verify('(property "Value" "0R"' in footprint,
                   ref + " USB series link is not 0 ohm")
        verify('(property "Value" "ASE2-25.000MHZ-L-C-T"' in get_footprint(pcb, "Y1"),
               "PCB 25 MHz oscillator type changed")
        print("[PASS] KiCad V005 duplicate USB pins, 3.3V bank, DNP R58 and 25MHz oscillator")

if errors:
    for error in errors:
        print("[FAIL] " + error, file=sys.stderr)
    sys.exit(1)
print("[PASS] Stage 3 RX-only USB monitor and constraints")
print("[PASS] " + str(len(ports)) + " unique constrained pads, no flash or USB attach")
