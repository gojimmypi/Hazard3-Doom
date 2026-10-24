#!/usr/bin/env python3
"""Offline-only plan for a diagnostic BTN2 FWT3 image at flash address zero.

Never communicates with hardware or produces a flash-programming image.
The report is a candidate transition plan, not authorization for a write.
"""
import argparse
import hashlib
import json
from pathlib import Path

FLASH_SIZE = 0x400000
SECTOR = 0x1000
PAGE = 0x100
APP_META = 0x200000
APP_NATIVE = 0x201000
FACTORY_HASH = "74b3accfa91b04efee753a72b6b9787eb20bfb217266198fefb349ca1cb9509d"
DFU_HASH = "8232dd932ff2ea40b2945de6ed1202be5e7dc75960464419cc0ffa95a75901f8"
DFU_LENGTH = 414867
SYNC = bytes.fromhex("d901ed96")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def checked_file(path, expected_len, expected_hash, label):
    data = Path(path).read_bytes()
    if len(data) != expected_len or digest(data) != expected_hash:
        raise ValueError("%s length/SHA-256 mismatch" % label)
    return data


def plan_stage0(factory, dfu):
    if len(factory) != FLASH_SIZE:
        raise ValueError("factory must be exactly 4 MiB")
    if len(dfu) != DFU_LENGTH or digest(dfu) != DFU_HASH:
        raise ValueError("DFU image fails pinned identity check")
    if not dfu.startswith(SYNC):
        raise ValueError("DFU GateMate sync missing")
    if factory[APP_META:APP_META + SECTOR] != b"\xff" * SECTOR:
        raise ValueError("candidate metadata sector is not erased in snapshot")
    if factory[APP_NATIVE:APP_NATIVE + SECTOR] != b"\xff" * SECTOR:
        raise ValueError("candidate native sector is not erased in snapshot")

    candidate = bytearray(factory)
    candidate[:len(dfu)] = dfu
    last_sector_end = ((len(dfu) + SECTOR - 1) // SECTOR) * SECTOR
    if candidate[len(dfu):] != factory[len(dfu):]:
        raise AssertionError("overlay changed bytes outside the DFU image")
    if candidate[APP_META:] != factory[APP_META:]:
        raise AssertionError("overlay changed second half of flash")

    changed_sectors = []
    non_ff_pages = 0
    for offset in range(0, last_sector_end, SECTOR):
        before = factory[offset:offset + SECTOR]
        after = candidate[offset:offset + SECTOR]
        if before == after:
            continue
        must_erase = any((new & ~old) != 0 for old, new in zip(before, after))
        non_ff_candidate_pages = sum(
            after[p:p + PAGE] != b"\xff" * PAGE
            for p in range(0, SECTOR, PAGE)
        )
        non_ff_pages += non_ff_candidate_pages
        changed_sectors.append({
            "sector_offset": "0x%06x" % offset,
            "erase_required": must_erase,
            "non_ff_candidate_pages": non_ff_candidate_pages,
            "before_sha256": digest(before),
            "after_sha256": digest(after),
        })
    if not changed_sectors:
        raise ValueError("factory already equals candidate; unexpected source image")
    return {
        "result": "CANDIDATE_ONLY - NOT AUTHORIZED FOR HARDWARE PROGRAMMING",
        "flash_bytes": FLASH_SIZE,
        "factory_sha256": digest(factory),
        "dfu_bitstream": {"bytes": len(dfu), "sha256": digest(dfu),
                           "flash_start": "0x000000", "flash_last_byte": "0x%06x" % (len(dfu) - 1)},
        "candidate_full_flash_sha256": digest(candidate),
        "first_stage_sectors_spanned": last_sector_end // SECTOR,
        "changed_sectors": len(changed_sectors),
        "sectors_requiring_erase": sum(x["erase_required"] for x in changed_sectors),
        "non_ff_candidate_pages_in_changed_sectors": non_ff_pages,
        "last_sector_suffix_bytes_preserved": last_sector_end - len(dfu),
        "candidate_metadata_and_native_sectors_unchanged": True,
        "all_bytes_after_dfu_payload_unchanged": True,
        "change_plan": changed_sectors,
        "image_role": "FWT3/BTN2 test firmware, not a production DFU bootloader",
        "deployable_bootloader": False,
        "hardware_spi_boot_tested": False,
        "stage0_persistent": False,
        "flash_write_protection_verified": False,
        "normal_application_boot_supported": False,
        "jtag_recovery_after_stage0_replacement_tested": False,
        "write_authorized": False,
    }


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--factory-backup", type=Path, required=True)
    p.add_argument("--second-backup", type=Path)
    p.add_argument("--dfu-bit", type=Path, required=True)
    p.add_argument("--report", type=Path, help="create-only JSON report (optional)")
    args = p.parse_args()
    factory = checked_file(args.factory_backup, FLASH_SIZE, FACTORY_HASH, "factory backup")
    if args.second_backup:
        other = checked_file(args.second_backup, FLASH_SIZE, FACTORY_HASH, "second backup")
        if other != factory:
            raise ValueError("two independently supplied backups differ")
    dfu = checked_file(args.dfu_bit, DFU_LENGTH, DFU_HASH, "BTN2 DFU image")
    report = plan_stage0(factory, dfu)
    # Do not silently overwrite reports; do not produce any flashable image.
    if args.report:
        fd = args.report.open("x", encoding="utf-8", newline="\n")
        with fd:
            json.dump(report, fd, indent=2, sort_keys=True)
            fd.write("\n")
    print("[PASS] Exact factory snapshot and hardware-tested BTN2 DFU image verified")
    print("[PASS] Plan touches only flash address zero through DFU image end")
    print("[PASS] Candidate U5IM/normal-image sectors remain unchanged")
    print("[OBSERVED] %d of %d overlapping sectors differ; %d require erase" % (
        report["changed_sectors"], report["first_stage_sectors_spanned"],
        report["sectors_requiring_erase"]))
    print("[BLOCK] FWT3 test firmware is NOT a production persistent DFU bootloader")
    print("[BLOCK] Flash-zero replacement, cold SPI boot, BTN2 recovery and rollback unproven")
    print("[BLOCK] Read-only planner; no output binary, JTAG, USB, or flash write")
    print(json.dumps({k: v for k, v in report.items() if k != "change_plan"}, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
