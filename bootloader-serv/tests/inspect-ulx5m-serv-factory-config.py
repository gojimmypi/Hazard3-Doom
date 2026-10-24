#!/usr/bin/env python3
"""Offline GateMate configuration evidence from a verified factory flash backup.

This tool is not a bitstream parser, flash layout specification, or programmer.
It does not authorize any flash writes.
"""

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

FLASH_BYTES = 4 * 1024 * 1024
SECTOR_BYTES = 4096
GATEMATE_SYNC = bytes.fromhex("d9 01 ed 96")
GATEMATE_PREAMBLE_BYTES = 16
# An observed trailer in two sample GateMate bitstreams, not a proven EOF token.
OBSERVED_TRAILER = bytes.fromhex("33 00 00 00 00")


def load_verified_backup(source):
    """Reuse the existing full backup and metadata verification unchanged."""
    here = Path(__file__).resolve().parent
    module_file = here / "analyze-ulx5m-serv-flash-backup.py"
    spec = importlib.util.spec_from_file_location("ulx5m_flash_analysis", module_file)
    if spec is None or spec.loader is None:
        raise ValueError("Cannot load existing backup verification module")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.analyze(source)  # validates both reads, report, JEDEC and sector map
    files = module.read_backup(source)
    return files["flash-pass1.bin"]


def occurrences(data, marker):
    result = []
    pos = data.find(marker)
    while pos >= 0:
        result.append(pos)
        pos = data.find(marker, pos + 1)
    return result


def inspect(image, reference=None):
    """Collect only directly observable facts; never infer a writable slot."""
    if len(image) != FLASH_BYTES:
        raise ValueError("Expected a complete 4 MiB factory flash image")
    if not image.startswith(GATEMATE_SYNC):
        raise ValueError("No GateMate signature at flash address zero")
    tail = len(image.rstrip(b"\xff"))
    if tail == 0:
        raise ValueError("Factory image is entirely erased")
    fully_erased_from = ((tail + SECTOR_BYTES - 1) // SECTOR_BYTES) * SECTOR_BYTES
    headers = occurrences(image, GATEMATE_SYNC)
    evidence = {
        "format": "ULX5M-GS factory configuration observations v1",
        "flash_sha256": hashlib.sha256(image).hexdigest(),
        "flash_bytes": FLASH_BYTES,
        "factory_preamble_hex": image[:GATEMATE_PREAMBLE_BYTES].hex(),
        "sync_signature_offsets": headers,
        "last_non_ff_offset": tail - 1,
        "observed_non_ff_prefix_bytes": tail,
        "first_all_ff_sector_start": fully_erased_from,
        "observed_trailer_offsets": occurrences(image[:tail], OBSERVED_TRAILER),
        "candidate_bitstream_end_verified": False,
        "secondary_configuration_absence_verified": False,
        "write_authorized": False,
    }
    if reference is not None:
        if len(reference) < GATEMATE_PREAMBLE_BYTES:
            raise ValueError("Reference bitstream is shorter than GateMate preamble")
        evidence["reference"] = {
            "bytes": len(reference),
            "sha256": hashlib.sha256(reference).hexdigest(),
            "sync_at_zero": reference.startswith(GATEMATE_SYNC),
            "same_16_byte_preamble": (
                reference[:GATEMATE_PREAMBLE_BYTES] ==
                image[:GATEMATE_PREAMBLE_BYTES]
            ),
            "identical_prefix_bytes": next(
                (i for i, (a, b) in enumerate(zip(image, reference)) if a != b),
                min(len(image), len(reference)),
            ),
            "observed_trailer_offsets": occurrences(reference, OBSERVED_TRAILER),
        }
    return evidence


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True,
                        help="Verified flash backup directory or ZIP")
    parser.add_argument("--reference-bit", type=Path,
                        help="Optional known GateMate .bit file for format comparison")
    parser.add_argument("--json-out", type=Path,
                        help="Optional new JSON file (never overwrite)")
    args = parser.parse_args(argv)
    try:
        image = load_verified_backup(args.input)
        reference = args.reference_bit.read_bytes() if args.reference_bit else None
        result = inspect(image, reference)
        print("[PASS] Verified 4 MiB factory backup; SHA-256 " + result["flash_sha256"])
        print("[SIGNATURE] GateMate sync candidates: " +
              ", ".join("0x%06X" % offset for offset in result["sync_signature_offsets"]))
        print("[LAST NON-FF] 0x%06X (observed only)" % result["last_non_ff_offset"])
        print("[FIRST ALL-FF SECTOR] 0x%06X" % result["first_all_ff_sector_start"])
        print("[TRAILER] 5-byte pattern: %d occurrences; last at 0x%06X" % (
              len(result["observed_trailer_offsets"]),
              result["observed_trailer_offsets"][-1]
              if result["observed_trailer_offsets"] else 0))
        if reference is not None:
            ref = result["reference"]
            print("[REFERENCE] size=%d preamble_match=%s common_prefix=%d bytes" % (
                ref["bytes"], ref["same_16_byte_preamble"],
                ref["identical_prefix_bytes"]))
        print("[POLICY] Image end and secondary boot boundaries unverified; all flash protected")
        if args.json_out:
            with args.json_out.open("x", encoding="utf-8", newline="\n") as output:
                json.dump(result, output, indent=2)
                output.write("\n")
            print("[REPORT] " + str(args.json_out))
    except (ValueError, OSError, KeyError, ImportError, RuntimeError) as exc:
        print("[FAIL] " + str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
