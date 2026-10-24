#!/usr/bin/env python3
"""SRAM-only FWTN native application slot (0x201000), Windows USB probe.

Read-only unless BOTH --write-test and an exact acknowledgment are present.
Physical writes affect one 4KiB secondary-application sector. Never boot
from it, and never use this tool against FWT3 or production firmware.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import sys
import zlib

VID, PID = 0x1d50, 0x614b
FIRST_STAGE_CHECK = 0x000000
META = 0x200000
NATIVE = 0x201000
SECTOR = 4096
APP_BYTES = 3026
APP_SHA = "68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd"
FACTORY_SHA = "74b3accfa91b04efee753a72b6b9787eb20bfb217266198fefb349ca1cb9509d"
ACK = "I_ACCEPT_201000_4096_USB_FLASH_WRITE_RISK"


def verify_app(path):
    data = path.read_bytes()
    if len(data) != APP_BYTES or hashlib.sha256(data).hexdigest() != APP_SHA:
        raise ValueError("Expected exact hardware-tested 3026-byte walking-LED image")
    return data


def verify_backups(a, b):
    x, y = a.read_bytes(), b.read_bytes()
    if len(x) != 0x400000 or x != y or hashlib.sha256(x).hexdigest() != FACTORY_SHA:
        raise ValueError("Two independent 4MiB factory backup copies must match pinned SHA")
    if x[META:NATIVE + SECTOR] != b"\xff" * (2 * SECTOR):
        raise ValueError("Candidate metadata/application sectors were not erased in factory")
    return x


def status(dev, timeout):
    b = bytes(dev.ctrl_transfer(0xc0, 0x5d, 0, 0, 24, timeout=timeout))
    if len(b) != 24 or b[:4] != b"FWTN":
        raise ValueError("FWTN native-slot firmware NOT detected; no write allowed")
    return struct.unpack("<5I", b[4:])


def read_flash(dev, address, length, timeout):
    b = bytearray()
    while len(b) < length:
        where = address + len(b)
        n = min(32, length - len(b))
        part = bytes(dev.ctrl_transfer(0xc0, 0x5b, where & 0xffff,
                                       where >> 16, n, timeout=timeout))
        if len(part) != n:
            raise RuntimeError("Short SPI read at 0x{:06x}".format(where))
        b.extend(part)
    return bytes(b)


def stream_info(dev, timeout):
    b = bytes(dev.ctrl_transfer(0xc0, 0x59, 0, 0, 20, timeout=timeout))
    if len(b) != 20 or b[:4] != b"STR1":
        raise ValueError("Unexpected DFU stream info")
    return struct.unpack("<IIHBBI", b[4:])


def report_save(path, record):
    tmp = path.with_name(path.name + ".writing")
    # Atomic create-only publication: never overwrite an earlier report.
    with tmp.open("x", encoding="ascii", newline="\n") as fp:
        json.dump(record, fp, sort_keys=True, indent=2)
        fp.write("\n")
        fp.flush()
        os.fsync(fp.fileno())
    try:
        os.link(tmp, path)
    finally:
        tmp.unlink()


def report_update(path, record):
    # Writes to the existing report only after it was created by this run.
    tmp = path.with_name(path.name + ".writing")
    with tmp.open("x", encoding="ascii", newline="\n") as fp:
        json.dump(record, fp, sort_keys=True, indent=2)
        fp.write("\n")
        fp.flush()
        os.fsync(fp.fileno())
    os.replace(tmp, path)


def device_preflight(dev, timeout, backup):
    if status(dev, timeout) != (0, 0, 0, 0, 0):
        raise RuntimeError("Native firmware is not disarmed; reload SRAM, do not retry")
    chip = bytes(dev.ctrl_transfer(0xc0, 0x5a, 0, 0, 8, timeout=timeout))
    if chip != b"A251\x1f\x42\x16\x00":
        raise RuntimeError("Unexpected JEDEC/status: " + chip.hex())
    if stream_info(dev, timeout) != (0, 0, 0, 2, 0, 0x200000):
        raise RuntimeError("DFU stream not idle")
    snapshots = {}
    for addr, label in ((FIRST_STAGE_CHECK, "first_sector"),
                        (META, "metadata"), (NATIVE, "native")):
        snapshots[label] = read_flash(dev, addr, SECTOR, timeout)
    if backup is not None:
        if snapshots["first_sector"] != backup[0:SECTOR] or \
           snapshots["metadata"] != backup[META:NATIVE] or \
           snapshots["native"] != backup[NATIVE:NATIVE + SECTOR]:
            raise RuntimeError("Live flash preflight differs from pinned factory snapshot")
    return snapshots


def program(dev, app, backup, timeout, report_path, record):
    snapshots = device_preflight(dev, timeout, backup)
    if snapshots["native"] != b"\xff" * SECTOR:
        raise RuntimeError("Native target sector is not fully erased")
    crc = zlib.crc32(app) & 0xffffffff
    arm = b"U5WN" + struct.pack("<III", len(app), crc, 0xc01d2041)
    record.update(phase="about_to_arm", target="0x201000", bytes=len(app),
                  payload_crc32="{:08x}".format(crc))
    report_update(report_path, record)
    result = dev.ctrl_transfer(0x40, 0x5c, 1, 0x2000, arm, timeout=timeout)
    if result != 16 or status(dev, timeout) != (1, len(app), crc, 0, 0):
        raise RuntimeError("ARM failure; state unknown; do not retry")
    record["phase"] = "ARMED_FLASH_MAY_BE_PARTIALLY_WRITTEN"
    report_update(report_path, record)
    for offset in range(0, len(app), 64):
        block, part = offset // 64, app[offset:offset + 64]
        written = dev.ctrl_transfer(0x21, 1, block, 0, part, timeout=timeout)
        if written != len(part):
            raise RuntimeError("Short DNLOAD; do not retry")
        dfu = bytes(dev.ctrl_transfer(0xa1, 3, 0, 0, 6, timeout=timeout))
        if len(dfu) != 6 or dfu[0] != 0 or dfu[4] != 5:
            raise RuntimeError("DFU state/error after block {}".format(block))
        done = offset + len(part)
        expected_stream = (done, zlib.crc32(app[:done]) & 0xffffffff,
                           block + 1, 5, 0, 0x200000)
        if stream_info(dev, timeout) != expected_stream or \
           status(dev, timeout) != (1, len(app), crc, done, 0):
            raise RuntimeError("Stream/state mismatch after block {}".format(block))
        record.update(phase="dfu_in_progress", completed_bytes=done)
        report_update(report_path, record)
    dev.ctrl_transfer(0x40, 0x5e, 0x5afe, 0x2026, b"", timeout=timeout)
    if status(dev, timeout) != (2, len(app), crc, len(app), 0):
        raise RuntimeError("Finish/readback failure")
    after = read_flash(dev, NATIVE, SECTOR, timeout)
    if after != app + b"\xff" * (SECTOR - len(app)):
        raise RuntimeError("Independent native-sector USB readback differs")
    for addr, key in ((FIRST_STAGE_CHECK, "first_sector"), (META, "metadata")):
        if read_flash(dev, addr, SECTOR, timeout) != snapshots[key]:
            raise RuntimeError("PROTECTED FLASH CHANGED: " + key)
    record.update(phase="VERIFIED_NATIVE_SECTOR_ONLY", completed_bytes=len(app),
                  app_sha256=APP_SHA)
    report_update(report_path, record)
    print("[PASS] FWTN USB write/readback: 3026 native bytes at 0x201000")
    print("[PASS] First 4KiB of stage0 and U5IM metadata unchanged")
    print("[LIMIT] This did not test native SPI boot or app handoff")


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--app", type=Path, required=True)
    p.add_argument("--backup-a", type=Path)
    p.add_argument("--backup-b", type=Path)
    p.add_argument("--write-test", action="store_true")
    p.add_argument("--confirm-write", default="")
    p.add_argument("--report", type=Path)
    p.add_argument("--timeout-ms", type=int, default=15000)
    a = p.parse_args(argv)
    app = verify_app(a.app)
    if a.timeout_ms < 500:
        p.error("Timeout must be >=500ms")
    if a.write_test:
        if a.confirm_write != ACK or not a.backup_a or not a.backup_b or not a.report:
            p.error("Writes require --backup-a, --backup-b, NEW --report and --confirm-write " + ACK)
        if a.report.exists() or a.report.with_name(a.report.name + ".writing").exists():
            p.error("Refusing to overwrite existing recovery report")
    elif a.confirm_write or a.report:
        p.error("--confirm-write/--report are only valid with --write-test")
    if bool(a.backup_a) != bool(a.backup_b):
        p.error("Provide both factory backups, or neither for read-only probe")
    backup = verify_backups(a.backup_a, a.backup_b) if a.backup_a else None
    if sys.platform != "win32":
        p.error("Physical USB must run in native Windows Python, not WSL")
    import usb.backend.libusb1
    import usb.core
    dll = Path(__file__).resolve().parents[2] / "bin" / "libusb-1.0.dll"
    backend = usb.backend.libusb1.get_backend(find_library=lambda _: str(dll))
    if backend is None:
        p.error("Missing libusb-1.0.dll at " + str(dll))
    dev = usb.core.find(idVendor=VID, idProduct=PID, backend=backend)
    if dev is None:
        p.error("No ULX5M USB device 1D50:614B")
    if not a.write_test:
        snap = device_preflight(dev, a.timeout_ms, backup)
        print("[PASS] FWTN SRAM-only native writer detected (DISARMED)")
        print("[PASS] Read-only candidate sector sha256=" + hashlib.sha256(snap["native"]).hexdigest())
        print("[PASS] No ARM, DFU OUT, JTAG, or flash write")
        return 0
    a.report.parent.mkdir(parents=True, exist_ok=True)
    record = {"phase": "PRE_ARM", "backup_sha256": FACTORY_SHA, "target": "0x201000"}
    report_save(a.report, record)
    try:
        program(dev, app, backup, a.timeout_ms, a.report, record)
    except BaseException as exc:
        record.update(phase="UNVERIFIED_KEEP_BACKUPS_NO_RETRY", error=str(exc))
        report_update(a.report, record)
        print("[CRITICAL] Do not retry a potentially partial USB write; retain backups", file=sys.stderr)
        raise
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print("[FAIL] {}: {}".format(type(exc).__name__, exc), file=sys.stderr)
        sys.exit(1)
