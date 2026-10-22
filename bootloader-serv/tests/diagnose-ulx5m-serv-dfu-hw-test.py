#!/usr/bin/env python3
"""Native Windows probe for isolated ULX5M 4 KiB DFU flash-write experiment.

Default is READ ONLY. --write-test is destructive at 0x200000 and intentionally
LEAVES the first 4 KiB candidate sector programmed. Restore with the separate
JTAG candidate restorer after powering the ULX5M off/on (Tigard stays powered).
NEVER test against the normal discard-only dfu-stream-serv image.
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
CANDIDATE = 0x200000
FACTORY_SHA = "74b3accfa91b04efee753a72b6b9787eb20bfb217266198fefb349ca1cb9509d"
ACK = "I_ACCEPT_200000_USB_FLASH_WRITE_RISK"


def verified_backup(directory):
    a = (directory / "flash-pass1.bin").read_bytes()
    b = (directory / "flash-pass2.bin").read_bytes()
    if len(a) != 0x400000 or a != b or hashlib.sha256(a).hexdigest() != FACTORY_SHA:
        raise ValueError("Factory flash backup does not match the two verified copies")
    if a[CANDIDATE:CANDIDATE + 4096] != b"\xff" * 4096:
        raise ValueError("Candidate sector is not erased in factory reference")
    return a


def read_status(dev, timeout):
    raw = bytes(dev.ctrl_transfer(0xc0, 0x5d, 0, 0, 24, timeout=timeout))
    if len(raw) != 24 or raw[:4] != b"FWT1":
        raise ValueError("Experimental FWT1 firmware not detected (DO NOT WRITE)")
    return struct.unpack("<5I", raw[4:])


def read_flash(dev, offset, count, timeout):
    result = bytearray()
    while len(result) < count:
        where = offset + len(result)
        size = min(32, count - len(result))
        chunk = bytes(dev.ctrl_transfer(0xc0, 0x5b, where & 0xffff,
                                        where >> 16, size, timeout=timeout))
        if len(chunk) != size:
            raise ValueError("Short flash read at 0x{:06x}".format(where))
        result.extend(chunk)
    return bytes(result)


def payload():
    return bytes(((i * 37 + 0x5a) & 0xff) for i in range(64))


def save_report(path, data):
    temporary = path.with_name(path.name + ".writing")
    with temporary.open("w", encoding="ascii", newline="\n") as file:
        json.dump(data, file, indent=2, sort_keys=True)
        file.write("\n")
        file.flush()
        os.fsync(file.fileno())
    os.replace(temporary, path)


def write_first_block(dev, backup, timeout, report=None, report_path=None):
    if read_status(dev, timeout) != (0, 0, 0, 0, 0):
        raise RuntimeError("FWT1 is not disarmed and idle")
    state = bytes(dev.ctrl_transfer(0xc0, 0x5a, 0, 0, 8, timeout=timeout))
    if state != b"A251\x1f\x42\x16\x00":
        raise RuntimeError("Unexpected flash JEDEC/status: {}".format(state.hex()))
    before = read_flash(dev, CANDIDATE, 4096, timeout)
    if before != backup[CANDIDATE:CANDIDATE + 4096]:
        raise RuntimeError("Candidate sector does not match erased factory reference")
    raw = bytes(dev.ctrl_transfer(0xc0, 0x59, 0, 0, 20, timeout=timeout))
    expected = b"STR1" + b"\0" * 10 + bytes([2, 0]) + struct.pack("<I", 0x200000)
    if raw != expected:
        raise RuntimeError("DFU receiver is not empty: {}".format(raw.hex()))
    data = payload()
    crc = zlib.crc32(data) & 0xffffffff
    arm = b"U5W1" + struct.pack("<III", len(data), crc, 0xc01d2026)
    print("[ARM] 64 bytes, CRC32={:08x}, target=0x200000".format(crc), flush=True)
    if report is not None:
        report["phase"] = "about_to_arm"
        report["payload_crc32"] = "{:08x}".format(crc)
        save_report(report_path, report)
    wrote = dev.ctrl_transfer(0x40, 0x5c, 1, 0x2000, arm, timeout=timeout)
    if wrote != len(arm) or read_status(dev, timeout)[:3] != (1, len(data), crc):
        raise RuntimeError("Arm did not complete; STOP")
    if report is not None:
        report["phase"] = "armed_flash_may_change"
        save_report(report_path, report)
    wrote = dev.ctrl_transfer(0x21, 1, 0, 0, data, timeout=timeout)
    if wrote != len(data):
        raise RuntimeError("Short DFU OUT; do not retry")
    dfu = bytes(dev.ctrl_transfer(0xa1, 3, 0, 0, 6, timeout=timeout))
    if len(dfu) != 6 or dfu[0] or dfu[4] != 5:
        raise RuntimeError("DFU status mismatch: {}".format(dfu.hex()))
    got = read_status(dev, timeout)
    if got != (1, len(data), crc, len(data), 0):
        raise RuntimeError("FWT1 receiver mismatch: {}".format(got))
    if report is not None:
        report["phase"] = "dfu_block_accepted"
        save_report(report_path, report)
    print("[FINISH] Trigger page flush, sector erase, readback CRC", flush=True)
    if report is not None:
        report["phase"] = "about_to_erase_and_program"
        save_report(report_path, report)
    dev.ctrl_transfer(0x40, 0x5e, 0x5afe, 0x2026, b"", timeout=timeout)
    got = read_status(dev, timeout)
    if got != (2, len(data), crc, len(data), 0):
        raise RuntimeError("Hardware flash finish FAILED: {}".format(got))
    actual = read_flash(dev, CANDIDATE, 4096, timeout)
    if actual != data + b"\xff" * (4096 - len(data)):
        raise RuntimeError("Candidate flash verification failed")
    if report is not None:
        report["phase"] = "usb_candidate_verified_restore_required"
        save_report(report_path, report)
    print("[PASS] USB wrote and verified 64 bytes at 0x200000; factory boot region not targeted")
    print("[ACTION] Restore candidate 4 KiB via JTAG after power-cycling ULX5M only")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--backup-dir", type=Path)
    p.add_argument("--write-test", action="store_true")
    p.add_argument("--report", type=Path,
                   help="Required NEW JSON report for any physical write")
    p.add_argument("--confirm-write", default="")
    p.add_argument("--timeout-ms", type=int, default=15000)
    args = p.parse_args()
    if sys.platform != "win32":
        p.error("Hardware USB must run with native Windows Python, not WSL")
    if args.timeout_ms < 500:
        p.error("Timeout must be >=500 ms")
    if args.write_test and (args.confirm_write != ACK or not args.backup_dir or not args.report):
        p.error("--write-test requires --backup-dir, NEW --report, and --confirm-write " + ACK)
    if not args.write_test and args.confirm_write:
        p.error("Write acknowledgment without --write-test")
    backup = verified_backup(args.backup_dir) if args.backup_dir else None
    if args.write_test and (args.report.exists() or
                            args.report.with_name(args.report.name + ".writing").exists()):
        p.error("Report already exists; refusing overwrite")
    import usb.backend.libusb1
    import usb.core
    dll = Path(__file__).resolve().parents[2] / "bin" / "libusb-1.0.dll"
    backend = usb.backend.libusb1.get_backend(find_library=lambda _: str(dll))
    if backend is None:
        p.error("Missing Windows libusb backend: " + str(dll))
    dev = usb.core.find(idVendor=VID, idProduct=PID, backend=backend)
    if dev is None:
        p.error("ULX5M 1D50:614B not enumerated")
    status = read_status(dev, args.timeout_ms)
    print("[FWT1] phase={} image={} crc={:08x} received={} error={}".format(
        status[0], status[1], status[2], status[3], status[4]))
    if not args.write_test:
        print("[PASS] Read-only FWT1 probe; no flash writes")
        return 0
    record = {"format": "ULX5M-DFU-PHYSICAL-4K-V1", "target": CANDIDATE,
              "maximum_writable_bytes": 4096, "backup_sha256": FACTORY_SHA,
              "phase": "preflight_pending", "restoration": "required"}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    save_report(args.report, record)
    try:
        write_first_block(dev, backup, args.timeout_ms, record, args.report)
    except BaseException as exc:
        record["phase"] = "UNVERIFIED_KEEP_BACKUPS"
        record["error"] = str(exc)
        save_report(args.report, record)
        print("[CRITICAL] If ARM was issued, candidate flash state may be partial.",
              file=sys.stderr)
        print("[CRITICAL] Do not retry USB writing; use JTAG recovery.", file=sys.stderr)
        raise
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print("[FAIL] {}: {}".format(type(exc).__name__, exc), file=sys.stderr)
        sys.exit(1)
