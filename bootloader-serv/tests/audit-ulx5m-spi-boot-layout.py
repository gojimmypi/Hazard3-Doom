#!/usr/bin/env python3
"""Offline-only ULX5M SPI multiboot layout and recovery feasibility gate.

No flash-ready files, GPIO/JTAG operations, or boot authorization are produced.
The actual protected factory-flash layout and BTN2 recovery policy are not proven.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import tempfile
import zlib

PREVIOUS = Path(__file__).with_name("audit-ulx5m-spi-multiboot-commands.py")
SPEC = importlib.util.spec_from_file_location("ulx5m_v34_audit", PREVIOUS)
V34 = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(V34)

FLASH_BYTES = 0x400000
SECTOR_BYTES = 0x1000
HEADER_ADDRESS = 0x200000
LEGACY_PAYLOAD_ADDRESS = 0x200100
NATIVE_PAYLOAD_ADDRESS = 0x201000
NATIVE_OFFSET = NATIVE_PAYLOAD_ADDRESS - HEADER_ADDRESS
NATIVE_SYNC = bytes.fromhex("d901ed96")
REFERENCE_BOOTADDR_SHA256 = "3e5d682e1fd08bf242b9ecc05fd8e3ab9ab95674b759a6039b0a0414066f8c87"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def make_u5im_header(bitstream, payload_offset=NATIVE_OFFSET):
    if not bitstream.startswith(NATIVE_SYNC) or len(bitstream) < 16:
        raise ValueError("candidate does not begin with GateMate CMD_PATH sync")
    if (payload_offset < 256 or payload_offset % 256 or
            HEADER_ADDRESS + payload_offset + len(bitstream) > FLASH_BYTES):
        raise ValueError("candidate payload is not page-aligned or exceeds flash")
    header = bytearray(32)
    struct.pack_into("<4sIIIII", header, 0, b"U5IM", 1, 1,
                     payload_offset, len(bitstream), zlib.crc32(bitstream))
    struct.pack_into("<I", header, 24, zlib.crc32(header))
    return bytes(header)


def check_flash_regions(header_address, payload_address, size, flash_bytes=FLASH_BYTES):
    if header_address % SECTOR_BYTES or payload_address % SECTOR_BYTES:
        raise ValueError("header and SPI jump target must be sector aligned")
    if not 0x200000 <= header_address < payload_address:
        raise ValueError("secondary slot must remain within provisional upper half")
    if header_address + 32 > payload_address:
        raise ValueError("metadata overlaps the configuration stream")
    if not size or size > flash_bytes - payload_address:
        raise ValueError("application exceeds flash or is empty")
    return True


def compare_bootaddr_commands(at_two_megs, at_payload, target=NATIVE_PAYLOAD_ADDRESS):
    """Require all gmpack changes to be limited to the jump record."""
    if len(at_two_megs) != len(at_payload):
        raise ValueError("changing boot address changed total stream length")
    baseline = [(c, int(c["offset"], 16)) for c in V34.find_commands(at_two_megs)
                if c["command"] == "CMD_JUMP" and c["bytes"] == 4]
    candidate = [(c, int(c["offset"], 16)) for c in V34.find_commands(at_payload)
                 if c["command"] == "CMD_JUMP" and c["bytes"] == 4]
    if len(baseline) != 1 or len(candidate) != 1:
        raise ValueError("expected exactly one CRC-verified CMD_JUMP in each variant")
    old, old_pos = baseline[0]
    new, new_pos = candidate[0]
    if old_pos != new_pos or old["target_le"] != "0x00200000":
        raise ValueError("reference jump or command location is unexpected")
    if new["target_le"] != "0x%08x" % target:
        raise ValueError("jump target does not equal native configuration address")
    old_size = 6 + old["bytes"]
    new_size = 6 + new["bytes"]
    if old_size != new_size:
        raise ValueError("jump record length changed")
    if (at_two_megs[:old_pos] != at_payload[:new_pos] or
            at_two_megs[old_pos + old_size:] != at_payload[new_pos + new_size:]):
        raise ValueError("gmpack changed bytes outside the CMD_JUMP record")
    reset_before = [c for c in V34.find_commands(at_payload)
                    if c["command"] == "CMD_CFGRST" and
                    int(c["offset"], 16) < new_pos]
    if len(reset_before) != 1:
        raise ValueError("expected CRC-valid CMD_CFGRST before jump")
    return {"target": "0x%06x" % target, "jump_offset": "0x%x" % new_pos,
            "reset_offset": reset_before[0]["offset"], "stream_bytes": len(at_payload),
            "stream_sha256": digest(at_payload)}


def check_firmware_policy(root):
    """Check current source assumptions; never silently approve firmware changes."""
    fw = root / "fw"
    path = fw / "ulx5m_normal_boot.c"
    header = fw / "ulx5m_normal_boot.h"
    layout = fw / "ulx5m_flash_layout.c"
    image = fw / "ulx5m_normal_image.c"
    probe = root / "tests" / "probe-ulx5m-serv-normal-image.c"
    for p in (path, header, layout, image, probe):
        if not p.is_file():
            raise ValueError("missing existing firmware/parser source: " + str(p))
    boot = path.read_text(encoding="ascii")
    slot = header.read_text(encoding="ascii")
    guard = layout.read_text(encoding="ascii")
    if "ULX5M_NORMAL_BOOT_SLOT 0x00200000u" not in slot:
        raise ValueError("unexpected candidate slot in firmware")
    if "info.payload_address != ULX5M_NORMAL_BOOT_SLOT + 256u" not in boot:
        raise ValueError("normal-boot payload-address guard changed: requalify manually")
    if "return ULX5M_FLASH_WRITE_PROTECTED;" not in guard:
        raise ValueError("flash-write protection is not as expected")
    return {"u5im_parser": "supports native 0x1000 offset (subject to host test)",
            "existing_normal_boot": "requires 0x100 offset; INCOMPATIBLE",
            "writes_enabled": False}


def memory_fixture(bitstream):
    """Synthetic erased 4 MiB flash for the host parser; never program hardware."""
    check_flash_regions(HEADER_ADDRESS, NATIVE_PAYLOAD_ADDRESS, len(bitstream))
    memory = bytearray(b"\xff" * FLASH_BYTES)
    memory[HEADER_ADDRESS:HEADER_ADDRESS + 32] = make_u5im_header(bitstream)
    memory[NATIVE_PAYLOAD_ADDRESS:NATIVE_PAYLOAD_ADDRESS + len(bitstream)] = bitstream
    if memory[HEADER_ADDRESS:HEADER_ADDRESS + 4] != b"U5IM":
        raise AssertionError("bad U5IM header")
    if memory[NATIVE_PAYLOAD_ADDRESS:NATIVE_PAYLOAD_ADDRESS + 4] != NATIVE_SYNC:
        raise AssertionError("bad native configuration sync")
    if memory[LEGACY_PAYLOAD_ADDRESS:LEGACY_PAYLOAD_ADDRESS + 4] == NATIVE_SYNC:
        raise AssertionError("legacy address unexpectedly contains native sync")
    return memory


def run_c_probe(root, bitstream):
    """Build and call existing C firmware U5IM parser, using temp-only fixtures."""
    with tempfile.TemporaryDirectory(prefix="ulx5m-v35-host-only-") as d:
        out = Path(d)
        fw = root / "fw"
        sources = [fw / "ulx5m_normal_image.c", fw / "ulx5m_flash_layout.c",
                   root / "tests" / "probe-ulx5m-serv-normal-image.c"]
        subprocess.run(["gcc", "-std=c11", "-Wall", "-Wextra", "-Werror", "-O1",
                        "-I", str(fw), "-o", str(out / "probe"),
                        *[str(x) for x in sources]], check=True,
                       capture_output=True, text=True)
        flash = memory_fixture(bitstream)
        staged = out / "synthetic-flash.bin"
        def probe(candidate, expected, text):
            staged.write_bytes(candidate)
            result = subprocess.run([str(out / "probe"), str(staged),
                                     hex(HEADER_ADDRESS)], capture_output=True, text=True)
            if result.returncode != expected or text not in result.stdout + result.stderr:
                raise RuntimeError("C U5IM parser did not yield %s: %s %s" %
                                   (text, result.stdout, result.stderr))
        probe(flash, 0, "[INTEGRITY OK]")
        bad = bytearray(flash)
        bad[NATIVE_PAYLOAD_ADDRESS + len(bitstream) // 2] ^= 1
        probe(bad, 1, "[REJECT]")
        bad = bytearray(flash)
        bad[HEADER_ADDRESS + 24] ^= 1
        probe(bad, 1, "[REJECT]")
        probe(b"\xff" * FLASH_BYTES, 0, "[ABSENT]")
    return True


def pack_variants(implementation, reference, packer="gmpack", runner=None):
    if runner is None:
        runner = subprocess.run
    with tempfile.TemporaryDirectory(prefix="ulx5m-v35-packer-only-") as d:
        variants = {}
        for name, flags in (
                ("default", []),
                ("legacy", ["--bootaddr", str(HEADER_ADDRESS)]),
                ("native", ["--bootaddr", str(NATIVE_PAYLOAD_ADDRESS)])):
            output = Path(d) / (name + ".bit")
            result = runner([packer, *flags, str(implementation), str(output)],
                            capture_output=True, text=True, check=False)
            if result.returncode or not output.exists():
                raise RuntimeError("gmpack %s failed: %s" % (name, result.stderr))
            variants[name] = output.read_bytes()
        if variants["default"] != reference:
            raise ValueError("default packer output differs from hardware-verified image")
        if digest(variants["legacy"]) != REFERENCE_BOOTADDR_SHA256:
            raise ValueError("legacy --bootaddr image does not match the v34 tested output")
        return compare_bootaddr_commands(variants["legacy"], variants["native"])


def perform(bit_path, impl_path, root, packer="gmpack", runner=None, c_probe=True):
    bit = V34.verify_inputs(bit_path, impl_path)
    firmware = check_firmware_policy(root)
    check_flash_regions(HEADER_ADDRESS, NATIVE_PAYLOAD_ADDRESS, len(bit))
    command = pack_variants(impl_path, bit, packer=packer, runner=runner)
    if c_probe:
        run_c_probe(root, bit)
    return {
        "audit_passed": True,
        "flash_bytes": FLASH_BYTES,
        "erase_sector_bytes": SECTOR_BYTES,
        "metadata_address": "0x%06x" % HEADER_ADDRESS,
        "native_image_address": "0x%06x" % NATIVE_PAYLOAD_ADDRESS,
        "legacy_payload_address": "0x%06x" % LEGACY_PAYLOAD_ADDRESS,
        "image_bytes": len(bit),
        "image_sha256": digest(bit),
        "crc32": "0x%08x" % zlib.crc32(bit),
        "command": command,
        "firmware": firmware,
        "btn2_recovery_selector_proven": False,
        "independent_recovery_after_corrupt_image_proven": False,
        "native_spi_boot_verified_on_hardware": False,
        "flash_write_authorized": False,
        "persistent_boot_authorized": False,
        "result": "BLOCKED: layout is coherent offline, boot selection and recovery unproven"
    }


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--bit", type=Path, required=True)
    p.add_argument("--implementation", type=Path, required=True)
    p.add_argument("--packer", default="gmpack")
    p.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[1])
    args = p.parse_args(argv)
    try:
        report = perform(args.bit, args.implementation, args.repo_root, args.packer)
    except (ValueError, RuntimeError, OSError, subprocess.CalledProcessError) as exc:
        p.exit(1, "[FAIL] %s\n" % exc)
    print("[PASS] Pinned JTAG-working bitstream and source, default gmpack reproduction")
    print("[PASS] CMD_CFGRST and CRC-valid CMD_JUMP target 0x201000")
    print("[PASS] Only the address/CRC of the jump command changed from v34")
    print("[PASS] In-memory U5IM at 0x200000, raw GateMate image at 0x201000")
    print("[PASS] Real C U5IM parser accepts candidate and rejects bad header/payload")
    print("[BLOCK] Existing normal_boot_run requires 0x200100, not 0x201000")
    print("[BLOCK] Unconditional SPI jump cannot preserve BTN2 startup selection")
    print("[BLOCK] Independent recovery from corrupt secondary image not established")
    print("[BLOCK] No authorized hardware boot, flash writes, JTAG, USB, or FPGA operation")
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
