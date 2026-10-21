#!/usr/bin/env python3
"""Static guards for the ULX5M-GS USB enumeration-only SoC."""
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1]
errors = []


def check(condition, description):
    if not condition:
        errors.append(description)


def source(path):
    p = root / path
    check(p.is_file(), "missing " + path)
    if not p.is_file():
        return ""
    s = p.read_text(encoding="utf-8")
    check(s.isascii() and "\r" not in s, "not ASCII LF: " + path)
    return s


top = source("rtl/top-ulx5m-gs-usb-probe.v")
misc = source("rtl/soc_ulx5m_misc.v")
ccf = source("data/top-ulx5m-gs-usb-probe.ccf")
sdc = source("data/top-ulx5m-gs-usb-probe.sdc")
fw = source("fw/fw_ulx5m_probe.c")
fwdesc = source("fw/usb_desc_ulx5m_probe.c")
fwmake = source("fw/Makefile.ulx5m-gs")
standard = source("fw/usb_ctrl_std.c")
make = source("Makefile.ulx5m-gs")
usb = source("cores/usb/rtl/usb.v")
usb_trans = source("cores/usb/rtl/usb_trans.v")
response = source("rtl/soc_mem_response_reg.v")

pins = dict(re.findall(r'^Pin_(?:in|out|inout)\s+"([^"]+)"\s+Loc\s*=\s*"([^"]+)"', ccf, re.M))
expected = {
    "clk25": "IO_SB_A8",
    "btn_n[0]": "IO_EA_B4",
    "btn_n[1]": "IO_EA_A4",
    "btn_n[2]": "IO_EA_B3",
    "usb_dp": "IO_EA_A1",
    "usb_dn": "IO_EA_B1",
    "usb_pull_p": "IO_EA_A2",
    **{f"led_n[{i}]": f"IO_SB_{'A' if i % 2 == 0 else 'B'}{i//2}" for i in range(8)},
}
check(pins == expected, "ULX5M-GS V005 probe CCF mapping changed")
check(len(set(pins.values())) == len(pins), "duplicate constrained FPGA pads")
check("usb_pull_n" not in top and "usb_pull_n" not in pins, "negative USB pull control must stay unused")
check("IO_EA_A0" not in pins.values() and "IO_EA_B0" not in pins.values(),
      "duplicate USB data pads must be unassigned")
check("Pin_inout \"usb_pull_p\"" in ccf, "pull control needs high-Z capability")
check(".T(~usb_attach | reset)" in top and ".A(1'b1)" in top,
      "attach pad must be high or high-Z, never low")
check(".TARGET(\"GATEMATE\")" in top, "GateMate PHY override missing")
check(".INIT_FILE(\"build-ulx5m-gs/fw_ulx5m_probe.hex\")" in top,
      "firmware BRAM is not initialized from probe image")
for module in ("picorv32", "soc_bridge", "soc_bram", "uart_wb", "usb #", "soc_ulx5m_misc"):
    check(module in top, "missing SoC module " + module)
for dangerous in ("qspi_phy", "qspi_master", "flash_csn", "flash_sck", "flash_mosi", "flash_miso", "CC_CFG_CTRL"):
    check(dangerous not in top and dangerous not in ccf,
          "flash access must not be connected: " + dangerous)
check("USB_RT_DFU_DNLOAD:" in fw and "USB_RT_DFU_UPLOAD:" in fw and "return USB_FND_ERROR;" in fw,
      "DFU transfer requests must be rejected")
check("flash_" not in fw and "spi_" not in fw, "probe FW must not use flash/SPI services")
check("usb_connect();" in fw, "probe firmware must request USB attach")
check("_dfu_tick(void) {}" in fw, "USB polling must use an empty DFU tick")
check(".bmAttributes = 0x08" in fwdesc, "probe descriptor must deny upload/download")
check(".bAlternateSetting = 0" in fwdesc, "probe must expose only alt 0")
check(".wTotalLength = sizeof(probe_conf)" in fwdesc, "descriptor total length mismatch")
check("-DBOARD_ULX5M_GS=1" in fwmake, "ULX5M USB standard request fixes not enabled")
check("#ifdef BOARD_ULX5M_GS" in standard, "ULX5M-specific USB request guards absent")
check(".COMPRESSED_ISA(0)" in top and "-march=rv32i " in fwmake,
      "GateMate probe CPU/firmware must both use uncompressed RV32I")
check(".ENABLE_REGS_DUALPORT(1)" in top,
      "GateMate probe must use dual-port PicoRV32 register-file reads")
check(".WB_REG(4)" in top,
      "ULX5M probe must register Wishbone acknowledge and read data")
check(".TWO_CYCLE_ALU(1)" not in top and ".TWO_CYCLE_COMPARE(1)" not in top,
      "v13 timing regression must be reverted")
check("soc_mem_response_reg response_i" in top and
      ".cpu_valid(mem_valid)" in top and ".cpu_ready(mem_ready)" in top and
      ".bridge_valid(bridge_valid)" in top and ".bridge_ready(bridge_ready)" in top and
      ".bridge_rdata(bridge_rdata)" in top and
      ".pb_valid(bridge_valid)" in top and ".pb_ready(bridge_ready)" in top and
      ".pb_rdata(bridge_rdata)" in top,
      "registered CPU memory response must sit between PicoRV32 and bridge")
check("assign bridge_valid = cpu_valid && !accepted;" in response and
      "rdata_q <= bridge_rdata;" in response and "ready_q <= 1'b1;" in response and
      "if (!cpu_valid)" in response and "accepted <= 1'b0;" in response,
      "response stage must register read data / ack and suppress duplicate requests")
check("rtl/soc_mem_response_reg.v" in make,
      "response stage missing from GateMate synthesis source list")
check("$(SRCS) lnk-app.lds Makefile.ulx5m-gs |" in fwmake,
      "firmware Makefile must trigger ELF rebuild when ISA flags change")
check("fw_dfu.c" not in fwmake and "usb_dfu.c" not in fwmake and "spi.c" not in fwmake,
      "unsafe flash-capable firmware source linked")
check("usb-probe: $(PROBE_BIT)" in make and
      "$(PROBE_JSON): $(PROBE_SRC) $(PROBE_FW) $(PROBE_MC)" in make,
      "firmware/microcode-before-synthesis dependency missing")
check("PROBE_MC := $(BUILD_DIR)/usb_trans_mc.hex" in make and
      "python3 $< > $@" in make, "USB transaction microcode generation missing")
check('.MC_INIT_FILE("build-ulx5m-gs/usb_trans_mc.hex")' in top and
      ".MC_INIT_FILE(MC_INIT_FILE)" in usb and
      "$readmemh(MC_INIT_FILE, rom)" in usb_trans and
      'MC_INIT_FILE = "usb_trans_mc.hex"' in usb_trans,
      "USB transaction ROM path not propagated to GateMate")
for dependency in ("glitch_filter.v", "ram_sdp.v", "fifo_sync_shift.v"):
    path = "cores/misc/rtl/" + dependency
    check(path in make, "USB probe source list missing " + path)
    check((root / path).is_file(), "USB probe dependency not found: " + path)
check("read_verilog -defer -Icores/usb/rtl $(PROBE_SRC)" in make,
      "probe USB PHY must defer parameter elaboration")
check("flash dfu:" in make and "@exit 1" in make, "flash targets must remain disabled")
check("-period 40.000" in sdc, "25 MHz oscillator SDC missing")

if errors:
    for error in errors:
        print("[FAIL] " + error, file=sys.stderr)
    sys.exit(1)
print("[PASS] USB enumeration probe: firmware, CCF and SoC sources")
print("[PASS] " + str(len(pins)) + " unique pins; no connected flash access")
print("[PASS] DFU upload/download rejected; only D+ pullup controllable")
