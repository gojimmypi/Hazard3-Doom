#!/usr/bin/env python3
"""Read-only ULX5M-GS v45 flash evidence and recovery qualification.

This tool cannot authorize configuration, erase, write, or reconfiguration.
It contains no USB, JTAG, GPIO, or subprocess interfaces. Passing its byte
checks is independent of establishing a persistent/recoverable bootloader.
"""

import argparse
import hashlib
import json
from pathlib import Path
import sys

FLASH_BYTES = 0x400000
SECTOR_BYTES = 0x1000
APP_ADDR = 0x201000
APP_BYTES = 3026
PROTECTED_METADATA_ADDR = 0x200000
PROTECTED_STAGE0_ADDR = 0x000000

FACTORY_SHA256 = "74b3accfa91b04efee753a72b6b9787eb20bfb217266198fefb349ca1cb9509d"
APP_SHA256 = "68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd"
SECTOR_SHA256 = "28b1e5cbfa45a319600ec38c81207a36d9889c3179e8055f5a663c616ef97bee"


def sha256(blob):
    return hashlib.sha256(blob).hexdigest()


def expected_app_sector(image):
    if len(image) != APP_BYTES or sha256(image) != APP_SHA256:
        raise ValueError("application does not match the pinned 3026-byte v41 image")
    return image + b"\xff" * (SECTOR_BYTES - APP_BYTES)


def read_pinned(path, expected_length, expected_sha, label):
    blob = Path(path).read_bytes()
    if len(blob) != expected_length:
        raise ValueError("%s: size %d, expected %d" % (label, len(blob), expected_length))
    if sha256(blob) != expected_sha:
        raise ValueError("%s: SHA-256 differs from pinned checkpoint" % label)
    return blob


def differing_sectors(reference, observed, allowed_start=APP_ADDR,
                      allowed_length=SECTOR_BYTES):
    """Report modifications, excluding one explicitly permitted app sector.

    Fail closed on geometry errors. A range check against both full images
    avoids accidentally accepting a truncated dump or a shifted read.
    """
    if len(reference) != FLASH_BYTES or len(observed) != FLASH_BYTES:
        raise ValueError("full flash comparison requires exactly 4 MiB per input")
    if allowed_start != APP_ADDR or allowed_length != SECTOR_BYTES:
        raise ValueError("only the pinned application sector is permitted to differ")
    return [address for address in range(0, FLASH_BYTES, SECTOR_BYTES)
            if address != APP_ADDR and
            reference[address:address + SECTOR_BYTES] !=
            observed[address:address + SECTOR_BYTES]]


def recovery_policy(*, btn2_latched, stage0_installed, stage0_protected,
                    independent_recovery, image_verified, handoff_supported,
                    failure_detection_and_rollback, attempts_remaining):
    """Pure hypothetical policy model, NOT an on-device implementation.

    In particular, a passing policy-model result is not an authorization to
    set up or try a live hardware handoff. Never infer any gate from an LED.
    """
    if not independent_recovery:
        return "BLOCK_NO_INDEPENDENT_RECOVERY"
    if not stage0_installed or not stage0_protected:
        return "BLOCK_NO_PROTECTED_STAGE0"
    if btn2_latched:
        return "STAY_DFU_BTN2"
    if not image_verified:
        return "STAY_DFU_INVALID_IMAGE"
    if not handoff_supported:
        return "STAY_DFU_UNSUPPORTED_HANDOFF"
    if not failure_detection_and_rollback:
        return "STAY_DFU_NO_ROLLBACK"
    if not attempts_remaining:
        return "STAY_DFU_ATTEMPTS_EXHAUSTED"
    return "MODEL_ELIGIBLE_ONLY_NO_HARDWARE_AUTHORIZATION"


def audit(factory_pass1=None, factory_pass2=None, app_bit=None,
          sector_dump=None, flash_snapshot=None):
    """Validate user-provided, existing files; never create deployment data."""
    report = {
        "result": "BLOCKED_NO_PERSISTENT_BOOT_AUTHORIZATION",
        "evidence": {},
        "protection": {
            "flash_zero_stage0_installed": False,
            "flash_zero_stage0_protected": False,
            "btn2_preconfiguration_recovery": False,
            "independent_recovery_after_bad_stage0_qualified": False,
            "gateware_full_reconfiguration_handoff_qualified": False,
            "autonomous_rollback_qualified": False,
            "flash_write_authorized": False,
            "jtag_configuration_authorized": False,
            "cc_cfg_ctrl_stream_authorized": False,
        },
        "errors": [],
    }

    def record(name, value):
        report["evidence"][name] = value

    def error(name, message):
        report["errors"].append("%s: %s" % (name, message))
        record(name, "FAIL")

    image = None
    expected_sector = None
    if app_bit is not None:
        try:
            image = read_pinned(app_bit, APP_BYTES, APP_SHA256, "application")
            expected_sector = expected_app_sector(image)
            record("app_image", "PASS_PINNED_V41_3026_BYTES")
        except (OSError, ValueError) as exc:
            error("app_image", str(exc))
    else:
        record("app_image", "MISSING")

    baseline = None
    if (factory_pass1 is None) != (factory_pass2 is None):
        error("factory_dual_backup", "both independent backups must be supplied together")
    elif factory_pass1 is None:
        record("factory_dual_backup", "MISSING")
    else:
        try:
            first = read_pinned(factory_pass1, FLASH_BYTES, FACTORY_SHA256, "factory_pass1")
            second = read_pinned(factory_pass2, FLASH_BYTES, FACTORY_SHA256, "factory_pass2")
            if first != second:
                raise ValueError("factory backups differ")
            baseline = first
            record("factory_dual_backup", "PASS_TWO_IDENTICAL_PINNED_BACKUPS")
        except (OSError, ValueError) as exc:
            error("factory_dual_backup", str(exc))

    if sector_dump is not None:
        if expected_sector is None:
            error("independent_sector", "pinned app image required for cross-check")
        else:
            try:
                sector = read_pinned(sector_dump, SECTOR_BYTES, SECTOR_SHA256,
                                     "independent_sector")
                if sector != expected_sector:
                    raise ValueError("4096-byte sector differs from pinned app plus erased tail")
                record("independent_sector", "PASS_EXACT_4096_BYTES")
            except (OSError, ValueError) as exc:
                error("independent_sector", str(exc))
    else:
        record("independent_sector", "MISSING")

    if flash_snapshot is not None:
        if baseline is None or expected_sector is None:
            error("current_flash_snapshot", "both factory backups and pinned app required")
        else:
            try:
                observed = Path(flash_snapshot).read_bytes()
                changed = differing_sectors(baseline, observed)
                if changed:
                    short = ", ".join("0x%06x" % addr for addr in changed[:8])
                    raise ValueError("unexpected changed erase sectors: " + short +
                                     (" ..." if len(changed) > 8 else ""))
                if observed[APP_ADDR:APP_ADDR + SECTOR_BYTES] != expected_sector:
                    raise ValueError("current application sector does not match pinned v41 bytes")
                record("current_flash_snapshot", "PASS_ONLY_EXPECTED_APP_SECTOR_DIFFERS")
            except (OSError, ValueError) as exc:
                error("current_flash_snapshot", str(exc))
    else:
        record("current_flash_snapshot", "NOT_PROVIDED_NO_CURRENT_FLASH_CLAIM")

    required = ("factory_dual_backup", "app_image", "independent_sector")
    has_complete_evidence = all(report["evidence"][name].startswith("PASS")
                                for name in required)
    if report["errors"]:
        report["evidence_status"] = "FAIL"
    elif has_complete_evidence:
        report["evidence_status"] = "PINNED_OFFLINE_EVIDENCE_PASS"
    else:
        report["evidence_status"] = "INCOMPLETE"

    # Deliberately never assign deployment-ready regardless of offline inputs.
    report["result"] = "EVIDENCE_%s_DEPLOYMENT_BLOCKED" % report["evidence_status"]
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--factory-pass1", type=Path)
    parser.add_argument("--factory-pass2", type=Path)
    parser.add_argument("--app-bit", type=Path)
    parser.add_argument("--sector-dump", type=Path)
    parser.add_argument("--flash-snapshot", type=Path)
    args = parser.parse_args(argv)
    result = audit(**vars(args))
    print(json.dumps(result, indent=2, sort_keys=True))
    if result["evidence_status"] == "PINNED_OFFLINE_EVIDENCE_PASS":
        return 0
    return 1 if result["evidence_status"] == "FAIL" else 2


if __name__ == "__main__":
    sys.exit(main())
