#!/usr/bin/env python3
"""Decode the VERIFIED seed-147 GateMate gmpack command trailer (offline only).

NOT a full bitstream parser. NOT authorization to boot, reconfigure or write flash.
"""

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

# Absolute file offsets measured in the frozen seed-147 build.
STATUS_OFFSET = 0x65478
GOLDEN_SIZE = 414867
APPENDED_SIZE = 19
STATUS_LEN = 12
# Nine bytes after CMD_CHG_STATUS CRC2: NOP and execute/padding bytes.
STATUS_EPILOGUE = bytes.fromhex("00 00 00 00 33 00 00 00 00")
STATUS_PAYLOAD_TAIL = bytes.fromhex("08 21 c3 00 00 00 00 00 00 00")
VARIANT_INFO = {
    "default": (0x13, GOLDEN_SIZE,
                "8232dd932ff2ea40b2945de6ed1202be5e7dc75960464419cc0ffa95a75901f8"),
    "reconfig": (0x1B, GOLDEN_SIZE,
                 "2af381aa97902a7f26acdc90647c2a22c95962b9dbabc02b13cde1e7ba66050f"),
    "bootaddr_probe": (0x17, GOLDEN_SIZE + APPENDED_SIZE,
                       "d7d601a7f6aebf550f6f484ef4a604acb5cff4a0f3e1ef9161cf531d7e301a33"),
    "reconfig_bootaddr_probe": (0x1F, GOLDEN_SIZE + APPENDED_SIZE,
                                "999c6b55aa26888e6c07514e237c87bb0586b131aac7a7cdaf407495975f98fd"),
}
COMMAND_NAMES = {0xDB: "CMD_CHG_STATUS", 0xC3: "CMD_CFGRST", 0xDA: "CMD_JUMP"}


def crc16_x25(data):
    """Reflected CRC-16/ISO-HDLC: poly 0x8408, init/xorout 0xffff."""
    crc = 0xFFFF
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = (crc >> 1) ^ (0x8408 if crc & 1 else 0)
    return crc ^ 0xFFFF


def parse_command(data, pos, expected_cmd, expected_length):
    """Parse only the three known fixed-size commands at a known offset."""
    if pos < 0 or pos + 6 + expected_length > len(data):
        raise ValueError("incomplete command at 0x%x" % pos)
    cmd = data[pos]
    length = data[pos + 1]
    if cmd != expected_cmd or length != expected_length:
        raise ValueError("unexpected command/length at 0x%x" % pos)
    # Verified on the actual gmpack bytes: CRC fields are low-byte first.
    header_crc = int.from_bytes(data[pos + 2:pos + 4], "little")
    if crc16_x25(data[pos:pos + 2]) != header_crc:
        raise ValueError("header CRC mismatch at 0x%x" % pos)
    data_end = pos + 4 + length
    full_crc = int.from_bytes(data[data_end:data_end + 2], "little")
    if crc16_x25(data[pos:data_end]) != full_crc:
        raise ValueError("command CRC mismatch at 0x%x" % pos)
    return ({"name": COMMAND_NAMES[cmd], "offset": pos, "opcode": "0x%02x" % cmd,
             "length": length, "data_hex": data[pos + 4:data_end].hex(),
             "header_crc": "0x%04x" % header_crc,
             "full_crc": "0x%04x" % full_crc,
             "crc_byte_order": "little"}, data_end + 2)


def decode_one(image, name, golden):
    if name not in VARIANT_INFO:
        raise ValueError("unrecognized variant: %s" % name)
    status, size, _ = VARIANT_INFO[name]
    if len(image) != size:
        raise ValueError("unexpected size: %s" % name)
    if len(golden) != GOLDEN_SIZE:
        raise ValueError("invalid golden length")
    if image[:STATUS_OFFSET] != golden[:STATUS_OFFSET]:
        raise ValueError("unexpected changes before CMD_CHG_STATUS: %s" % name)

    block, next_pos = parse_command(image, STATUS_OFFSET, 0xDB, STATUS_LEN)
    payload = image[STATUS_OFFSET + 4:STATUS_OFFSET + 4 + STATUS_LEN]
    expected_mode = 0x10 if status & 0x04 else 0x1F
    if payload != bytes([status, expected_mode]) + STATUS_PAYLOAD_TAIL:
        raise ValueError("unexpected status payload: %s" % name)
    if image[next_pos:GOLDEN_SIZE] != STATUS_EPILOGUE:
        raise ValueError("unexpected status epilogue: %s" % name)

    commands = [block]
    if status & 0x04:
        reset, pos = parse_command(image, GOLDEN_SIZE, 0xC3, 1)
        if image[GOLDEN_SIZE + 4:GOLDEN_SIZE + 5] != b"\x00":
            raise ValueError("unexpected CFGRST data")
        jump, pos = parse_command(image, pos, 0xDA, 4)
        address = int.from_bytes(bytes.fromhex(jump["data_hex"]), "little")
        if address != 0x200000:
            raise ValueError("unexpected jump address")
        if image[pos:] != b"\x00\x00":
            raise ValueError("unexpected jump epilogue")
        jump["address_observed"] = "0x%08x" % address
        jump["address_authorized"] = False
        commands += [reset, jump]
    elif len(image) != GOLDEN_SIZE:
        raise ValueError("unexpected data after status trailer")
    return {"name": name, "size": len(image), "sha256": hashlib.sha256(image).hexdigest(),
            "status_byte": "0x%02x" % status,
            "status_second_byte": "0x%02x" % expected_mode,
            "status_reconfig_mask_observed": bool(status & 0x08),
            "status_bootaddr_mask_observed": bool(status & 0x04),
            "commands": commands}


def analyze_images(images):
    if set(images) != set(VARIANT_INFO):
        raise ValueError("require default and all three specific variants")
    for name, (_, size, sha) in VARIANT_INFO.items():
        value = images[name]
        if len(value) != size or hashlib.sha256(value).hexdigest() != sha:
            raise ValueError("frozen variant size/hash mismatch: %s" % name)
    golden = images["default"]
    if any(images[n][:STATUS_OFFSET] != golden[:STATUS_OFFSET]
           for n in images if n != "default"):
        raise ValueError("unexpected change before trailer")
    entries = {name: decode_one(images[name], name, golden) for name in VARIANT_INFO}
    if (int(entries["reconfig"]["status_byte"], 16) ^
            int(entries["default"]["status_byte"], 16)) != 0x08:
        raise ValueError("reconfig mask differs from observed 0x08")
    if (int(entries["bootaddr_probe"]["status_byte"], 16) ^
            int(entries["default"]["status_byte"], 16)) != 0x04:
        raise ValueError("bootaddr mask differs from observed 0x04")
    return {"purpose": "OFFLINE TRAILER COMMAND FORENSICS; NOT BOOT AUTHORIZATION",
            "verified_byte_order": "little-endian CRC16/X25 on the frozen gmpack output",
            "stream_scope": "only frozen seed-147 terminal commands; NOT full-bitstream decode",
            "variants": entries,
            "hardware_handoff_verified": False,
            "persistent_recovery_verified": False,
            "secondary_slot_authorized": False}


def import_previous_validator():
    source = Path(__file__).with_name("analyze-ulx5m-gmpack-trailers.py")
    spec = importlib.util.spec_from_file_location("ulx5m_tail_v4", source)
    if spec is None or spec.loader is None:
        raise ValueError("Phase 4.2 trailer analyzer is required")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--offline-dir", required=True, type=Path)
    parser.add_argument("--golden-bit", type=Path, help="optional baseline path override")
    parser.add_argument("--implementation", type=Path, help="optional nextpnr .txt path override")
    parser.add_argument("--json-out", type=Path, help="optional create-only report path")
    args = parser.parse_args(argv)
    root = Path(__file__).resolve().parents[2]
    base = root / "bootloader-serv/build-ulx5m-gs/top_ulx5m_gs_flash_read-serv-dfu-hw-quad-btn2"
    try:
        validator = import_previous_validator()
        validator.validate(args.offline_dir,
                           args.golden_bit or Path(str(base) + ".bit"),
                           args.implementation or Path(str(base) + ".txt"))
        images = {name: validator.read_binary(args.offline_dir / (name + ".bit"))
                  for name in VARIANT_INFO}
        report = analyze_images(images)
        if args.json_out:
            # Create only after complete verification. Never overwrite inputs/reports.
            with args.json_out.open("x", encoding="utf-8", newline="\n") as out:
                json.dump(report, out, indent=2, sort_keys=True)
                out.write("\n")
        print("[PASS] Phase 4.2 reference hashes, default reproduction and variants metadata")
        print("[PASS] Frozen variant hashes and CRC-16/X-25 command blocks")
        for name, entry in report["variants"].items():
            cmd_summary = ", ".join(c["name"] for c in entry["commands"])
            print("[DECODE] %-25s status=%s commands=%s" %
                  (name, entry["status_byte"], cmd_summary))
            for command in entry["commands"]:
                detail = " address=" + command["address_observed"] if "address_observed" in command else ""
                print("         0x%06x %-14s data=%s CRC(header/full)=%s/%s%s" %
                      (command["offset"], command["name"], command["data_hex"],
                       command["header_crc"], command["full_crc"], detail))
        print("[NOTE] Commands decode; no full-fabric handoff, app authorization or recovery established")
        print("[NOTE] DO NOT PROGRAM THESE VARIANTS")
        return 0
    except (OSError, ValueError, TypeError, KeyError, ImportError) as error:
        print("[REJECT] %s" % error, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
