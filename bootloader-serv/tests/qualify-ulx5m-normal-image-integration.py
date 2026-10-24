#!/usr/bin/env python3
"""Read-only ULX5M U5IM integration with the existing C firmware parser.

Creates only temporary host-side flash fixtures. Does not create a flash-ready
image, program hardware, call openFPGALoader, or authorize an application boot.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import zlib

FLASH_BYTES = 0x400000
SECTOR_BYTES = 4096
CANDIDATE_ADDR = 0x200000
PAYLOAD_OFFSET = 256
HEADER_BYTES = 32
MAX_IMAGE_BYTES = 0x200000 - PAYLOAD_OFFSET
FACTORY_SHA256 = "74b3accfa91b04efee753a72b6b9787eb20bfb217266198fefb349ca1cb9509d"
GOLDEN_SHA256 = "8232dd932ff2ea40b2945de6ed1202be5e7dc75960464419cc0ffa95a75901f8"
SIGNATURE = bytes.fromhex("d901ed96")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def u5im_bytes(bit):
    if len(bit) < 16 or len(bit) > MAX_IMAGE_BYTES or not bit.startswith(SIGNATURE):
        raise ValueError("Not a bounded raw GateMate bitstream with known sync")
    header = bytearray(HEADER_BYTES)
    struct.pack_into("<4sIIIII", header, 0, b"U5IM", 1, 1, PAYLOAD_OFFSET,
                     len(bit), zlib.crc32(bit))
    struct.pack_into("<I", header, 24, zlib.crc32(header))
    return bytes(header) + bytes(PAYLOAD_OFFSET - HEADER_BYTES) + bit


def require_factory(path, expected_sha=FACTORY_SHA256):
    data = path.read_bytes()
    if len(data) != FLASH_BYTES or digest(data) != expected_sha:
        raise ValueError("Factory backup size/SHA-256 does not match frozen reference")
    return data


def stage_in_memory(factory, bit):
    """Return a host-only overlay; do not write its bytes to a persistent file."""
    blob = u5im_bytes(bit)
    region_end = CANDIDATE_ADDR + ((len(blob) + SECTOR_BYTES - 1) // SECTOR_BYTES) * SECTOR_BYTES
    if len(factory) != FLASH_BYTES or region_end > FLASH_BYTES:
        raise ValueError("Candidate does not fit within the experimental upper-half window")
    if factory[CANDIDATE_ADDR:region_end] != b"\xff" * (region_end - CANDIDATE_ADDR):
        raise ValueError("Candidate window contains existing flash data; refusing overlay")
    composite = bytearray(factory)
    composite[CANDIDATE_ADDR:CANDIDATE_ADDR + len(blob)] = blob
    return composite, blob, region_end


def build_c_probe(repo_root, output):
    fw = repo_root / "fw"
    tests = repo_root / "tests"
    sources = (fw / "ulx5m_normal_image.c", fw / "ulx5m_flash_layout.c",
               tests / "probe-ulx5m-serv-normal-image.c")
    for path in sources:
        if not path.is_file():
            raise ValueError("Missing existing firmware parser source: " + str(path))
    subprocess.run(["gcc", "-std=c11", "-Wall", "-Wextra", "-Werror", "-O1",
                    "-I", str(fw), "-o", str(output), *(str(p) for p in sources)],
                   check=True, capture_output=True, text=True)


def run_probe(exe, image, expected, label):
    done = subprocess.run([str(exe), str(image), hex(CANDIDATE_ADDR)],
                          capture_output=True, text=True, check=False)
    if done.returncode != expected:
        raise RuntimeError(f"{label}: C probe exited {done.returncode}, expected {expected}: "
                           + done.stdout + done.stderr)
    if expected == 0 and "[INTEGRITY OK]" not in done.stdout:
        raise RuntimeError(f"{label}: probe did not report integrity success: " + done.stdout)
    if expected == 1 and "[REJECT]" not in done.stderr:
        raise RuntimeError(f"{label}: probe did not explicitly reject: " + done.stderr)


def integrate(repo_root, factory, bit, scratch):
    composite, blob, region_end = stage_in_memory(factory, bit)
    exe = scratch / "probe-normal-image"
    build_c_probe(repo_root, exe)
    fixture = scratch / "host-only-flash-fixture.bin"
    fixture.write_bytes(composite)
    run_probe(exe, fixture, 0, "valid image")

    # Verify C parser rejects corrupted payload, header, and truncated source.
    data = bytearray(composite)
    data[CANDIDATE_ADDR + PAYLOAD_OFFSET + len(bit) // 2] ^= 1
    fixture.write_bytes(data)
    run_probe(exe, fixture, 1, "corrupted payload")
    data = bytearray(composite)
    data[CANDIDATE_ADDR + 24] ^= 1
    fixture.write_bytes(data)
    run_probe(exe, fixture, 1, "corrupted header")
    # A missing header is expected absence, not validation success.
    fixture.write_bytes(factory)
    done = subprocess.run([str(exe), str(fixture), hex(CANDIDATE_ADDR)],
                          capture_output=True, text=True, check=False)
    if done.returncode != 0 or "[ABSENT]" not in done.stdout:
        raise RuntimeError("Unmodified backup did not report the candidate absent")
    return {
        "format": "ULX5M U5IM host-only integration v1",
        "factory_sha256": digest(factory),
        "payload_sha256": digest(bit),
        "payload_bytes": len(bit),
        "candidate_address": f"0x{CANDIDATE_ADDR:06x}",
        "configuration_stream_address": f"0x{CANDIDATE_ADDR + PAYLOAD_OFFSET:06x}",
        "candidate_blob_bytes": len(blob),
        "candidate_sector_end_exclusive": f"0x{region_end:06x}",
        "u5im_payload_crc32": f"0x{zlib.crc32(bit):08x}",
        "c_parser_valid": True,
        "c_parser_payload_corruption_rejected": True,
        "c_parser_header_corruption_rejected": True,
        "factory_image_unmodified": True,
        "app_boot_authorized": False,
        "flash_write_authorized": False,
        "persistent_recovery_proven": False,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--factory-backup", required=True, type=Path,
                        help="Exact 4 MiB frozen factory flash-pass1.bin")
    parser.add_argument("--image", required=True, type=Path,
                        help="Raw GateMate normal-application .bit (read only)")
    parser.add_argument("--report", type=Path,
                        help="Optional NEW JSON report (existing files are never overwritten)")
    parser.add_argument("--golden-as-fixture", action="store_true",
                        help="Permit frozen DFU image as a TEST FIXTURE only, not an application")
    args = parser.parse_args()
    if args.report and args.report.exists():
        parser.error("Refusing to overwrite an existing report")
    try:
        factory = require_factory(args.factory_backup)
        bit = args.image.read_bytes()
        if digest(bit) == GOLDEN_SHA256 and not args.golden_as_fixture:
            raise ValueError("Seed-147 DFU is not a normal app; use --golden-as-fixture for test only")
        repo_root = Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory(prefix="ulx5m-u5im-integration-") as temp:
            result = integrate(repo_root, factory, bit, Path(temp))
        result["image_role"] = "golden-test-fixture" if digest(bit) == GOLDEN_SHA256 else "untrusted-candidate"
        if args.report:
            with args.report.open("x", encoding="ascii", newline="\n") as f:
                json.dump(result, f, indent=2, sort_keys=True)
                f.write("\n")
        print("[PASS] Actual C U5IM parser accepts the staged candidate")
        print("[PASS] Actual C parser rejects damaged header and payload")
        print("[PASS] Frozen factory SHA and erased test window verified")
        print("[INFO] Raw stream starts at " + result["configuration_stream_address"])
        print("[BLOCK] No flash write, boot authorization, or persistent recovery approval")
        if args.report:
            print("[REPORT] " + str(args.report))
    except (ValueError, OSError, subprocess.CalledProcessError, RuntimeError) as exc:
        parser.exit(1, "[FAIL] " + str(exc) + "\n")


if __name__ == "__main__":
    main()
