#!/usr/bin/env python3
"""Independently read GateMate configuration flash via JTAG and compare a backup.

Read-only preflight. Does not erase, program, reset, or change flash protection.
The Windows openFPGALoader flash-read path uses stack-sized transfer buffers;
small requests avoid the observed 0xC00000FD crash on a 4 MiB dump.
"""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

FLASH_SIZE = 4 * 1024 * 1024
FLASH_JEDEC = "1f4216"
CHUNK_SIZE = 16 * 1024


def sha256_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def check_reference(backup_dir):
    report_path = backup_dir / "flash-backup-report.json"
    report = json.loads(report_path.read_text(encoding="utf-8"))
    if report.get("format") != "ULX5M-GS SERV flash-backup-v1":
        raise ValueError("Unexpected backup report format")
    if report.get("device_jedec_hex", "").lower() != FLASH_JEDEC:
        raise ValueError("Unexpected JEDEC ID in backup report")
    if report.get("size_bytes") != FLASH_SIZE:
        raise ValueError("Unexpected flash size in backup report")
    if report.get("byte_for_byte_match") is not True:
        raise ValueError("Original backup was not recorded as matching")
    passes = report.get("passes")
    if not isinstance(passes, list) or len(passes) != 2:
        raise ValueError("Expected two independent backup passes")
    expected = None
    for i, item in enumerate(passes, 1):
        name = f"flash-pass{i}.bin"
        if item.get("file") != name:
            raise ValueError(f"Unexpected backup pass {i} filename")
        path = backup_dir / name
        if path.stat().st_size != FLASH_SIZE:
            raise ValueError(f"Bad backup size: {path}")
        actual = sha256_file(path)
        if actual != item.get("sha256"):
            raise ValueError(f"Backup {i} does not match the report hash")
        if expected is not None and actual != expected:
            raise ValueError("Backup passes have different SHA-256 hashes")
        expected = actual
    with (backup_dir / "flash-pass1.bin").open("rb") as first, \
         (backup_dir / "flash-pass2.bin").open("rb") as second:
        while True:
            a = first.read(64 * 1024)
            b = second.read(64 * 1024)
            if a != b:
                raise ValueError("Backup passes differ byte-for-byte")
            if not a:
                break
    return expected


def validate_chunk_size(size):
    if size not in (4096, 8192, 16384):
        raise ValueError("Chunk size must be 4096, 8192, or 16384 bytes")


def build_dump_command(loader, output, freq, offset=0, length=CHUNK_SIZE):
    if freq <= 0:
        raise ValueError("JTAG frequency must be positive")
    validate_chunk_size(length)
    if offset < 0 or offset % 4096 or offset + length > FLASH_SIZE:
        raise ValueError("Invalid JTAG flash read offset/length")
    # Never add -f/--write-flash, -m, --reset, or any protection command.
    return [str(loader), "-c", "tigard", "--freq", f"{freq}k",
            "--dump-flash", "--offset", str(offset), "--file-size", str(length),
            str(output)]


def read_chunk(loader, output, freq, offset, length):
    cmd = build_dump_command(loader, output, freq, offset, length)
    result = subprocess.run(cmd, check=False)
    if result.returncode:
        code = result.returncode & 0xFFFFFFFF
        raise ValueError(f"JTAG read failed at 0x{offset:06x}, exit={result.returncode} "
                         f"(0x{code:08x}); no write attempted")
    if not output.is_file() or output.stat().st_size != length:
        raise ValueError(f"JTAG chunk at 0x{offset:06x} missing or wrong size")
    return output.read_bytes()


def probe_chunk(args, backup_path):
    with tempfile.TemporaryDirectory(prefix="ulx5m-jtag-read-", dir=args.output.parent) as tmp:
        chunk_file = Path(tmp) / "probe.bin"
        actual = read_chunk(args.loader, chunk_file, args.freq_khz, 0, args.chunk_bytes)
        with backup_path.open("rb") as original:
            expected = original.read(args.chunk_bytes)
        if actual != expected:
            raise ValueError("JTAG probe differs from verified USB backup at offset 0x000000")
    print(f"[PASS] Independent JTAG read matched first {args.chunk_bytes} backup bytes")
    print("[NOTE] This verifies READ only, not recovery flash WRITE access.")


def full_chunked_read(args, backup_path, digest):
    partial = args.output.with_name(args.output.name + ".partial")
    parts_dir = args.output.with_name(args.output.name + ".parts")
    if partial.exists() or parts_dir.exists():
        raise ValueError("Partial output or parts directory already exists; refusing overwrite")
    parts_dir.mkdir()
    accumulated = hashlib.sha256()
    try:
        with backup_path.open("rb") as original, partial.open("xb") as destination:
            for offset in range(0, FLASH_SIZE, args.chunk_bytes):
                length = min(args.chunk_bytes, FLASH_SIZE - offset)
                chunk_file = parts_dir / f"chunk-{offset:06x}.bin"
                actual = read_chunk(args.loader, chunk_file, args.freq_khz, offset, length)
                expected = original.read(length)
                if actual != expected:
                    different = next((i for i, (a, b) in enumerate(zip(actual, expected))
                                      if a != b), 0)
                    raise ValueError(f"JTAG flash differs from USB backup at "
                                     f"0x{offset + different:06x}; no write attempted")
                destination.write(actual)
                accumulated.update(actual)
                chunk_file.unlink()
                if (offset + length) % (256 * 1024) == 0:
                    print(f"[READ] {offset + length}/{FLASH_SIZE} bytes verified", flush=True)
        if accumulated.hexdigest() != digest or partial.stat().st_size != FLASH_SIZE:
            raise ValueError("JTAG image SHA-256/size mismatch")
        if args.output.exists():
            raise ValueError("Output appeared while reading; refusing overwrite")
        partial.rename(args.output)
        parts_dir.rmdir()
    except (OSError, ValueError):
        print(f"[PARTIAL] Retained any captured bytes in {partial} and {parts_dir}",
              file=sys.stderr)
        raise
    print(f"[PASS] Independent JTAG flash read matches both USB backups: {digest}")
    print("[NOTE] Flash READ access is verified; flash recovery WRITE access is not yet proven.")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    root = Path(__file__).resolve().parents[2]
    parser.add_argument("--backup-dir", type=Path, required=True,
                        help="Directory containing the two verified USB flash reads")
    parser.add_argument("--output", type=Path, required=True,
                        help="New JTAG flash readback file (must not exist)")
    parser.add_argument("--loader", type=Path, default=root / "bin" / "openFPGALoader.exe")
    parser.add_argument("--freq-khz", type=int, default=1000)
    parser.add_argument("--chunk-bytes", type=int, default=CHUNK_SIZE)
    operation = parser.add_mutually_exclusive_group()
    operation.add_argument("--run", action="store_true", help="Perform full chunked flash read")
    operation.add_argument("--probe-only", action="store_true",
                           help="Read and compare one chunk; create no final image")
    args = parser.parse_args(argv)

    try:
        validate_chunk_size(args.chunk_bytes)
        digest = check_reference(args.backup_dir)
        if args.output.exists():
            raise ValueError(f"Output already exists (refusing overwrite): {args.output}")
        cmd = build_dump_command(args.loader, args.output, args.freq_khz,
                                 0, args.chunk_bytes)
        if not args.loader.is_file():
            raise ValueError(f"Cannot find loader: {args.loader}")
        print(f"[BACKUP] Two verified 4 MiB copies, SHA-256 {digest}")
        print("[JTAG] " + subprocess.list2cmdline(cmd))
        if not args.run and not args.probe_only:
            print("[PREFLIGHT] No read performed. Add --probe-only or --run.")
            return 0
        args.output.parent.mkdir(parents=True, exist_ok=True)
        if args.probe_only:
            probe_chunk(args, args.backup_dir / "flash-pass1.bin")
        else:
            full_chunked_read(args, args.backup_dir / "flash-pass1.bin", digest)
        return 0
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"[FAIL] {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
