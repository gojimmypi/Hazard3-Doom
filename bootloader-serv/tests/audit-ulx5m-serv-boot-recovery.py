#!/usr/bin/env python3
"""Read-only ULX5M-GS boot provenance audit; NEVER authorizes configuration."""

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

FLASH_BYTES = 4 * 1024 * 1024
FACTORY_SHA256 = "74b3accfa91b04efee753a72b6b9787eb20bfb217266198fefb349ca1cb9509d"
SEED147_SHA256 = "8232dd932ff2ea40b2945de6ed1202be5e7dc75960464419cc0ffa95a75901f8"
SEED147_BYTES = 414867
CANDIDATE_ADDR = 0x200000  # Probe location only; not an assigned partition.


class AuditError(ValueError):
    pass


def digest(data):
    return hashlib.sha256(data).hexdigest()


def checked_golden(path):
    try:
        image = Path(path).read_bytes()
    except OSError as exc:
        raise AuditError("Cannot read seed-147 reference: " + str(exc)) from exc
    if len(image) != SEED147_BYTES or digest(image) != SEED147_SHA256:
        raise AuditError("Seed-147 byte count or frozen SHA-256 differs")
    return image


def load_existing_backup_checker():
    path = Path(__file__).with_name("analyze-ulx5m-serv-flash-backup.py")
    if not path.is_file():
        raise AuditError("Required existing backup checker is missing: " + str(path))
    spec = importlib.util.spec_from_file_location("ulx5m_existing_backup_checker", path)
    if spec is None or spec.loader is None:
        raise AuditError("Cannot load existing backup checker")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def checked_factory(source):
    checker = load_existing_backup_checker()
    try:
        result = checker.analyze(source)
        files = checker.read_backup(source)
        data = files["flash-pass1.bin"]
    except (OSError, ValueError, KeyError) as exc:
        raise AuditError("Factory backup verification failed: " + str(exc)) from exc
    if (result.get("both_reads_verified") is not True
            or len(data) != FLASH_BYTES
            or digest(data) != FACTORY_SHA256):
        raise AuditError("Factory backup differs from frozen two-pass SHA-256")
    return data


def assess(factory, golden):
    """Classify observed bytes without inferring configuration or recovery."""
    if len(factory) != FLASH_BYTES or len(golden) == 0 or len(golden) > len(factory):
        raise AuditError("Invalid flash or golden image length")
    exact_origin = factory[:len(golden)] == golden
    first_delta = next((i for i, (a, b) in enumerate(zip(factory, golden)) if a != b), None)
    erased_sector = factory[CANDIDATE_ADDR:CANDIDATE_ADDR + 4096] == b"\xff" * 4096
    return {
        "format": "ULX5M-GS offline boot-provenance-v1",
        "factory_image_sha256": digest(factory),
        "reference_seed147_sha256": digest(golden),
        "flash_bytes": len(factory),
        "flash_origin_exact_seed147_bytes": exact_origin,
        "flash_origin_first_seed147_difference": first_delta,
        "candidate_probe_offset": CANDIDATE_ADDR,
        "candidate_probe_has_u5im_magic": factory[CANDIDATE_ADDR:CANDIDATE_ADDR + 4] == b"U5IM",
        "candidate_probe_first_sector_all_ff": erased_sector,
        "physical_boot_straps_verified": False,
        "global_reset_recovery_verified": False,
        "independent_jtag_recovery_verified": False,
        "persistent_dfu_recovery_verified": False,
        "configuration_handoff_authorized": False,
        "flash_write_authorized": False,
        "bootaddr_0x200000_authorized": False,
        "note": ("An exact prefix is byte-level evidence only. It does not prove SPI "
                 "boot, actual device configuration, independent recovery, "
                 "authorization, or writable flash regions."),
    }


def audit(backup, golden):
    # Check the reference first; never turn an unverified input into a report.
    image = checked_golden(golden)
    factory = checked_factory(backup)
    return assess(factory, image)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--backup", required=True, type=Path,
                        help="Existing two-pass backup directory or ZIP, with report")
    parser.add_argument("--golden-bit", required=True, type=Path,
                        help="Frozen seed-147 .bit (verified SHA-256)")
    parser.add_argument("--json-out", type=Path,
                        help="Optional new report path; exclusive create")
    args = parser.parse_args(argv)
    try:
        result = audit(args.backup, args.golden_bit)
        print("[PASS] Frozen factory dual backup and seed-147 reference verified")
        if result["flash_origin_exact_seed147_bytes"]:
            print("[BYTES] SPI flash origin has exact seed-147 prefix (boot NOT proven)")
        else:
            delta = result["flash_origin_first_seed147_difference"]
            print("[BYTES] SPI flash origin is NOT the seed-147 .bit; first difference 0x%X" % delta)
        print("[PROBE] U5IM magic at 0x200000: %s (not boot authorization)" %
              ("present" if result["candidate_probe_has_u5im_magic"] else "absent"))
        print("[BLOCK] Persistent DFU recovery, handoff, and flash writes remain unapproved")
        if args.json_out is not None:
            try:
                with args.json_out.open("x", encoding="utf-8", newline="\n") as output:
                    json.dump(result, output, indent=2, sort_keys=True)
                    output.write("\n")
            except FileExistsError as exc:
                raise AuditError("Refusing to overwrite existing report") from exc
            print("[REPORT] " + str(args.json_out))
    except (AuditError, OSError) as exc:
        print("[FAIL] " + str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
