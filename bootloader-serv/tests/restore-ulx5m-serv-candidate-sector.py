#!/usr/bin/env python3
"""Read-only check or explicitly authorized JTAG restore of candidate 0x200000.

This tool NEVER writes the factory boot area. It does not select a boot slot.
Hardware access is native Windows only (Tigard via openFPGALoader.exe).
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location(
    "ulx5m_qualifier", HERE / "qualify-ulx5m-serv-jtag-write.py")
qual = importlib.util.module_from_spec(spec)
spec.loader.exec_module(qual)

TARGET = 0x200000
SECTOR = 4096
ACK = "I_ACCEPT_200000_SECTOR_RESTORE_RISK"


def validate_backup(directory):
    image, sha = qual.verified_backup(directory)
    if image[TARGET:TARGET + SECTOR] != b"\xff" * SECTOR:
        raise ValueError("Factory candidate sector is not empty")
    return image, sha


def write_cmd(loader, frequency, image):
    if image.suffix != ".bin" or image.stat().st_size != SECTOR:
        raise ValueError("Restore requires exact 4096-byte raw image")
    return qual.jtag_cmd(loader, frequency) + [
        "-f", "--verify", "--offset", str(TARGET), str(image)]


def report(path, record):
    temp = path.with_name(path.name + ".writing")
    with temp.open("x", encoding="ascii", newline="\n") as f:
        f.write(json.dumps(record, sort_keys=True, indent=2) + "\n")
    os.replace(temp, path)


def execute(loader, freq, backup, restore_file=None):
    qual.detect(loader, freq)
    header = qual.read_region(loader, freq, 0, SECTOR)
    qual.compare("factory boot header", header, backup[:SECTOR])
    # Whole-image comparison permits exactly the targeted 4KiB to differ.
    flash = qual.read_region(loader, freq, 0, qual.FLASH_BYTES)
    if flash[:TARGET] != backup[:TARGET] or flash[TARGET + SECTOR:] != backup[TARGET + SECTOR:]:
        raise ValueError("Unexpected changes outside candidate sector; no write allowed")
    if restore_file is None:
        print("[READ ONLY] Candidate sector matches factory: {}".format(
            flash[TARGET:TARGET + SECTOR] == backup[TARGET:TARGET + SECTOR]))
        return "read_only_complete"
    print("[RESTORE] Replacing only 0x200000..0x200fff from verified backup", flush=True)
    qual.call(write_cmd(loader, freq, restore_file), timeout=180)
    full = qual.read_region(loader, freq, 0, qual.FLASH_BYTES)
    qual.compare("full restored 4 MiB", full, backup)
    return "restored_and_verified"


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--backup-dir", type=Path, required=True)
    p.add_argument("--report", type=Path, required=True)
    p.add_argument("--loader", type=Path, default=HERE.parents[1] / "bin" / "openFPGALoader.exe")
    p.add_argument("--freq-khz", type=int, default=1000)
    p.add_argument("--run", action="store_true", help="Only compare flash, no changes")
    p.add_argument("--restore", action="store_true", help="Write original 4 KiB and verify 4 MiB")
    p.add_argument("--confirm-restore", default="")
    args = p.parse_args(argv)
    try:
        if args.run and args.restore:
            raise ValueError("Choose one action")
        if args.restore and args.confirm_restore != ACK:
            raise ValueError("Explicit exact --confirm-restore required")
        if not args.restore and args.confirm_restore:
            raise ValueError("Acknowledgment without restore")
        if args.report.exists() or Path(str(args.report) + ".writing").exists():
            raise ValueError("Report exists; refusing overwrite")
        if not args.loader.is_file():
            raise ValueError("Missing Windows openFPGALoader.exe")
        qual.jtag_cmd(args.loader, args.freq_khz)
        backup, sha = validate_backup(args.backup_dir)
        print("[BACKUP] Verified dual factory 4 MiB image: " + sha, flush=True)
        if not args.run and not args.restore:
            print("[DRY RUN] No programmer commands; add --run or explicit --restore")
            return 0
        args.report.parent.mkdir(parents=True, exist_ok=True)
        record = {"format": "ULX5M-CANDIDATE-RESTORE-V1",
                  "backup_sha256": sha, "target": TARGET, "size": SECTOR,
                  "phase": "started", "mutating": args.restore}
        directory = args.report.with_name(args.report.stem + "-recovery-files")
        original = None
        if args.restore:
            if directory.exists():
                raise ValueError("Recovery directory already exists")
            directory.mkdir()
            original = directory / "original-200000.bin"
            with original.open("xb") as f:
                f.write(backup[TARGET:TARGET + SECTOR])
                f.flush()
                os.fsync(f.fileno())
            record["recovery_file"] = str(original)
            record["phase"] = "restore_image_saved"
        report(args.report, record)
        try:
            state = execute(args.loader, args.freq_khz, backup, original)
            record["phase"] = state
        except Exception as exc:
            record["phase"] = "FAILED_KEEP_RECOVERY_FILES"
            record["error"] = str(exc)
            qual.atomic_report(args.report, record)
            raise
        qual.atomic_report(args.report, record)
        print("[REPORT] " + str(args.report))
        return 0
    except (OSError, ValueError, KeyError) as exc:
        print("[FAIL] " + str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
