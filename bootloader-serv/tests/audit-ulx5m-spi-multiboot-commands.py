#!/usr/bin/env python3
"""Offline gmpack SPI multiboot command audit; no output bitstreams retained.

Strictly check CMD_JUMP for --bootaddr alone. Report, but do not assume,
CMD_JUMP semantics when --background is combined with --bootaddr.
This checks stream bytes/CRC, not board straps, flash layout, or SPI boot.
Do not program any generated stream from this tool.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

EXPECTED_BIT_SHA = "68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd"
EXPECTED_IMPL_SHA = "55589d04d383f57fa3108c758c01de963b6cb2d0cb8142729cb6cc8c8430c7f4"
EXPECTED_BIT_SIZE = 3026
EXPECTED_IMPL_SIZE = 8987
SECONDARY_ADDR = 0x200000
COMMANDS = {0xc3: "CMD_CFGRST", 0xda: "CMD_JUMP", 0xdb: "CMD_CHG_STATUS"}
VARIANTS = (
    ("default", ()),
    ("bootaddr", ("--bootaddr", str(SECONDARY_ADDR))),
    ("background", ("--background",)),
    ("bootaddr_background", ("--bootaddr", str(SECONDARY_ADDR), "--background")),
)


def sha256(payload):
    return hashlib.sha256(payload).hexdigest()


def crc16_x25(data):
    crc = 0xffff
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = (crc >> 1) ^ (0x8408 if (crc & 1) else 0)
    return crc ^ 0xffff


def parse_command(payload, offset):
    if offset < 0 or offset + 6 > len(payload):
        return None
    opcode = payload[offset]
    size = payload[offset + 1]
    if opcode not in COMMANDS or size > 64 or offset + 6 + size > len(payload):
        return None
    end = offset + 6 + size
    head = payload[offset:offset + 2]
    body = payload[offset:offset + 4 + size]
    if int.from_bytes(payload[offset + 2:offset + 4], "little") != crc16_x25(head):
        return None
    if int.from_bytes(payload[end - 2:end], "little") != crc16_x25(body):
        return None
    data = payload[offset + 4:end - 2]
    result = {"command": COMMANDS[opcode], "offset": "0x%x" % offset,
              "bytes": size, "payload_hex": data.hex()}
    if opcode == 0xda and size == 4:
        result["target_le"] = "0x%08x" % int.from_bytes(data, "little")
        result["target_be"] = "0x%08x" % int.from_bytes(data, "big")
    if opcode == 0xdb and size >= 1:
        result["status"] = "0x%02x" % data[0]
    return result


def find_commands(payload):
    return [cmd for offset in range(len(payload))
            if (cmd := parse_command(payload, offset)) is not None]


def find_diff(a, b):
    prefix = 0
    while prefix < min(len(a), len(b)) and a[prefix] == b[prefix]:
        prefix += 1
    suffix = 0
    while (suffix < min(len(a), len(b)) - prefix
           and a[len(a) - suffix - 1] == b[len(b) - suffix - 1]):
        suffix += 1
    return {"first_diff": None if a == b else "0x%x" % prefix,
            "size_delta": len(b) - len(a), "common_suffix": suffix}


def jump_opcode_windows(payload, limit=8):
    """Raw 0xDA locations are clues, not verified CMD_JUMP records."""
    return [{"offset": "0x%x" % i,
             "near_hex": payload[max(0, i - 8):min(len(payload), i + 18)].hex()}
            for i, byte in enumerate(payload) if byte == 0xda][:limit]


def difference_windows(reference, candidate):
    """Bounded context around first changed byte, including insertions."""
    change = find_diff(reference, candidate)
    if change["first_diff"] is None:
        return {"reference_hex": "", "candidate_hex": ""}
    pos = int(change["first_diff"], 16)
    return {"reference_hex": reference[max(0, pos - 8):pos + 32].hex(),
            "candidate_hex": candidate[max(0, pos - 8):pos + 32].hex()}


def verify_inputs(bit_path, implementation_path):
    bit = Path(bit_path).read_bytes()
    implementation = Path(implementation_path).read_bytes()
    if len(bit) != EXPECTED_BIT_SIZE or sha256(bit) != EXPECTED_BIT_SHA:
        raise ValueError("reference image differs from JTAG-working walking-LED bitstream")
    if len(implementation) != EXPECTED_IMPL_SIZE or sha256(implementation) != EXPECTED_IMPL_SHA:
        raise ValueError("nextpnr implementation differs from pinned walking-LED source")
    return bit


def audit(implementation_path, reference, packer="gmpack", runner=None):
    """All candidate bitstreams exist only within the TemporaryDirectory."""
    if runner is None:
        runner = subprocess.run
    report = {}
    with tempfile.TemporaryDirectory(prefix="ulx5m-spi-multiboot-audit-") as tmp:
        for name, flags in VARIANTS:
            output = Path(tmp) / (name + ".bit")
            cmd = [packer, *flags, str(implementation_path), str(output)]
            result = runner(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            check=False, text=True)
            if result.returncode != 0:
                raise RuntimeError("gmpack variant %s failed: %s" % (name, result.stderr.strip()))
            if not output.is_file():
                raise RuntimeError("gmpack did not produce variant %s" % name)
            candidate = output.read_bytes()
            if not candidate:
                raise ValueError("gmpack generated empty variant %s" % name)
            if name == "default" and candidate != reference:
                raise ValueError("default packer output did not reproduce JTAG-working reference")
            commands = find_commands(candidate)
            jumps = [c for c in commands if c["command"] == "CMD_JUMP"]
            has_jump = any(
                c.get("target_le") == "0x%08x" % SECONDARY_ADDR or
                c.get("target_be") == "0x%08x" % SECONDARY_ADDR for c in jumps
            )
            # The stand-alone --bootaddr option advertises a jump. Do not
            # require that --background combined with --bootaddr uses the
            # same record layout or command sequence; record it as unknown.
            if name == "bootaddr" and not has_jump:
                raise ValueError("variant %s lacks a CRC-valid jump to 0x%06x" %
                                 (name, SECONDARY_ADDR))
            report[name] = {"flags": list(flags), "bytes": len(candidate),
                            "sha256": sha256(candidate),
                            "change": find_diff(reference, candidate),
                            "first_difference_windows": difference_windows(reference, candidate),
                            "has_verified_jump_to_secondary": has_jump,
                            "jump_opcode_windows": jump_opcode_windows(candidate),
                            "first_32_hex": candidate[:32].hex(),
                            "last_48_hex": candidate[-48:].hex(),
                            "interesting_commands": commands}
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bit", required=True, type=Path)
    parser.add_argument("--implementation", required=True, type=Path)
    parser.add_argument("--packer", default="gmpack")
    args = parser.parse_args(argv)
    try:
        baseline = verify_inputs(args.bit, args.implementation)
        report = audit(args.implementation, baseline, args.packer)
    except (ValueError, RuntimeError, OSError) as error:
        parser.exit(1, "[FAIL] %s\n" % error)
    print("[PASS] Pinned JTAG-working bitstream and nextpnr input")
    print("[PASS] Default gmpack output is byte-identical to the working image")
    print("[PASS] Standalone --bootaddr contains a CRC-verified CMD_JUMP to 0x200000")
    if report["bootaddr_background"]["has_verified_jump_to_secondary"]:
        print("[OBSERVED] --bootaddr --background also contains a CRC-valid jump to 0x200000")
    else:
        print("[OBSERVED] --bootaddr --background has NO CRC-valid jump to 0x200000")
        print("[UNKNOWN] Combined option semantics may differ; do not install this image")
    for name, record in report.items():
        change = record["change"]
        print("[%s] bytes=%d first=%s delta=%+d sha256=%s" %
              (name, record["bytes"], change["first_diff"], change["size_delta"], record["sha256"]))
        for command in record["interesting_commands"]:
            if command["command"] in ("CMD_CFGRST", "CMD_JUMP"):
                print("  %s offset=%s payload=%s" %
                      (command["command"], command["offset"], command["payload_hex"]))
        if name == "bootaddr_background":
            print("  first32=%s" % record["first_32_hex"])
            print("  last48=%s" % record["last_48_hex"])
            print("  raw_0xda=%s" % ",".join(x["offset"] for x in record["jump_opcode_windows"]))
            print("  changed_ref=%s" % record["first_difference_windows"]["reference_hex"])
            print("  changed_combined=%s" % record["first_difference_windows"]["candidate_hex"])
    print("[BLOCK] Temporary files deleted. No JTAG, FPGA, USB, or SPI flash operations.")
    print("[UNKNOWN] CRC-valid commands do not prove SPI boot, option precedence, or recovery")
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
