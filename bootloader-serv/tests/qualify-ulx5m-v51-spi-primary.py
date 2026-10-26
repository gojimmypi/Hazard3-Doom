#!/usr/bin/env python3
"""Read-only ULX5M-GS v50 seed-7 SPI-primary deployment preflight.

Pins the known local primary, 4 MiB factory recovery copies, and the exact
native secondary image at 0x201000. Computes (never writes) the flash-zero
sector erase footprint. No hardware access, flash-writing API, or programming
approval is implemented. A PASS of file evidence ALWAYS blocks deployment
until independent recovery is demonstrated on the actual board.
"""

import argparse
import hashlib
import json
from pathlib import Path
import sys

FLASH_BYTES = 4 * 1024 * 1024
SECTOR_BYTES = 4096
FLASH_ZERO = 0x000000
METADATA = 0x200000
SECONDARY = 0x201000
PRIMARY_SIZE = 406566
APP_SIZE = 3026
PRIMARY_SHA256 = "85bd3a962bf061a936418aa02020efe06df042bde98b77098d73b748b89fb70a"
FACTORY_SHA256 = "74b3accfa91b04efee753a72b6b9787eb20bfb217266198fefb349ca1cb9509d"
APP_SHA256 = "68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd"
SECTOR_SHA256 = "28b1e5cbfa45a319600ec38c81207a36d9889c3179e8055f5a663c616ef97bee"
TRAILER = bytes.fromhex("c3010cfe00ccc6da0428eb0010200029510000")
MAGIC = bytes.fromhex("d901ed96")


def sha(data):
    return hashlib.sha256(data).hexdigest()


def checked_file(label, path, expected_size, expected_sha, problems):
    try:
        data = Path(path).read_bytes()
    except OSError as exc:
        problems.append("%s: %s" % (label, exc))
        return None
    if len(data) != expected_size:
        problems.append("%s: size %d, expected %d" %
                        (label, len(data), expected_size))
    if sha(data) != expected_sha:
        problems.append("%s: SHA256 mismatch: %s" % (label, sha(data)))
    return data


def evaluate(primary_file, factory_a_file, factory_b_file,
             app_file, sector_file, snapshot_file=None):
    """Return a standalone, byte-precise preflight report; never authorize writes."""
    problems = []
    primary = checked_file("primary", primary_file, PRIMARY_SIZE, PRIMARY_SHA256, problems)
    backup_a = checked_file("factory_pass1", factory_a_file, FLASH_BYTES,
                            FACTORY_SHA256, problems)
    backup_b = checked_file("factory_pass2", factory_b_file, FLASH_BYTES,
                            FACTORY_SHA256, problems)
    app = checked_file("secondary_app", app_file, APP_SIZE, APP_SHA256, problems)
    sector = checked_file("independent_sector", sector_file, SECTOR_BYTES,
                          SECTOR_SHA256, problems)
    sectors = None
    erase_end = None
    if primary is not None:
        if not primary.startswith(MAGIC):
            problems.append("primary: missing GateMate magic")
        if not primary.endswith(TRAILER):
            problems.append("primary: exact --bootaddr 0x201000 trailer mismatch")
        sectors = (len(primary) + SECTOR_BYTES - 1) // SECTOR_BYTES
        erase_end = sectors * SECTOR_BYTES
        if erase_end > METADATA or erase_end > SECONDARY:
            problems.append("primary: erase footprint overlaps protected metadata or application")
        if len(primary) == 0:
            problems.append("primary: empty image")
    if backup_a is not None and backup_b is not None:
        if backup_a != backup_b:
            problems.append("factory: two backups differ byte-for-byte")
        if not backup_a.startswith(MAGIC):
            problems.append("factory: flash-zero GateMate magic missing")
    if app is not None and sector is not None:
        if sector[:len(app)] != app:
            problems.append("independent_sector: payload differs from secondary app")
        if sector[len(app):] != b"\xff" * (SECTOR_BYTES - len(app)):
            problems.append("independent_sector: erased tail changed")
    current = None
    if snapshot_file is not None:
        try:
            current = Path(snapshot_file).read_bytes()
        except OSError as exc:
            problems.append("current_snapshot: %s" % exc)
        if current is not None and len(current) != FLASH_BYTES:
            problems.append("current_snapshot: expected exactly 4 MiB")
        if current is not None and len(current) == FLASH_BYTES and backup_a is not None:
            if current[:SECONDARY] != backup_a[:SECONDARY]:
                problems.append("current_snapshot: flash zero/metadata/other pre-app bytes changed")
            if current[SECONDARY + SECTOR_BYTES:] != backup_a[SECONDARY + SECTOR_BYTES:]:
                problems.append("current_snapshot: bytes beyond app sector changed")
            if sector is not None and current[SECONDARY:SECONDARY + SECTOR_BYTES] != sector:
                problems.append("current_snapshot: secondary sector does not match independent readback")
    report = {
        "result": ("PINNED_FILE_EVIDENCE_PASS_DEPLOYMENT_BLOCKED" if not problems
                   else "FILE_EVIDENCE_FAIL_DEPLOYMENT_BLOCKED"),
        "errors": problems,
        "primary": {
            "expected_size": PRIMARY_SIZE, "sha256": PRIMARY_SHA256,
            "sector_count": sectors, "erase_start": "0x000000",
            "erase_end_exclusive": ("0x%06X" % erase_end if erase_end is not None else None),
            "factory_bytes_at_risk": erase_end,
            "can_recover_flash_zero_by_BTN2_alone": False,
        },
        "factory": {"bytes": FLASH_BYTES, "sha256": FACTORY_SHA256,
                    "double_backup_required": True},
        "secondary": {"address": "0x201000", "bytes": APP_SIZE,
                      "sector_sha256": SECTOR_SHA256, "metadata_address": "0x200000"},
        "current_snapshot": ("NOT_SUPPLIED" if snapshot_file is None else
                             ("CHECKED" if current is not None else "INVALID")),
        "recovery_gates": {
            "independent_JTAG_SRAM_override_verified_against_SPI_active_mode": False,
            "flash_zero_JTAG_SPI_writer_restoration_qualified": False,
            "v005_DIP_positions_verified_on_physical_board": False,
            "secondary_takeover_from_SPI_active_flash": False,
            "authorize_flash_erase_or_write": False,
        },
        "note": "A passing report confirms pinned input bytes only, not flash programming, recoverability or SPI takeover."
    }
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--primary", required=True)
    parser.add_argument("--factory-pass1", required=True)
    parser.add_argument("--factory-pass2", required=True)
    parser.add_argument("--app-bit", required=True)
    parser.add_argument("--sector-dump", required=True)
    parser.add_argument("--current-snapshot", help="optional PRE-DEPLOY 4 MiB readback")
    parser.add_argument("--report", help="create a new JSON report; refuses overwrite")
    args = parser.parse_args()
    report = evaluate(args.primary, args.factory_pass1, args.factory_pass2,
                      args.app_bit, args.sector_dump, args.current_snapshot)
    rendered = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.report is not None:
        try:
            with open(args.report, "x", encoding="ascii", newline="\n") as fh:
                fh.write(rendered)
        except OSError as exc:
            print("[FAIL] report: %s" % exc, file=sys.stderr)
            return 2
    print(rendered, end="")
    return 0 if not report["errors"] else 1


if __name__ == "__main__":
    sys.exit(main())
