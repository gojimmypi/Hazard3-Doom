#!/usr/bin/env python3
"""Audit frozen ULX5M-GS configuration experiments, without hardware access.

This is not a GateMate configuration controller emulator. It checks the
unmodified binaries and prints evidence for reviewing the handoff mechanism.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

APP_SHA = "68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd"
RECONFIG_SHA = "2400c521eb10acd5e496f327e2366c36c3849548891033ce6891fc73469f5eac"
SOURCE_SHA = "24fdc177d67278c26ca3299566a98f6d112809d1f2a6a4fa90ef91c29e67d097"
APP_SIZE = 3026
STATUS_COMMAND_SIZE = 18
STATUS_COMMAND_OFFSET = 2999
MODIFIED_START = 3003
MODIFIED_END = 3017
EPILOGUE = bytes.fromhex("000000003300000000")


def crc16_x25(data):
    crc = 0xffff
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = (crc >> 1) ^ (0x8408 if crc & 1 else 0)
    return crc ^ 0xffff


def status_command(data, offset):
    if offset < 0 or offset + STATUS_COMMAND_SIZE > len(data):
        raise ValueError("status command missing or truncated")
    part = data[offset:offset + STATUS_COMMAND_SIZE]
    if part[:2] != b"\xdb\x0c":
        raise ValueError("unexpected status command opcode or length")
    if crc16_x25(part[:2]) != int.from_bytes(part[2:4], "little"):
        raise ValueError("status header CRC mismatch")
    if crc16_x25(part[:16]) != int.from_bytes(part[16:18], "little"):
        raise ValueError("status payload CRC mismatch")
    return part[4:16]


def check_binary(data, length, digest, label):
    if length is not None and len(data) != length:
        raise ValueError("%s size mismatch: %d" % (label, len(data)))
    actual = hashlib.sha256(data).hexdigest()
    if actual != digest:
        raise ValueError("%s SHA-256 mismatch: %s" % (label, actual))


def audit_images(default, reconfig, source, rtl_text):
    check_binary(default, APP_SIZE, APP_SHA, "default destination")
    check_binary(reconfig, APP_SIZE, RECONFIG_SHA, "reconfig destination")
    check_binary(source, None, SOURCE_SHA, "v30 source probe")
    if default[:MODIFIED_START] != reconfig[:MODIFIED_START]:
        raise ValueError("unexpected changes before reconfig status payload")
    if default[MODIFIED_END:] != reconfig[MODIFIED_END:]:
        raise ValueError("unexpected changes after reconfig status CRC")
    if default[:STATUS_COMMAND_OFFSET] != reconfig[:STATUS_COMMAND_OFFSET]:
        raise ValueError("unexpected change before status command")
    if default[-len(EPILOGUE):] != EPILOGUE:
        raise ValueError("default epilogue differs from verified reference")
    a = status_command(default, STATUS_COMMAND_OFFSET)
    b = status_command(reconfig, STATUS_COMMAND_OFFSET)
    if a != bytes.fromhex("131f00200000000000000000"):
        raise ValueError("default status payload unexpected")
    if b != bytes.fromhex("1b1f00200000000000000000"):
        raise ValueError("reconfig status payload unexpected")
    if "CC_CFG_CTRL" not in rtl_text or not re.search(
            r"\.RECFG\s*\(\s*1'b1\s*\)", rtl_text):
        raise ValueError("source RTL must instantiate CC_CFG_CTRL with RECFG=1")
    if "state == FINISHED" not in rtl_text:
        raise ValueError("source RTL FINISHED indicator cannot be confirmed")
    # The user bitstream was built using gmpack --reconfig. Verify the actual
    # CRC-protected terminal command, not merely the command-line claim.
    if len(source) < STATUS_COMMAND_SIZE + len(EPILOGUE):
        raise ValueError("source probe stream too short")
    source_status_offset = len(source) - STATUS_COMMAND_SIZE - len(EPILOGUE)
    s = status_command(source, source_status_offset)
    if s[0] != 0x1b or s[1] != 0x1f:
        raise ValueError("source does not have expected reconfig status")
    if source[-len(EPILOGUE):] != EPILOGUE:
        raise ValueError("source probe epilogue unexpected")
    return {
        "app_default": {"size": len(default), "sha256": APP_SHA, "status": "0x13",
                        "hardware_jtag": "walking LEDs verified",
                        "hardware_internal": "probe remains active"},
        "app_reconfig": {"size": len(reconfig), "sha256": RECONFIG_SHA,
                         "status": "0x1b", "changed_range": [MODIFIED_START, MODIFIED_END],
                         "hardware_jtag": "walking LEDs verified",
                         "hardware_internal": "probe remains active"},
        "source_probe": {"size": len(source), "sha256": SOURCE_SHA,
                         "status": "0x1b", "reconfig_pin": 1,
                         "transmitter_finished": True,
                         "configuration_accepted": "not observable through CC_CFG_CTRL"},
        "vendor_question": "Can CC_CFG_CTRL replace the complete CPE fabric containing its own "
                           "transmitter, or only a nonoverlapping region? What is the "
                           "supported command and reset sequence?",
        "hardware_status_signals": {
            "CFG_DONE": "V3 - consult the board schematic for access",
            "CFG_FAILED_N": "V2 - consult the board schematic for access"},
        "safety": "No FPGA command, JTAG, USB, SPI flash, or live reconfiguration performed"
    }


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--default-bit", type=Path, required=True)
    p.add_argument("--reconfig-bit", type=Path, required=True)
    p.add_argument("--source-bit", type=Path, required=True)
    p.add_argument("--source-rtl", type=Path, required=True)
    p.add_argument("--json-out", type=Path, help="optional create-only report")
    args = p.parse_args(argv)
    try:
        report = audit_images(args.default_bit.read_bytes(),
                              args.reconfig_bit.read_bytes(),
                              args.source_bit.read_bytes(),
                              args.source_rtl.read_text(encoding="utf-8"))
        if args.json_out:
            with args.json_out.open("x", encoding="utf-8", newline="\n") as out:
                json.dump(report, out, indent=2, sort_keys=True)
                out.write("\n")
        print("[PASS] Exact hardware-tested destination images and hashes")
        print("[PASS] Status commands validated with CRC16/X25")
        print("[PASS] Only the expected terminal reconfig status/CRC window differs")
        print("[PASS] Exact hardware-tested v30 source and reconfig status")
        print("[PASS] RECFG=1 and source FINISHED indicator confirmed")
        print("[OBSERVED] Both images run via JTAG; neither took over via CC_CFG_CTRL")
        print("[UNKNOWN] CFG_DONE / CFG_FAILED_N levels during internal attempt")
        print("[QUESTION] " + report["vendor_question"])
        print("[BLOCK] No FPGA, JTAG, USB, or SPI flash operations")
        return 0
    except (OSError, ValueError, UnicodeError) as exc:
        print("[REJECT] " + str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
