#!/usr/bin/env python3
"""Read-only audit of the known-good walking-LED GateMate gmpack stream.

Runs gmpack on a pinned nextpnr .txt in a temporary directory ONLY.
Generated variants must never be used for FPGA programming or flash writes.
This script is not a complete GateMate configuration parser.
"""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

BIT_HASH = "68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd"
TEXT_HASH = "55589d04d383f57fa3108c758c01de963b6cb2d0cb8142729cb6cc8c8430c7f4"
PROBE_HASH = "c298999e6a19604018f0b8be8ceadb3572b95b00d90475c1017fd3a037e9ff84"
BIT_SIZE = 3026
TEXT_SIZE = 8987
COMMAND_NAMES = {0xDB: "CMD_CHG_STATUS", 0xC3: "CMD_CFGRST", 0xDA: "CMD_JUMP"}
VARIANTS = (
    ("default", ()),
    ("reconfig", ("--reconfig",)),
    ("reset", ("--reset",)),
    ("reset_reconfig", ("--reset", "--reconfig")),
)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def load_reference(bit_path, text_path):
    bit = Path(bit_path).read_bytes()
    text = Path(text_path).read_bytes()
    if len(bit) != BIT_SIZE or sha256(bit) != BIT_HASH:
        raise ValueError("walking-LED .bit does not match hardware-validated reference")
    if len(text) != TEXT_SIZE or sha256(text) != TEXT_HASH:
        raise ValueError("walking-LED .txt does not match reference nextpnr output")
    return bit


def crc16_x25(data):
    crc = 0xffff
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = (crc >> 1) ^ (0x8408 if crc & 1 else 0)
    return crc ^ 0xffff


def parse_command(data, offset):
    """Recognize CRC-verified gmpack-style commands; not arbitrary stream grammar."""
    if offset < 0 or offset + 6 > len(data):
        return None
    opcode, length = data[offset:offset + 2]
    if opcode not in COMMAND_NAMES or length > 64:
        return None
    end = offset + 4 + length + 2
    if end > len(data):
        return None
    header_crc = int.from_bytes(data[offset + 2:offset + 4], "little")
    full_crc = int.from_bytes(data[end - 2:end], "little")
    if crc16_x25(data[offset:offset + 2]) != header_crc:
        return None
    if crc16_x25(data[offset:end - 2]) != full_crc:
        return None
    payload = data[offset + 4:end - 2]
    result = {
        "offset": offset,
        "name": COMMAND_NAMES[opcode],
        "payload_hex": payload.hex(),
        "payload_size": len(payload),
        "end": end,
    }
    if opcode == 0xDB and len(payload) >= 2:
        result["status_byte"] = "0x%02x" % payload[0]
        result["mode_byte"] = "0x%02x" % payload[1]
        result["reconfig_status_bit"] = bool(payload[0] & 0x08)
    if opcode == 0xDA and len(payload) == 4:
        result["jump_address"] = "0x%08x" % int.from_bytes(payload, "little")
    return result


def scan_tail(data, window=256):
    return [cmd for off in range(max(0, len(data) - window), len(data))
            if (cmd := parse_command(data, off)) is not None]


def check_source_probe(path):
    data = Path(path).read_bytes()
    if sha256(data) != PROBE_HASH:
        raise ValueError("v26 probe .bit does not match the corrected hardware-loaded SHA-256")
    commands = [c for c in scan_tail(data) if c["name"] == "CMD_CHG_STATUS"]
    if len(commands) != 1 or not commands[0].get("reconfig_status_bit"):
        raise ValueError("the v26 source bitstream does not set its reconfig status bit")
    return {"length": len(data), "sha256": sha256(data),
            "status_command": commands[0]}


def difference(a, b):
    prefix = 0
    while prefix < min(len(a), len(b)) and a[prefix] == b[prefix]:
        prefix += 1
    suffix = 0
    remaining = min(len(a), len(b)) - prefix
    while suffix < remaining and a[len(a) - suffix - 1] == b[len(b) - suffix - 1]:
        suffix += 1
    return {
        "size_delta": len(b) - len(a),
        "common_prefix": prefix,
        "common_suffix": suffix,
        "first_difference": None if a == b else "0x%x" % prefix,
        "reference_changed_window": a[prefix:len(a) - suffix if suffix else len(a)].hex(),
        "variant_changed_window": b[prefix:len(b) - suffix if suffix else len(b)].hex(),
    }


def pack_variants(implementation, reference, packer="gmpack"):
    results = {}
    with tempfile.TemporaryDirectory(prefix="ulx5m-cfg-audit-") as directory:
        for name, flags in VARIANTS:
            output = Path(directory) / (name + ".bit")
            cmd = [packer, *flags, str(implementation), str(output)]
            proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                  text=True, check=False)
            if proc.returncode != 0:
                raise RuntimeError("gmpack failed for %s (exit %d): %s" %
                                   (name, proc.returncode, proc.stderr.strip()))
            if not output.is_file():
                raise RuntimeError("gmpack did not create %s" % name)
            payload = output.read_bytes()
            if name == "default" and payload != reference:
                raise ValueError("default gmpack output differs from JTAG-proven image; stop")
            tail = scan_tail(payload)
            if not any(c["name"] == "CMD_CHG_STATUS" for c in tail):
                raise ValueError("no CRC-verified CMD_CHG_STATUS in tail: %s" % name)
            results[name] = {
                "flags": list(flags),
                "length": len(payload),
                "sha256": sha256(payload),
                "difference_from_default": difference(reference, payload),
                "tail_commands": tail,
            }
    if results["reconfig"]["sha256"] == results["default"]["sha256"]:
        raise ValueError("--reconfig had no effect in installed gmpack; stop")
    return results


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bit", required=True, type=Path)
    parser.add_argument("--implementation", required=True, type=Path)
    parser.add_argument("--source-probe-bit", required=True, type=Path)
    parser.add_argument("--packer", default="gmpack",
                        help="gmpack executable, defaults to gmpack on PATH")
    args = parser.parse_args(argv)
    try:
        reference = load_reference(args.bit, args.implementation)
        source = check_source_probe(args.source_probe_bit)
        results = pack_variants(args.implementation, reference, args.packer)
    except (OSError, ValueError, RuntimeError) as exc:
        parser.exit(1, "[FAIL] %s\n" % exc)
    print("[PASS] Input SHA-256 and length match known JTAG-working image")
    print("[PASS] Corrected v26 source probe has reconfig status bit set")
    print("[source] " + json.dumps(source, sort_keys=True))
    print("[PASS] Default gmpack exactly reproduced the original .bit")
    for name, result in results.items():
        diff = result["difference_from_default"]
        print("[%s] bytes=%d sha256=%s delta=%+d first=%s" %
              (name, result["length"], result["sha256"], diff["size_delta"],
               diff["first_difference"]))
        for cmd in result["tail_commands"]:
            print("  %s offset=0x%x payload=%s" %
                  (cmd["name"], cmd["offset"], cmd["payload_hex"]))
    print("[BLOCK] These variants are ONLY temporary offline comparisons; no programming")
    print(json.dumps(results, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
