#!/usr/bin/env python3
"""Qualify a narrowly bounded JTAG flash restore using the verified backup.

The default run reads only. The optional explicitly authorized write-test
changes a single erased 4 KiB sector at the very end of ULX5M-GS flash,
then restores it to the original all-0xff state. Neither a successful test
nor an erased region proves boot slot ownership or boot selection.
"""

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
RECOVERY_FILE = HERE / "check-ulx5m-serv-jtag-recovery.py"
_spec = importlib.util.spec_from_file_location("ulx5m_jtag_reference", RECOVERY_FILE)
_ref = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_ref)

FLASH_BYTES = 0x400000
BASE = 0x3FF000
NEIGHBOR_BASE = 0x3F0000
NEIGHBOR_LEN = 0x10000
CHUNK = 0x4000
IDCODE = "0x20000001"
JEDEC = "0x1f4216"
FACTORY_SHA256 = "74b3accfa91b04efee753a72b6b9787eb20bfb217266198fefb349ca1cb9509d"
ACK = "I_ACCEPT_3FF000_FLASH_ERASE_AND_RESTORE_RISK"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def jtag_cmd(loader, freq):
    if not 1 <= freq <= 10000:
        raise ValueError("Frequency must be 1..10000 kHz")
    return [str(loader), "-c", "tigard", "--freq", f"{freq}k"]


def detect_cmd(loader, freq):
    return jtag_cmd(loader, freq) + ["--detect", "-v"]


def read_cmd(loader, freq, offset, size, output):
    if size not in (4096, 16384) or offset < 0 or offset % 4096 or offset + size > FLASH_BYTES:
        raise ValueError("Unsafe read address or length")
    return jtag_cmd(loader, freq) + ["--dump-flash", "--offset", str(offset),
                                     "--file-size", str(size), str(output)]


def write_cmd(loader, freq, filepath, offset=BASE):
    if offset != BASE or filepath.stat().st_size != 4096:
        raise ValueError("Only the final 4096-byte flash sector may be written")
    if filepath.suffix != ".bin":
        raise ValueError("Write input must be a raw .bin file")
    # No bulk-erase, --unprotect-flash, -m or -r allowed.
    return jtag_cmd(loader, freq) + ["-f", "--verify", "--offset", str(BASE), str(filepath)]


def call(cmd, timeout=120):
    try:
        result = subprocess.run(cmd, capture_output=True, text=True,
                                check=False, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise ValueError(f"Programmer command failed: {exc}") from exc
    output = ((result.stdout or "") + (result.stderr or "")).strip()
    if result.returncode or "no device found" in output.lower():
        tail = output[-1000:]
        raise ValueError(f"Programmer returned {result.returncode}: {tail}")
    return output


def detect(loader, freq):
    output = call(detect_cmd(loader, freq), timeout=30)
    count = re.search(r"(?m)^found\s+(\d+)\s+devices\s*$", output)
    codes = re.findall(r"(?im)^\s*idcode\s+(0x[0-9a-f]+)\s*$", output)
    if not count or int(count.group(1)) != 1 or [c.lower() for c in codes] != [IDCODE]:
        raise ValueError(f"Expected exactly one GateMate JTAG IDCODE {IDCODE}: {output}")
    print("[JTAG] Exactly one GateMate IDCODE 0x20000001")


def read_region(loader, freq, offset, size):
    if offset % 4096 or size % 4096 or offset < 0 or offset + size > FLASH_BYTES:
        raise ValueError("Invalid flash read region")
    output = bytearray()
    with tempfile.TemporaryDirectory(prefix="ulx5m-jtag-write-read-") as tmp:
        for at in range(offset, offset + size, CHUNK):
            n = min(CHUNK, offset + size - at)
            path = Path(tmp) / f"read-{at:06x}.bin"
            text = call(read_cmd(loader, freq, at, n, path), timeout=120)
            if JEDEC not in text.lower():
                raise ValueError(f"Expected flash JEDEC {JEDEC} at 0x{at:06x}")
            if not path.is_file() or path.stat().st_size != n:
                raise ValueError(f"Incorrect flash dump length at 0x{at:06x}")
            output.extend(path.read_bytes())
            if size == FLASH_BYTES and (len(output) % (256 * 1024) == 0):
                print(f"[VERIFY] {len(output)}/{FLASH_BYTES} bytes read", flush=True)
    return bytes(output)


def verified_backup(path):
    digest = _ref.check_reference(path)
    backup = (path / "flash-pass1.bin").read_bytes()
    if digest != FACTORY_SHA256:
        raise ValueError("Backup SHA-256 differs from verified ULX5M factory image")
    if len(backup) != FLASH_BYTES or sha(backup) != digest:
        raise ValueError("Factory reference failed validation")
    if backup[NEIGHBOR_BASE:] != bytes([0xFF]) * NEIGHBOR_LEN:
        raise ValueError("Final 64 KiB is not erased in factory backup; refusing test")
    return backup, digest


def compare(label, got, expected):
    if got != expected:
        at = next(i for i, (a, b) in enumerate(zip(got, expected)) if a != b)
        raise ValueError(f"{label} mismatch at relative offset 0x{at:04x}")
    print(f"[PASS] {label}: {len(got)} bytes match expected reference")


def preflight(loader, freq, backup):
    detect(loader, freq)
    first = read_region(loader, freq, 0, 4096)
    compare("factory configuration header", first, backup[:4096])
    top = read_region(loader, freq, NEIGHBOR_BASE, NEIGHBOR_LEN)
    compare("last 64 KiB", top, backup[NEIGHBOR_BASE:])
    return top


def pattern_bytes(digest):
    seed = bytes.fromhex(digest) + b"ULX5M-JTAG-RESTORE-QUALIFY-V1"
    # Nontrivial and deterministic 4KiB pattern; original sector must be FF.
    data = bytearray()
    counter = 0
    while len(data) < 4096:
        data.extend(hashlib.sha256(seed + counter.to_bytes(4, "little")).digest())
        counter += 1
    return bytes(data[:4096])


def atomic_report(path, status):
    temp = path.with_name(path.name + ".writing")
    with temp.open("w", encoding="utf-8", newline="\n") as f:
        json.dump(status, f, indent=2, sort_keys=True)
        f.write("\n")
    os.replace(temp, path)


def artifact_dir(report):
    return report.with_name(report.stem + "-recovery-files")


def validate_restore_artifacts(directory, backup_digest, backup):
    meta = json.loads((directory / "qualification.json").read_text(encoding="utf-8"))
    if meta != {"format": "ULX5M-JTAG-WRITE-QUALIFICATION-V1",
                "backup_sha256": backup_digest, "offset": BASE,
                "length": 4096}:
        raise ValueError("Saved sector metadata does not match verified backup")
    restored = (directory / "original-3ff000.bin").read_bytes()
    if restored != backup[BASE:] or len(restored) != 4096:
        raise ValueError("Saved restore sector does not match verified backup")
    return directory / "original-3ff000.bin"


def restore(loader, freq, backup, original_path):
    print("[RESTORE] Writing original 4 KiB sector from verified backup", flush=True)
    call(write_cmd(loader, freq, original_path), timeout=180)
    sector = read_region(loader, freq, BASE, 4096)
    compare("restored final sector", sector, backup[BASE:])
    live = read_region(loader, freq, NEIGHBOR_BASE, NEIGHBOR_LEN)
    compare("restored upper 64 KiB", live, backup[NEIGHBOR_BASE:])
    hdr = read_region(loader, freq, 0, 4096)
    compare("factory header after restore", hdr, backup[:4096])
    print("[VERIFY] Independently reading all 4 MiB after restoration", flush=True)
    full = read_region(loader, freq, 0, FLASH_BYTES)
    compare("complete restored flash", full, backup)
    return True


def write_test(args, report, backup, digest):
    directory = artifact_dir(args.report)
    if directory.exists():
        raise ValueError(f"Recovery-files directory exists: {directory}")
    preflight(args.loader, args.freq_khz, backup)
    directory.mkdir()
    original = directory / "original-3ff000.bin"
    candidate = directory / "test-pattern-3ff000.bin"
    with original.open("xb") as f:
        f.write(backup[BASE:])
        f.flush()
        os.fsync(f.fileno())
    with candidate.open("xb") as f:
        f.write(pattern_bytes(digest))
        f.flush()
        os.fsync(f.fileno())
    metadata = {"format": "ULX5M-JTAG-WRITE-QUALIFICATION-V1",
                "backup_sha256": digest, "offset": BASE, "length": 4096}
    with (directory / "qualification.json").open("x", encoding="ascii", newline="\n") as f:
        f.write(json.dumps(metadata, indent=2) + "\n")
        f.flush()
        os.fsync(f.fileno())
    validate_restore_artifacts(directory, digest, backup)
    report["artifacts_dir"] = str(directory)
    report["phase"] = "recovery_files_saved_write_not_started"
    atomic_report(args.report, report)
    print("[SAVED] Original flash sector and recovery metadata saved before mutation", flush=True)
    error = None
    try:
        report["phase"] = "test_write_attempted"
        atomic_report(args.report, report)
        print("[TEST WRITE] Only 0x3FF000..0x3FFFFF; NO boot changes", flush=True)
        call(write_cmd(args.loader, args.freq_khz, candidate), timeout=180)
        compare("test pattern", read_region(args.loader, args.freq_khz, BASE, 4096), candidate.read_bytes())
        report["phase"] = "test_pattern_verified"
        atomic_report(args.report, report)
    except (OSError, ValueError, KeyboardInterrupt) as exc:
        error = str(exc) or type(exc).__name__
        report["write_error"] = error
        print(f"[WRITE FAILED] {exc}; attempting restoration regardless", flush=True)
    # Even a failed programmer command can have erased some bytes. Always
    # attempt restoring original sector once a write command was attempted.
    try:
        report["phase"] = "restoration_attempted"
        atomic_report(args.report, report)
        restore(args.loader, args.freq_khz, backup, original)
        report["restored"] = True
        report["phase"] = "restored_and_verified"
        atomic_report(args.report, report)
    except (OSError, ValueError, KeyboardInterrupt) as exc:
        report["restored"] = False
        report["restore_error"] = str(exc)
        report["phase"] = "RESTORE_UNVERIFIED_MANUAL_RECOVERY_NEEDED"
        atomic_report(args.report, report)
        print(f"[CRITICAL] Restoration not verified: {exc}", file=sys.stderr)
        print("[CRITICAL] Keep the recovery files. Power-cycle ULX5M only, then run --restore-only.", file=sys.stderr)
        return 1
    if error:
        print(f"[FAIL] Test write failed but sector restoration verified: {error}", file=sys.stderr)
        return 1
    print("[PASS] JTAG WRITE + READBACK + RESTORE + VERIFY completed; NOT boot activation")
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    root = HERE.parents[1]
    parser.add_argument("--backup-dir", required=True, type=Path)
    parser.add_argument("--report", required=True, type=Path, help="New, nonexisting JSON report")
    parser.add_argument("--loader", type=Path, default=root / "bin" / "openFPGALoader.exe")
    parser.add_argument("--freq-khz", type=int, default=1000)
    actions = parser.add_mutually_exclusive_group()
    actions.add_argument("--run", action="store_true", help="Read-only 68 KiB preflight")
    actions.add_argument("--write-test", action="store_true", help="Guarded single-sector destructive qualification")
    actions.add_argument("--restore-only", type=Path, metavar="DIR",
                         help="Explicitly restore original sector using saved recovery files")
    parser.add_argument("--confirm-write", default="", metavar="EXACT_ACK",
                        help=f"Required for --write-test/--restore-only: {ACK}")
    args = parser.parse_args(argv)
    try:
        if args.report.exists() or Path(str(args.report) + ".writing").exists():
            raise ValueError("Report file already exists; refusing overwrite")
        if not args.loader.is_file():
            raise ValueError(f"Missing openFPGALoader: {args.loader}")
        jtag_cmd(args.loader, args.freq_khz)
        backup, digest = verified_backup(args.backup_dir)
        print(f"[BACKUP] Verified 2 x 4 MiB, SHA-256 {digest}", flush=True)
        if (args.write_test or args.restore_only) and args.confirm_write != ACK:
            raise ValueError("Mutating operation requires exact --confirm-write acknowledgement")
        if not args.write_test and not args.restore_only and args.confirm_write:
            raise ValueError("Acknowledgement supplied without a mutating operation")
        if args.write_test and artifact_dir(args.report).exists():
            raise ValueError("Recovery files already exist; refusing overwrite")
        args.report.parent.mkdir(parents=True, exist_ok=True)
        report = {"format": "ULX5M-JTAG-WRITE-QUALIFICATION-V1", "backup_sha256": digest,
                  "flash_size": FLASH_BYTES, "test_offset": BASE, "test_size": 4096,
                  "original_erased": True, "test_type": "read_only_preflight",
                  "phase": "preflight_not_run", "restored": None}
        if not args.run and not args.write_test and not args.restore_only:
            print("[DRY RUN] No programmer launched, no report generated.")
            print("[DRY RUN] Add --run for read-only preflight; --write-test requires exact acknowledgement.")
            return 0
        if args.restore_only:
            original = validate_restore_artifacts(args.restore_only, digest, backup)
            report["test_type"] = "restore_only"
            report["artifacts_dir"] = str(args.restore_only)
            report["phase"] = "restoration_attempted"
            atomic_report(args.report, report)
            detect(args.loader, args.freq_khz)
            restore(args.loader, args.freq_khz, backup, original)
            report["phase"] = "restored_and_verified"
            report["restored"] = True
            atomic_report(args.report, report)
            print("[PASS] Original 4 KiB sector restored and independently verified")
            return 0
        if args.write_test:
            report["test_type"] = "explicitly_authorized_write_and_restore"
            return write_test(args, report, backup, digest)
        atomic_report(args.report, report)
        try:
            preflight(args.loader, args.freq_khz, backup)
        except ValueError as exc:
            report["phase"] = "preflight_failed_no_flash_write"
            report["error"] = str(exc)
            atomic_report(args.report, report)
            raise
        report["phase"] = "read_only_preflight_passed"
        atomic_report(args.report, report)
        print(f"[REPORT] {args.report}")
        print("[POLICY] No erase, program, protection or boot-selection operation issued")
        return 0
    except (OSError, ValueError, json.JSONDecodeError, KeyError) as exc:
        print(f"[FAIL] {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
