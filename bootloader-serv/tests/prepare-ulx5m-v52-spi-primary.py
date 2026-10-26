#!/usr/bin/env python3
"""Prepare exact SPI-primary and factory-restore regions; NEVER accesses hardware.

Outputs two 458752-byte binaries and an evidence manifest in a new directory.
Flash zero must NOT be programmed until independent JTAG flash-write/restore
and the board's physical configuration strap/recovery method are qualified.
"""
import argparse
import hashlib
import json
from pathlib import Path

FLASH_BYTES = 0x400000
ERASE_BYTES = 0x1000
PRIMARY_BYTES = 406566
PRIMARY_SHA = "85bd3a962bf061a936418aa02020efe06df042bde98b77098d73b748b89fb70a"
FACTORY_SHA = "74b3accfa91b04efee753a72b6b9787eb20bfb217266198fefb349ca1cb9509d"
SECTOR_SHA = "28b1e5cbfa45a319600ec38c81207a36d9889c3179e8055f5a663c616ef97bee"
SECONDARY = 0x201000
MAGIC = bytes.fromhex("d901ed96")
# Keep the complete last 64 KiB erase block in the write and restore assets.
# Minimum 4 KiB-sector footprint is 0x64000; JTAG programmer erase choice
# may be coarser, so we preserve 0x64000..0x6ffff from the factory backup.
MIN_PRIMARY_ERASE_BYTES = (PRIMARY_BYTES + ERASE_BYTES - 1) // ERASE_BYTES * ERASE_BYTES
PRIMARY_REGION_BYTES = (PRIMARY_BYTES + 0xFFFF) // 0x10000 * 0x10000


def digest(data):
    return hashlib.sha256(data).hexdigest()


def check(name, data, size, sha):
    if len(data) != size or digest(data) != sha:
        raise ValueError("%s: size/SHA-256 mismatch" % name)
    return data


def build(primary, backup_a, backup_b, sector):
    primary = check("primary seed7", primary, PRIMARY_BYTES, PRIMARY_SHA)
    backup_a = check("factory pass1", backup_a, FLASH_BYTES, FACTORY_SHA)
    backup_b = check("factory pass2", backup_b, FLASH_BYTES, FACTORY_SHA)
    sector = check("independent secondary", sector, ERASE_BYTES, SECTOR_SHA)
    if backup_a != backup_b:
        raise ValueError("Factory backup passes disagree")
    if not primary.startswith(MAGIC) or not backup_a.startswith(MAGIC) or not sector.startswith(MAGIC):
        raise ValueError("Missing GateMate configuration magic")
    if PRIMARY_REGION_BYTES >= 0x200000 or SECONDARY + ERASE_BYTES > FLASH_BYTES:
        raise ValueError("Unsafe primary/secondary layout")
    factory_region = backup_a[:PRIMARY_REGION_BYTES]
    proposed_region = (primary + b"\xff" * (MIN_PRIMARY_ERASE_BYTES - len(primary)) +
                       backup_a[MIN_PRIMARY_ERASE_BYTES:PRIMARY_REGION_BYTES])
    # Keep the original non-primary flash bytes, except previously verified app.
    expected = bytearray(backup_a)
    expected[:PRIMARY_REGION_BYTES] = proposed_region
    expected[SECONDARY:SECONDARY + ERASE_BYTES] = sector
    if expected[PRIMARY_REGION_BYTES:SECONDARY] != backup_a[PRIMARY_REGION_BYTES:SECONDARY]:
        raise ValueError("Intermediate factory/metadata region changed")
    if expected[SECONDARY + ERASE_BYTES:] != backup_a[SECONDARY + ERASE_BYTES:]:
        raise ValueError("Post-secondary factory region changed")
    manifest = {
        "format": "ULX5M-GS-V52-LOCAL-SPI-PRIMARY-PREPARATION",
        "programming_authorized": False,
        "jtag_flash_writer_restoration_qualified": False,
        "secondary_takeover_verified": False,
        "primary_region_offset": "0x000000",
        "primary_region_length": PRIMARY_REGION_BYTES,
        "minimum_4k_erase_footprint": MIN_PRIMARY_ERASE_BYTES,
        "conservative_64k_block_coverage": PRIMARY_REGION_BYTES,
        "primary_region_sha256": digest(proposed_region),
        "factory_restore_region_sha256": digest(factory_region),
        "factory_full_sha256": FACTORY_SHA,
        "secondary_offset": "0x201000",
        "secondary_region_sha256": SECTOR_SHA,
        "expected_full_flash_sha256_after_controlled_install": digest(expected),
        "preserved_factory_bytes_within_write_region": "0x064000..0x06ffff",
        "protected_region": "0x070000..0x3fffff (except existing app at 0x201000)",
        "warning": "Prepared offline only. Never flash an entire 4MiB composite using this manifest."
    }
    return proposed_region, factory_region, manifest


def prepare(args):
    out = Path(args.output_dir)
    if out.exists():
        raise ValueError("Output directory exists; refusing overwrite")
    primary, factory, manifest = build(Path(args.primary).read_bytes(),
                                      Path(args.factory_pass1).read_bytes(),
                                      Path(args.factory_pass2).read_bytes(),
                                      Path(args.sector_dump).read_bytes())
    out.mkdir(parents=True, exist_ok=False)
    try:
        # Create-only; image files do NOT contain instructions or execute writes.
        with (out / "PROPOSED-primary-000000-06ffff.bin").open("xb") as f:
            f.write(primary)
        with (out / "RESTORE-factory-000000-06ffff.bin").open("xb") as f:
            f.write(factory)
        with (out / "preparation.json").open("x", encoding="ascii", newline="\n") as f:
            f.write(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    except Exception:
        # Keep partial files for forensic review; do not overwrite any prior files.
        raise
    return manifest


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--primary", required=True)
    ap.add_argument("--factory-pass1", required=True)
    ap.add_argument("--factory-pass2", required=True)
    ap.add_argument("--sector-dump", required=True)
    ap.add_argument("--output-dir", required=True)
    args = ap.parse_args()
    try:
        print(json.dumps(prepare(args), indent=2, sort_keys=True))
    except (OSError, ValueError) as exc:
        ap.exit(1, "[FAIL] %s\n" % exc)


if __name__ == "__main__":
    main()
