#!/usr/bin/env python3
"""Verify and show byte-level GateMate gmpack trailer differences (OFFLINE).

NOT a bitstream decoder. No reconfiguration, flash, USB, or JTAG operations.
"""

import argparse
import hashlib
import json
from pathlib import Path
import sys

GOLDEN_SHA256 = "8232dd932ff2ea40b2945de6ed1202be5e7dc75960464419cc0ffa95a75901f8"
IMPLEMENTATION_SHA256 = "3b1cca322420f5086a6f0695cc299660047a68740908a3f50f060ff6877c65b9"
GOLDEN_SIZE = 414867
GATEMATE_PREAMBLE = bytes.fromhex("d9 01 ed 96")
VARIANTS = ("reconfig", "bootaddr_probe", "reconfig_bootaddr_probe")
SIZES = {"reconfig": GOLDEN_SIZE, "bootaddr_probe": GOLDEN_SIZE + 19,
         "reconfig_bootaddr_probe": GOLDEN_SIZE + 19}
# Current measurement indicates changes near the end. Fail closed if that
# empirical observation changes: a broader change requires separate review.
TAIL_BOUND = 256
MAX_IMAGE_SIZE = 4 * 1024 * 1024


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read_binary(path, max_size=MAX_IMAGE_SIZE):
    if not path.is_file() or path.stat().st_size > max_size:
        raise ValueError("missing, nonregular, or oversized file: %s" % path)
    return path.read_bytes()


def common_prefix(a, b):
    limit = min(len(a), len(b))
    for i in range(limit):
        if a[i] != b[i]:
            return i
    return limit


def common_suffix(a, b, prefix):
    limit = min(len(a), len(b)) - prefix
    for i in range(limit):
        if a[-1 - i] != b[-1 - i]:
            return i
    return limit


def pair(a, b):
    prefix = common_prefix(a, b)
    suffix = common_suffix(a, b, prefix)
    result = {"a_size": len(a), "b_size": len(b),
              "same_prefix_bytes": prefix, "same_suffix_bytes": suffix,
              "a_middle_hex": a[prefix:len(a)-suffix if suffix else len(a)].hex(),
              "b_middle_hex": b[prefix:len(b)-suffix if suffix else len(b)].hex()}
    if len(a) == len(b):
        changes = [[i, a[i], b[i]] for i in range(len(a)) if a[i] != b[i]]
        result["same_offset_byte_changes"] = changes
    return result


def hexdump(data, start):
    # Offsets are absolute file offsets, never guessed packet boundaries.
    return ["%08x: %s" % (offset, " ".join("%02x" % x for x in data[offset:offset+16]))
            for offset in range(start, len(data), 16)]


def validate(run_dir, golden_path, impl_path):
    golden = read_binary(golden_path)
    if len(golden) != GOLDEN_SIZE or digest(golden) != GOLDEN_SHA256:
        raise ValueError("seed-147 golden .bit size/SHA-256 mismatch")
    impl = read_binary(impl_path, 20 * 1024 * 1024)
    if digest(impl) != IMPLEMENTATION_SHA256:
        raise ValueError("seed-147 nextpnr .txt SHA-256 mismatch")
    if not golden.startswith(GATEMATE_PREAMBLE):
        raise ValueError("golden preamble mismatch")

    default = read_binary(run_dir / "default.bit")
    if default != golden:
        raise ValueError("offline default.bit differs from verified seed-147 golden")
    report_file = run_dir / "variants.json"
    if not report_file.is_file() or report_file.stat().st_size > 65536:
        raise ValueError("missing or oversized variants.json")
    report = json.loads(report_file.read_text(encoding="utf-8"))
    if not isinstance(report, dict) or not isinstance(report.get("golden"), dict):
        raise ValueError("invalid variants.json structure")
    if (report["golden"].get("sha256") != GOLDEN_SHA256 or
            report["golden"].get("size") != GOLDEN_SIZE or
            report.get("implementation", {}).get("sha256") != IMPLEMENTATION_SHA256):
        raise ValueError("variants.json reference identities mismatch")
    listed = report.get("variants")
    if not isinstance(listed, dict) or set(listed) != set(VARIANTS):
        raise ValueError("variants.json must list exactly the three expected variants")

    images = {"default": default}
    for name in VARIANTS:
        candidate = read_binary(run_dir / (name + ".bit"))
        meta = listed[name]
        if (not isinstance(meta, dict) or meta.get("size") != len(candidate) or
                meta.get("sha256") != digest(candidate)):
            raise ValueError("variants.json size/SHA-256 mismatch for " + name)
        if len(candidate) != SIZES[name]:
            raise ValueError("unexpected variant size: " + name)
        if not candidate.startswith(GATEMATE_PREAMBLE):
            raise ValueError("variant preamble mismatch: " + name)
        if candidate == golden:
            raise ValueError("variant has no change: " + name)
        if common_prefix(golden, candidate) < GOLDEN_SIZE - TAIL_BOUND:
            raise ValueError("variant changed outside the last 256 golden bytes: " + name)
        images[name] = candidate

    comparisons = {
        "default_to_reconfig": pair(default, images["reconfig"]),
        "default_to_bootaddr": pair(default, images["bootaddr_probe"]),
        "reconfig_to_combined": pair(images["reconfig"], images["reconfig_bootaddr_probe"]),
        "bootaddr_to_combined": pair(images["bootaddr_probe"], images["reconfig_bootaddr_probe"]),
    }
    # Same-length comparisons provide exact offsets; unequal sizes cannot be
    # interpreted as byte substitutions without a verified stream grammar.
    first = min(value["same_prefix_bytes"] for value in comparisons.values())
    window_start = (max(0, first - 16) // 16) * 16
    if window_start < GOLDEN_SIZE - TAIL_BOUND - 16:
        raise ValueError("unexpected broad delta in pairwise comparison")
    return {
        "purpose": "READ-ONLY BYTE FORENSICS; NOT CONFIGURATION AUTHORIZATION",
        "golden_sha256": GOLDEN_SHA256,
        "implementation_sha256": IMPLEMENTATION_SHA256,
        "images": {name: {"size": len(data), "sha256": digest(data),
                          "hex_window_start": window_start,
                          "hex_lines": hexdump(data, window_start)}
                   for name, data in images.items()},
        "comparisons": comparisons,
        "interpretation_limit": "File offsets only. No command grammar, CRC, supported full handoff, or recovery inferred.",
    }


def render(report):
    lines = ["[PASS] Seed-147 .bit/.txt hashes, offline default and variants.json verified",
             "[PASS] Only final 256 golden bytes differ in the measured variants"]
    for name, info in report["images"].items():
        lines.append("[INFO] %-24s %7d bytes SHA-256 %s" %
                     (name, info["size"], info["sha256"]))
    for name, result in report["comparisons"].items():
        lines.append("[PAIR] %-25s prefix=0x%x suffix=%d bytes, lengths=%d/%d" %
                     (name, result["same_prefix_bytes"], result["same_suffix_bytes"],
                      result["a_size"], result["b_size"]))
        if "same_offset_byte_changes" in result:
            changes = result["same_offset_byte_changes"]
            if changes:
                lines.extend("       0x%x: %02x -> %02x" % tuple(item) for item in changes)
            else:
                lines.append("       same file bytes: flag has no additional measured effect")
    for name, info in report["images"].items():
        lines.append("[HEX] %s (absolute file offsets)" % name)
        lines.extend(info["hex_lines"])
    lines.append("[NOTE] No GateMate command/CRC semantics, live handoff, or recovery proved")
    lines.append("[NOTE] NEVER program these variant bitstreams to FPGA or flash")
    return "\n".join(lines) + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--offline-dir", type=Path, required=True,
                        help="existing /tmp/ulx5m-gmpack-offline.* run directory")
    parser.add_argument("--golden-bit", type=Path, help="override standard repository seed-147 .bit path")
    parser.add_argument("--implementation", type=Path, help="override standard seed-147 nextpnr .txt path")
    parser.add_argument("--json-out", type=Path, help="optional CREATE-ONLY JSON report")
    args = parser.parse_args(argv)
    root = Path(__file__).resolve().parents[2]
    base = (root / "bootloader-serv/build-ulx5m-gs/"
            "top_ulx5m_gs_flash_read-serv-dfu-hw-quad-btn2")
    try:
        result = validate(args.offline_dir,
                          args.golden_bit or Path(str(base) + ".bit"),
                          args.implementation or Path(str(base) + ".txt"))
        if args.json_out:
            # Exclusive create; existing reports and input files cannot be overwritten.
            with args.json_out.open("x", encoding="utf-8", newline="\n") as stream:
                json.dump(result, stream, indent=2, sort_keys=True)
                stream.write("\n")
        sys.stdout.write(render(result))
        return 0
    except (OSError, ValueError, TypeError, KeyError, json.JSONDecodeError) as error:
        print("[REJECT] %s" % error, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
