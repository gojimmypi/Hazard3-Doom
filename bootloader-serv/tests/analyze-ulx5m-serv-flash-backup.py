#!/usr/bin/env python3
"""Offline, read-only sector map for a verified ULX5M-GS SERV flash backup."""

import argparse
import hashlib
import json
from pathlib import Path
import sys
import zipfile

FLASH_BYTES = 4 * 1024 * 1024
SECTOR_BYTES = 4096
EXPECTED_JEDEC = "1f4216"
BACKUP_FILES = ("flash-backup-report.json", "flash-pass1.bin", "flash-pass2.bin")


class BackupError(ValueError):
    """The backup is incomplete, inconsistent, or fails verification."""


def read_backup(source):
    """Read three fixed filenames from either a directory or a ZIP archive."""
    source = Path(source)
    if source.is_dir():
        return {name: (source / name).read_bytes() for name in BACKUP_FILES}
    if not source.is_file() or source.suffix.lower() != ".zip":
        raise BackupError("Input must be a backup directory or ZIP file")
    with zipfile.ZipFile(source) as archive:
        members = [name for name in archive.namelist() if not name.endswith("/")]
        choices = [name for name in members if name.split("/")[-1] == BACKUP_FILES[0]]
        if len(choices) != 1:
            raise BackupError("ZIP must contain one flash-backup-report.json")
        prefix = choices[0][:-len(BACKUP_FILES[0])]
        if prefix.startswith("/") or ".." in prefix.split("/"):
            raise BackupError("Invalid backup ZIP path")
        if any(m.split("/")[-1] in BACKUP_FILES and not m.startswith(prefix)
               for m in members):
            raise BackupError("Multiple backup directories in ZIP")
        if any(members.count(prefix + name) != 1 for name in BACKUP_FILES):
            raise BackupError("Missing or duplicate backup file in ZIP")
        return {name: archive.read(prefix + name) for name in BACKUP_FILES}


def checked_report(files):
    try:
        report = json.loads(files[BACKUP_FILES[0]].decode("utf-8"))
    except (UnicodeError, ValueError) as exc:
        raise BackupError("Backup report is not valid UTF-8 JSON") from exc
    if not isinstance(report, dict):
        raise BackupError("Backup report must contain a JSON object")
    if report.get("format") != "ULX5M-GS SERV flash-backup-v1":
        raise BackupError("Unexpected backup report format")
    jedec = report.get("device_jedec_hex")
    if not isinstance(jedec, str) or jedec.lower() != EXPECTED_JEDEC:
        raise BackupError("Unexpected JEDEC ID in backup report")
    if report.get("size_bytes") != FLASH_BYTES:
        raise BackupError("Unexpected flash capacity")
    if report.get("byte_for_byte_match") is not True:
        raise BackupError("Backup report did not certify matching reads")
    passes = report.get("passes")
    if not isinstance(passes, list) or len(passes) != 2:
        raise BackupError("Backup report must contain two passes")
    for pass_number, name in enumerate(BACKUP_FILES[1:]):
        content = files[name]
        if len(content) != FLASH_BYTES:
            raise BackupError("Unexpected length for " + name)
        entry = passes[pass_number]
        if not isinstance(entry, dict) or entry.get("file") != name:
            raise BackupError("Pass order or filename mismatch")
        digest = hashlib.sha256(content).hexdigest()
        if entry.get("sha256") != digest:
            raise BackupError("SHA-256 mismatch for " + name)
    if files[BACKUP_FILES[1]] != files[BACKUP_FILES[2]]:
        raise BackupError("Physical backup passes differ byte-for-byte")
    return report


def sector_map(data):
    if len(data) != FLASH_BYTES:
        raise BackupError("Flash image must contain exactly 4 MiB")
    states = []
    first = None
    last = None
    for offset in range(0, FLASH_BYTES, SECTOR_BYTES):
        sector = data[offset:offset + SECTOR_BYTES]
        if sector == b"\xff" * SECTOR_BYTES:
            state = "all-ff"
        elif sector == b"\x00" * SECTOR_BYTES:
            state = "all-00"
        else:
            state = "mixed"
        states.append(state)
        if state != "all-ff":
            lo = next(i for i, v in enumerate(sector) if v != 0xff)
            hi = SECTOR_BYTES - 1 - next(i for i, v in enumerate(reversed(sector))
                                         if v != 0xff)
            if first is None:
                first = offset + lo
            last = offset + hi
    runs = []
    for index, state in enumerate(states):
        if runs and runs[-1]["class"] == state:
            runs[-1]["sector_count"] += 1
            runs[-1]["end_exclusive"] += SECTOR_BYTES
        else:
            runs.append({"class": state, "first_sector": index,
                         "sector_count": 1, "start": index * SECTOR_BYTES,
                         "end_exclusive": (index + 1) * SECTOR_BYTES})
    counts = {kind: states.count(kind) for kind in ("all-ff", "all-00", "mixed")}
    non_ff_ranges = []
    for run in runs:
        if run["class"] != "all-ff":
            if non_ff_ranges and non_ff_ranges[-1][1] == run["start"]:
                non_ff_ranges[-1][1] = run["end_exclusive"]
            else:
                non_ff_ranges.append([run["start"], run["end_exclusive"]])
    return {"sector_bytes": SECTOR_BYTES, "sector_count": len(states),
            "all_ff_sectors": counts["all-ff"],
            "all_00_sectors": counts["all-00"],
            "other_sectors": counts["mixed"],
            "first_non_ff_offset": first, "last_non_ff_offset": last,
            "non_ff_sector_ranges_end_exclusive": non_ff_ranges,
            "sector_runs": runs}


def analyze(source):
    try:
        files = read_backup(source)
    except (OSError, KeyError, zipfile.BadZipFile) as exc:
        raise BackupError("Cannot read complete backup: " + str(exc)) from exc
    report = checked_report(files)
    image = files[BACKUP_FILES[1]]
    computed = sector_map(image)
    supplied = report.get("analysis")
    if not isinstance(supplied, dict):
        raise BackupError("Backup report has no sector analysis")
    for field in ("sector_bytes", "all_ff_sectors", "all_00_sectors",
                  "other_sectors", "first_non_ff_offset", "last_non_ff_offset",
                  "non_ff_sector_ranges_end_exclusive"):
        if supplied.get(field) != computed[field]:
            raise BackupError("Backup report disagrees on " + field)
    return {"format": "ULX5M-GS SERV flash-sector-analysis-v1",
            "input": str(source),
            "device_jedec_from_report": report["device_jedec_hex"],
            "flash_bytes": FLASH_BYTES,
            "both_reads_verified": True,
            "sha256": hashlib.sha256(image).hexdigest(),
            "sector_analysis": computed,
            "write_authorized": False,
            "note": "All-FF sectors are observed data, not verified writable regions."}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path,
                        help="Directory or ZIP containing both flash passes and report")
    parser.add_argument("--json-out", type=Path,
                        help="Optionally create a new JSON analysis (never overwrite)")
    args = parser.parse_args(argv)
    try:
        result = analyze(args.input)
        sectors = result["sector_analysis"]
        print("[PASS] 2 matching 4 MiB flash reads; SHA-256 " + result["sha256"])
        print("[SECTORS] mixed=%d all-00=%d all-FF=%d" % (
            sectors["other_sectors"], sectors["all_00_sectors"],
            sectors["all_ff_sectors"]))
        if sectors["last_non_ff_offset"] is not None:
            print("[LAST NON-FF] 0x%06X" % sectors["last_non_ff_offset"])
        else:
            print("[LAST NON-FF] none")
        print("[SECTOR RUNS] address ranges inclusive")
        for run in sectors["sector_runs"]:
            print("  0x%06X..0x%06X %-6s (%d sectors)" % (
                run["start"], run["end_exclusive"] - 1,
                run["class"], run["sector_count"]))
        print("[POLICY] All flash remains protected; no writable range inferred")
        if args.json_out is not None:
            with args.json_out.open("x", encoding="utf-8", newline="\n") as dst:
                json.dump(result, dst, indent=2)
                dst.write("\n")
            print("[REPORT] " + str(args.json_out))
    except (BackupError, OSError) as exc:
        print("[FAIL] " + str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
