#!/usr/bin/env python3
"""Make and compare two read-only ULX5M-GS SERV 4 MiB flash dumps.

Run with native Windows Python/WinUSB; WSL has no direct USB device access.
Only vendor control IN requests 0x51, 0x52, 0x57 and 0x58 are issued.
No DFU transfers, SPI writes, resets, or JTAG programming are performed.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import sys
import time

VID, PID = 0x1D50, 0x614B
FLASH_BYTES = 0x400000
READ_BYTES = 32  # Firmware USB request 0x52 rejects larger requests.
SECTOR_BYTES = 4096
EXPECTED_JEDEC = bytes((0x1f, 0x42, 0x16))
EXPECTED_LAYOUT = (FLASH_BYTES, SECTOR_BYTES, 256, 0, FLASH_BYTES, 0, 3)
EXPECTED_STAGE = (0, 0, 0, 2, 0)
READ_REQ = 0x52


def query_preflight(dev, timeout_ms):
    """Check identity, fail-closed layout, and empty volatile DFU staging."""
    jedec = bytes(dev.ctrl_transfer(0xc0, 0x51, 0, 0, 3,
                                    timeout=timeout_ms))
    if jedec != EXPECTED_JEDEC:
        raise RuntimeError("unexpected JEDEC: {} (expected {})".format(
            jedec.hex(), EXPECTED_JEDEC.hex()))
    raw = bytes(dev.ctrl_transfer(0xc0, 0x58, 0, 0, 32,
                                  timeout=timeout_ms))
    if len(raw) != 32 or raw[:4] != b"FLM1":
        raise RuntimeError("missing or malformed 32-byte FLM1 report")
    values = struct.unpack_from("<7I", raw, 4)
    if values != EXPECTED_LAYOUT:
        raise RuntimeError("unrecognized flash policy {}; refusing backup".format(
            values))
    stage = bytes(dev.ctrl_transfer(0xc0, 0x57, 0, 0, 16,
                                    timeout=timeout_ms))
    if len(stage) != 16 or stage[:4] != b"STG1":
        raise RuntimeError("missing or malformed 16-byte STG1 report")
    state = struct.unpack_from("<IIHBB", stage, 4)
    if state != EXPECTED_STAGE:
        raise RuntimeError("RAM staging not empty/IDLE: {}; run ABORT separately".format(
            state))
    return jedec


def read_at(dev, offset, count, timeout_ms, retries, sleep=time.sleep):
    """Retry idempotent flash READ only; never retry any DFU OUT operation."""
    if offset < 0 or count < 1 or count > READ_BYTES or \
            offset > FLASH_BYTES or count > FLASH_BYTES - offset:
        raise ValueError("invalid 0x52 offset/length")
    for attempt in range(retries + 1):
        try:
            data = bytes(dev.ctrl_transfer(0xc0, READ_REQ,
                                           offset & 0xffff, offset >> 16,
                                           count, timeout=timeout_ms))
            if len(data) != count:
                raise IOError("short read: expected {}, got {}".format(
                    count, len(data)))
            return data
        except (OSError, IOError) as exc:
            if attempt == retries:
                raise IOError("flash READ at 0x{:06x} failed after {} tries: {}".format(
                    offset, retries + 1, exc)) from exc
            sleep(0.1 * (attempt + 1))


def capture_pass(dev, destination, size, timeout_ms, retries,
                 delay_ms=0, progress_bytes=0x10000, sleep=time.sleep):
    """Stream one physical read to a new file; never overwrite existing data."""
    digest = hashlib.sha256()
    offset = 0
    with destination.open("xb") as output:
        while offset < size:
            count = min(READ_BYTES, size - offset)
            data = read_at(dev, offset, count, timeout_ms, retries, sleep)
            output.write(data)
            digest.update(data)
            offset += count
            if progress_bytes and (offset % progress_bytes == 0 or offset == size):
                print("[READ] {}: {}/{} bytes".format(
                    destination.name, offset, size), flush=True)
            if delay_ms and offset < size:
                sleep(delay_ms / 1000.0)
        output.flush()
        os.fsync(output.fileno())
    return digest.hexdigest()


def compare_passes(first, second):
    """Byte-for-byte compare the two saved images; report first changed byte."""
    if first.stat().st_size != FLASH_BYTES or second.stat().st_size != FLASH_BYTES:
        raise RuntimeError("one or both backups have an incorrect size")
    offset = 0
    with first.open("rb") as a, second.open("rb") as b:
        while True:
            left, right = a.read(0x10000), b.read(0x10000)
            if not left and not right:
                return
            if left != right:
                for i, (x, y) in enumerate(zip(left, right)):
                    if x != y:
                        raise RuntimeError("flash passes differ at 0x{:06x}: "
                                           "pass1={:02x} pass2={:02x}".format(
                                               offset + i, x, y))
                raise RuntimeError("flash passes differ in block at 0x{:06x}".format(
                    offset))
            offset += len(left)


def inspect_erasure(path):
    """Report physical fill patterns, NOT asserted GateMate boot boundaries."""
    erased = zero = mixed = 0
    occupied = []
    first_non_ff = last_non_ff = None
    with path.open("rb") as source:
        for index in range(FLASH_BYTES // SECTOR_BYTES):
            chunk = source.read(SECTOR_BYTES)
            if len(chunk) != SECTOR_BYTES:
                raise RuntimeError("truncated image while inspecting sectors")
            if chunk == b"\xff" * SECTOR_BYTES:
                erased += 1
                continue
            occupied.append(index)
            if chunk == b"\x00" * SECTOR_BYTES:
                zero += 1
            else:
                mixed += 1
            non_ff = [i for i, byte in enumerate(chunk) if byte != 0xff]
            low, high = non_ff[0], non_ff[-1]
            addr = index * SECTOR_BYTES
            if first_non_ff is None:
                first_non_ff = addr + low
            last_non_ff = addr + high
    spans = []
    for index in occupied:
        if spans and index == spans[-1][1]:
            spans[-1][1] += 1
        else:
            spans.append([index, index + 1])
    return {
        "sector_bytes": SECTOR_BYTES,
        "all_ff_sectors": erased,
        "all_00_sectors": zero,
        "other_sectors": mixed,
        "first_non_ff_offset": first_non_ff,
        "last_non_ff_offset": last_non_ff,
        "non_ff_sector_ranges_end_exclusive": [
            [start * SECTOR_BYTES, end * SECTOR_BYTES]
            for start, end in spans],
    }


def open_device():
    if sys.platform != "win32":
        raise RuntimeError("run from native Windows PowerShell, not WSL")
    try:
        import usb.backend.libusb1
        import usb.core
    except ImportError as exc:
        raise RuntimeError("install PyUSB in native Windows Python") from exc
    dll = Path(__file__).resolve().parents[2] / "bin" / "libusb-1.0.dll"
    if not dll.is_file():
        raise RuntimeError("missing libusb backend DLL: {}".format(dll))
    backend = usb.backend.libusb1.get_backend(
        find_library=lambda _: str(dll))
    if backend is None:
        raise RuntimeError("unable to load libusb-1.0.dll")
    dev = usb.core.find(idVendor=VID, idProduct=PID, backend=backend)
    if dev is None:
        raise RuntimeError("ULX5M 1d50:614b not found")
    return dev


def backup(dev, directory, timeout_ms=5000, retries=2, delay_ms=0,
           size=FLASH_BYTES):
    """Two separate reads. Completed image and report files are never replaced."""
    if size != FLASH_BYTES:
        raise ValueError("the safety-checked backup must cover all 4 MiB")
    if not directory.is_dir():
        raise RuntimeError("create the output directory first: {}".format(directory))
    names = ("flash-pass1.bin", "flash-pass2.bin", "flash-backup-report.json")
    outputs = [directory / name for name in names]
    partials = [directory / (name + ".partial") for name in names[:2]]
    for path in outputs + partials:
        if path.exists():
            raise FileExistsError("refusing to overwrite: {}".format(path))
    digests = []
    for index in (0, 1):
        query_preflight(dev, timeout_ms)
        print("[PASS {}] 4 MiB read-only flash capture".format(index + 1),
              flush=True)
        digest = capture_pass(dev, partials[index], FLASH_BYTES, timeout_ms,
                              retries, delay_ms)
        # Rename only complete dumps. Unexpected errors retain .partial.
        partials[index].rename(outputs[index])
        digests.append(digest)
        print("[SHA256 {}] {}".format(index + 1, digest), flush=True)
    query_preflight(dev, timeout_ms)
    compare_passes(outputs[0], outputs[1])
    if digests[0] != digests[1]:
        raise RuntimeError("SHA-256 mismatch despite byte comparison")
    analysis = inspect_erasure(outputs[0])
    if analysis["first_non_ff_offset"] is None or \
            analysis["all_00_sectors"] == FLASH_BYTES // SECTOR_BYTES:
        raise RuntimeError("the flash appears entirely erased/zero-filled; "
                           "preserving both dumps for manual investigation")
    report = {
        "format": "ULX5M-GS SERV flash-backup-v1",
        "device_jedec_hex": EXPECTED_JEDEC.hex(),
        "size_bytes": FLASH_BYTES,
        "read_chunk_bytes": READ_BYTES,
        "flash_policy": "FLM1 all-write-protected; boundaries unverified",
        "passes": [
            {"file": outputs[i].name, "sha256": digests[i]}
            for i in (0, 1)],
        "byte_for_byte_match": True,
        "analysis": analysis,
    }
    with outputs[2].open("x", encoding="utf-8", newline="\n") as output:
        json.dump(report, output, indent=2)
        output.write("\n")
    print("[MATCH] Both 4 MiB files identical; SHA-256 {}".format(digests[0]))
    print("[SECTORS] all-FF={} all-00={} other={}".format(
        analysis["all_ff_sectors"], analysis["all_00_sectors"],
        analysis["other_sectors"]))
    print("[REPORT] {}".format(outputs[2]))
    print("[PASS] two physical read-only flash captures verified")
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", required=True, type=Path,
                        help="existing empty/new directory to hold two dumps and report")
    parser.add_argument("--timeout-ms", type=int, default=5000)
    parser.add_argument("--retries", type=int, default=2,
                        help="retries per idempotent READ request (default: 2)")
    parser.add_argument("--delay-ms", type=float, default=0.0,
                        help="optional pause between READ requests")
    args = parser.parse_args()
    if args.timeout_ms <= 0 or args.retries < 0 or args.retries > 10 or \
            args.delay_ms < 0:
        parser.error("invalid timeout, retries, or delay")
    try:
        backup(open_device(), args.output_dir, args.timeout_ms,
               args.retries, args.delay_ms)
        return 0
    except Exception as exc:
        print("[FAIL] {}: {}".format(type(exc).__name__, exc), file=sys.stderr)
        print("[SAFE] No flash writes sent. Keep any completed or partial dumps "
              "for review; use a new output directory on retry.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
