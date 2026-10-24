#!/usr/bin/env python3
"""Read-only ULX5M-GS SPI recovery gate: verified backup and staged image evidence.

This is not a programmer, bootloader, native-bitstream validator, or boot
permission checker. A valid U5IM CRC is insufficient to prove FPGA bootability.
"""
import argparse
import hashlib
import json
from pathlib import Path

FLASH_BYTES = 0x400000
ERASE_BYTES = 0x1000
METADATA_ADDRESS = 0x200000
NATIVE_ADDRESS = 0x201000
FACTORY_SHA256 = "74b3accfa91b04efee753a72b6b9787eb20bfb217266198fefb349ca1cb9509d"
APP_SHA256 = "68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd"
APP_BYTES = 3026
SYNC = bytes.fromhex("d901ed96")


def hash_bytes(data):
    return hashlib.sha256(data).hexdigest()


def verify_factory(path, expected_sha=FACTORY_SHA256):
    data = Path(path).read_bytes()
    if len(data) != FLASH_BYTES:
        raise ValueError("flash backup must contain exactly 4 MiB")
    digest = hash_bytes(data)
    if digest != expected_sha:
        raise ValueError("flash backup SHA-256 does not match pinned factory reference")
    return data


def verify_app(path):
    data = Path(path).read_bytes()
    if len(data) != APP_BYTES or hash_bytes(data) != APP_SHA256:
        raise ValueError("application is not the JTAG-verified 3026-byte fixture")
    if not data.startswith(SYNC):
        raise ValueError("application sync signature is missing")
    return data


def classify_region(flash, start, size):
    if start < 0 or size <= 0 or start > len(flash) or size > len(flash)-start:
        raise ValueError("region is outside supplied image")
    part = flash[start:start+size]
    used = sum(b != 0xff for b in part)
    return {"offset": "0x%06x" % start, "size": size,
            "non_erased_bytes": used, "erased": used == 0,
            "sha256": hash_bytes(part)}


def inspect_backup(flash):
    return {
        "stage0_factory_half": classify_region(flash, 0, METADATA_ADDRESS),
        "candidate_metadata_sector": classify_region(flash, METADATA_ADDRESS, ERASE_BYTES),
        "candidate_native_sector": classify_region(flash, NATIVE_ADDRESS, ERASE_BYTES),
    }


def report(app, factory=None, comparison=None):
    if factory is not None and comparison is not None and factory != comparison:
        raise ValueError("supplied independent flash snapshots differ")
    result = {
        "application": {"bytes": len(app), "sha256": hash_bytes(app),
                        "image_format": "known JTAG-working GateMate bitstream only"},
        "proposed_layout": {"metadata": "0x200000", "native_entry": "0x201000",
                            "erase_sector_bytes": ERASE_BYTES},
        "factory_snapshot_verified": factory is not None,
        "second_snapshot_matches_first": comparison is not None and factory is not None,
        "stage0_dfu_proven_persistent": False,
        "spi_boot_hardware_verified": False,
        "short_jump_accepted_by_cfg_ctrl": False,
        "corrupt_secondary_recovery_proven": False,
        "flash_writes_enabled": False,
        "persistent_boot_authorized": False,
        "result": "BLOCKED - no independently recoverable persistent DFU stage0",
    }
    if factory is not None:
        result["factory_sha256"] = hash_bytes(factory)
        result["flash_regions"] = inspect_backup(factory)
        result["candidate_sectors_empty_in_factory"] = (
            result["flash_regions"]["candidate_metadata_sector"]["erased"]
            and result["flash_regions"]["candidate_native_sector"]["erased"])
        result["current_flash_verified"] = False  # No USB/JTAG/live flash reads.
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, required=True,
                        help="known JTAG-working normal LED .bit")
    parser.add_argument("--factory-backup", type=Path,
                        help="optional pre-existing complete 4 MiB backup, read-only")
    parser.add_argument("--second-backup", type=Path,
                        help="optional independently captured 4 MiB backup, read-only")
    args = parser.parse_args(argv)
    if args.second_backup and not args.factory_backup:
        parser.error("--second-backup requires --factory-backup")
    if (args.second_backup and args.factory_backup and
            args.second_backup.resolve() == args.factory_backup.resolve()):
        parser.error("--second-backup must be a distinct file")
    try:
        app = verify_app(args.app)
        factory = verify_factory(args.factory_backup) if args.factory_backup else None
        comparison = verify_factory(args.second_backup) if args.second_backup else None
        result = report(app, factory, comparison)
    except (OSError, ValueError) as exc:
        parser.exit(1, "[FAIL] %s\n" % exc)
    print("[PASS] Exact JTAG-working native image SHA-256 and sync")
    if factory is not None:
        print("[PASS] Pinned original 4 MiB factory backup SHA-256")
        if comparison is not None:
            print("[PASS] Second supplied backup matches original byte-for-byte (capture independence unverified)")
        for name, item in result["flash_regions"].items():
            print("[OBSERVED] %s at %s: %d non-erased bytes" %
                  (name, item["offset"], item["non_erased_bytes"]))
        print("[LIMIT] Factory backup is historical; live flash was NOT inspected")
    else:
        print("[UNKNOWN] Factory flash backup not supplied; flash slot occupancy unverified")
    print("[LIMIT] U5IM CRC32 validation does NOT prove native GateMate bootability")
    print("[BLOCK] No persistent DFU stage0, BTN2 recovery, or SPI jump demonstrated")
    print("[BLOCK] No output images, hardware operations, USB, JTAG or flash writes")
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
