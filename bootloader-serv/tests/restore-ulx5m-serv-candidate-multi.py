#!/usr/bin/env python3
"""Read-only check or explicitly authorized JTAG restore of candidate 0x200000..0x201fff (two sectors).

This tool NEVER writes the factory boot area. It does not select a boot slot.
Hardware access is native Windows only (Tigard via openFPGALoader.exe).
"""
import argparse
import importlib.util
import json
import os
import zlib
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location(
    "ulx5m_qualifier", HERE / "qualify-ulx5m-serv-jtag-write.py")
qual = importlib.util.module_from_spec(spec)
spec.loader.exec_module(qual)

TARGET = 0x200000
SECTOR = 8192
ERASE = 4096
ACK = "I_ACCEPT_200000_8192_RESTORE_RISK"


def validate_backup(directory):
    image, sha = qual.verified_backup(directory)
    if image[TARGET:TARGET + SECTOR] != b"\xff" * SECTOR:
        raise ValueError("Factory candidate sector is not empty")
    return image, sha


def write_cmd(loader, frequency, image, offset):
    if offset not in (TARGET, TARGET + ERASE):
        raise ValueError("Restore offset must be one of the two candidate sectors")
    if image.suffix != ".bin" or image.stat().st_size != ERASE:
        raise ValueError("Restore requires exact 4096-byte raw sector")
    return qual.jtag_cmd(loader, frequency) + [
        "-f", "--verify", "--offset", str(offset), str(image)]


def report(path, record):
    temp = path.with_name(path.name + ".writing")
    with temp.open("x", encoding="ascii", newline="\n") as f:
        f.write(json.dumps(record, sort_keys=True, indent=2) + "\n")
    os.replace(temp, path)


def expected_sector_from_report(path, backup_sha):
    record = json.loads(path.read_text(encoding="ascii"))
    if record.get("format") != "ULX5M-DFU-PHYSICAL-8K-V1" or \
       record.get("backup_sha256") != backup_sha or \
       record.get("target") != TARGET or \
       record.get("phase") != "usb_candidate_verified_restore_required":
        raise ValueError("USB write report does not show a verified candidate")
    size = record.get("payload_bytes")
    if type(size) is not int or size != 8192 or \
       record.get("blocks_completed") != size // 64:
        raise ValueError("Unexpected USB write size or incomplete block count")
    data = bytes(((i * 37 + (i // 256) * 11 + 0x5a) & 0xff)
                 for i in range(size))
    if record.get("payload_crc32") != "{:08x}".format(zlib.crc32(data) & 0xffffffff):
        raise ValueError("USB report CRC32 does not match expected deterministic pattern")
    return data + b"\xff" * (SECTOR - size)


def execute(loader, freq, backup, restore_file=None, expected_sector=None):
    qual.detect(loader, freq)
    # The JTAG reader only supports 4 KiB or 16 KiB individual dumps.
    # The 8 KiB candidate size must not be used as the header read length.
    header = qual.read_region(loader, freq, 0, qual.CHUNK)
    qual.compare("factory boot header", header, backup[:qual.CHUNK])
    # Whole-image comparison permits exactly the targeted 8KiB to differ.
    flash = qual.read_region(loader, freq, 0, qual.FLASH_BYTES)
    if flash[:TARGET] != backup[:TARGET] or flash[TARGET + SECTOR:] != backup[TARGET + SECTOR:]:
        raise ValueError("Unexpected changes outside candidate sector; no write allowed")
    if expected_sector is not None:
        qual.compare("independent JTAG candidate pattern + erased padding",
                     flash[TARGET:TARGET + SECTOR], expected_sector)
    if restore_file is None:
        print("[READ ONLY] Candidate sector matches factory: {}".format(
            flash[TARGET:TARGET + SECTOR] == backup[TARGET:TARGET + SECTOR]))
        return ("read_only_verified_candidate_pattern" if expected_sector is not None
                else "read_only_complete")
    print("[RESTORE] Replacing only 0x200000..0x201fff from verified backup", flush=True)
    # Each 4 KiB write is independently bounded; preserve both recovery files.
    for i in range(2):
        sector_path = restore_file.with_name("original-{:06x}.bin".format(TARGET + i * ERASE))
        if sector_path.stat().st_size != ERASE:
            raise ValueError("Missing complete original sector file")
        qual.call(write_cmd(loader, freq, sector_path, TARGET + i * ERASE), timeout=180)
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
    p.add_argument("--expected-write-report", type=Path,
                   help="With --run: verify exact candidate bytes from successful USB report")
    p.add_argument("--restore", action="store_true", help="Write original two 4 KiB sectors; verify 4 MiB")
    p.add_argument("--confirm-restore", default="")
    args = p.parse_args(argv)
    try:
        if args.run and args.restore:
            raise ValueError("Choose one action")
        if args.expected_write_report and not args.run:
            raise ValueError("--expected-write-report requires read-only --run")
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
        expected_sector = (expected_sector_from_report(args.expected_write_report, sha)
                           if args.expected_write_report else None)
        args.report.parent.mkdir(parents=True, exist_ok=True)
        record = {"format": "ULX5M-CANDIDATE-RESTORE-8K-V1",
                  "backup_sha256": sha, "target": TARGET, "size": SECTOR,
                  "phase": "started", "mutating": args.restore}
        directory = args.report.with_name(args.report.stem + "-recovery-files")
        original = None
        if args.restore:
            if directory.exists():
                raise ValueError("Recovery directory already exists")
            directory.mkdir()
            original = directory / "original-200000-8k.bin"
            with original.open("xb") as f:
                f.write(backup[TARGET:TARGET + SECTOR])
                f.flush()
                os.fsync(f.fileno())
            for i in range(2):
                sector_path = directory / "original-{:06x}.bin".format(TARGET + i * ERASE)
                with sector_path.open("xb") as f:
                    f.write(backup[TARGET + i * ERASE:TARGET + (i + 1) * ERASE])
                    f.flush()
                    os.fsync(f.fileno())
            record["recovery_file"] = str(original)
            record["phase"] = "restore_image_saved"
        report(args.report, record)
        try:
            state = execute(args.loader, args.freq_khz, backup, original, expected_sector)
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
