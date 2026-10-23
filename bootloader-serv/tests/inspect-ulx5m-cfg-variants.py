#!/usr/bin/env python3
"""Read-only byte comparison for gmpack variants of one frozen implementation.

This is intentionally NOT a GateMate configuration-stream parser or validator.
Do not use its output to authorize a live reconfiguration or a flash write.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys

GOLDEN_SHA256 = "8232dd932ff2ea40b2945de6ed1202be5e7dc75960464419cc0ffa95a75901f8"
IMPLEMENTATION_SHA256 = "3b1cca322420f5086a6f0695cc299660047a68740908a3f50f060ff6877c65b9"
FACTORY_SHA256 = "74b3accfa91b04efee753a72b6b9787eb20bfb217266198fefb349ca1cb9509d"
GATEMATE_PREFIX = bytes.fromhex("d9 01 ed 96")
FLASH_SIZE = 4 * 1024 * 1024
FLASH_SECTOR = 4096
CANDIDATE_OFFSET = 0x200000
MAX_VARIANT_SIZE = FLASH_SIZE


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def read_binary(path, size_limit=None):
    path = Path(path)
    if not path.is_file():
        raise ValueError("not a regular file: %s" % path)
    if size_limit is not None and path.stat().st_size > size_limit:
        raise ValueError("file exceeds size limit: %s" % path)
    return path.read_bytes()


def check_bit(path):
    data = read_binary(path, MAX_VARIANT_SIZE)
    if len(data) < 64 or not data.startswith(GATEMATE_PREFIX):
        raise ValueError("not a recognized GateMate preamble (NOT a complete format check): %s" % path)
    return data


def differences(a, b, max_ranges=16):
    """Compute exact byte differences; missing bytes count as different."""
    overlap = min(len(a), len(b))
    first = None
    last = None
    total = abs(len(a) - len(b))
    ranges = []
    current_start = None
    for i in range(overlap):
        if a[i] != b[i]:
            total += 1
            first = i if first is None else first
            last = i
            if current_start is None:
                current_start = i
        elif current_start is not None:
            if len(ranges) < max_ranges:
                ranges.append([current_start, i])
            current_start = None
    if len(a) != len(b):
        first = overlap if first is None else first
        last = max(len(a), len(b)) - 1
        if current_start is None:
            current_start = overlap
    if current_start is not None and len(ranges) < max_ranges:
        ranges.append([current_start, max(len(a), len(b))])
    prefix_len = 0
    while prefix_len < overlap and a[prefix_len] == b[prefix_len]:
        prefix_len += 1
    suffix_len = 0
    while (suffix_len < overlap - prefix_len and
           a[len(a) - 1 - suffix_len] == b[len(b) - 1 - suffix_len]):
        suffix_len += 1
    return {
        "different_bytes_including_size_delta": total,
        "first_different_offset": first,
        "last_different_offset": last,
        "identical_prefix_bytes": prefix_len,
        "identical_suffix_bytes": suffix_len,
        "first_difference_ranges_end_exclusive": ranges,
        "ranges_truncated": len(ranges) == max_ranges,
    }


def validate_factory(path):
    data = read_binary(path, FLASH_SIZE)
    if len(data) != FLASH_SIZE:
        raise ValueError("factory backup must be exactly 4 MiB")
    digest = sha256(data)
    if digest != FACTORY_SHA256:
        raise ValueError("factory SHA-256 mismatch: " + digest)
    last_non_ff = next((i for i in range(len(data) - 1, -1, -1) if data[i] != 0xff), None)
    first_erased = next((i for i in range(0, FLASH_SIZE, FLASH_SECTOR)
                         if data[i:i + FLASH_SECTOR] == b"\xff" * FLASH_SECTOR), None)
    return {
        "sha256": digest, "size": len(data),
        "preamble_matches": data.startswith(GATEMATE_PREFIX),
        "candidate_u5im_magic_present": data[CANDIDATE_OFFSET:CANDIDATE_OFFSET + 4] == b"U5IM",
        "last_non_ff_offset": last_non_ff,
        "first_fully_erased_sector": first_erased,
        "interpretation": "flash observations only; no writable region or valid boot boundary inferred",
    }


def parse_variant(value):
    if "=" not in value:
        raise argparse.ArgumentTypeError("use NAME=FILE")
    name, path = value.split("=", 1)
    if not re.fullmatch(r"[a-z][a-z0-9_-]*", name) or not path:
        raise argparse.ArgumentTypeError("NAME must contain ASCII lowercase letters, digits, _ or -")
    return name, path


def run(args):
    golden = check_bit(args.golden_bit)
    digest = sha256(golden)
    if digest != GOLDEN_SHA256:
        raise ValueError("golden bitstream SHA-256 mismatch: " + digest)
    impl = read_binary(args.implementation)
    impl_digest = sha256(impl)
    if impl_digest != IMPLEMENTATION_SHA256:
        raise ValueError("implementation text SHA-256 mismatch: " + impl_digest)

    report = {
        "purpose": "OFFLINE BYTE FORENSICS ONLY; NO RECONFIGURATION AUTHORIZED",
        "golden": {"size": len(golden), "sha256": digest,
                   "prefix_hex": golden[:16].hex()},
        "implementation": {"size": len(impl), "sha256": impl_digest},
        "variants": {},
        "requirements_not_proven": [
            "whether CC_CFG_CTRL can perform complete application replacement",
            "CRC/command correctness or semantic meaning of modified bytes",
            "SPI ownership and device configuration pin straps",
            "midstream reconfiguration recovery and persistent rollback",
            "U5IM authenticity, compatibility and boot authorization",
        ],
    }
    if not args.variant:
        report["note"] = "Golden inputs checked only; provide --variant NAME=FILE to compare gmpack outputs"
    for name, path in args.variant:
        if name in report["variants"]:
            raise ValueError("duplicate variant name: " + name)
        candidate = check_bit(path)
        cdigest = sha256(candidate)
        diff = differences(golden, candidate)
        report["variants"][name] = {
            "size": len(candidate), "sha256": cdigest,
            "same_as_golden": candidate == golden,
            "preamble_matches_golden": candidate[:4] == golden[:4],
            "comparison": diff,
            "note": "bytes compared, configuration commands NOT decoded",
        }
        if candidate == golden:
            raise ValueError("variant %s identical to golden; flag effect not demonstrated" % name)
    if args.factory_flash:
        report["factory_backup"] = validate_factory(args.factory_flash)

    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--golden-bit", required=True,
                        help="existing untouched seed-147 .bit; exact SHA-256 enforced")
    parser.add_argument("--implementation", required=True,
                        help="seed-147 nextpnr .txt input to gmpack; exact SHA-256 enforced")
    parser.add_argument("--variant", type=parse_variant, action="append", default=[],
                        metavar="NAME=FILE", help="gmpack variant of the SAME .txt; repeatable")
    parser.add_argument("--factory-flash", help="optional original 4 MiB backup; exact SHA-256 enforced")
    parser.add_argument("--json-out", help="optional new report; existing destination is never replaced")
    args = parser.parse_args(argv)
    try:
        report = run(args)
        payload = json.dumps(report, indent=2, sort_keys=True) + "\n"
        if args.json_out:
            with open(args.json_out, "x", encoding="utf-8", newline="\n") as out:
                out.write(payload)
        sys.stdout.write(payload)
        return 0
    except (OSError, ValueError) as exc:
        print("[REJECT] " + str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
