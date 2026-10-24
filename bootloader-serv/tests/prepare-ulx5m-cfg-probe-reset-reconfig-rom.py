#!/usr/bin/env python3
"""Prepare a pinned reset+reconfig GateMate ROM. No hardware operations.

This deliberately changes only the destination; the source probe still uses
its original CC_CFG_CTRL RECFG=1. It is NOT proof of safe live configuration.
"""
import argparse
import hashlib
from pathlib import Path
import subprocess
import sys
import tempfile

DEFAULT_SHA256 = "68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd"
VARIANT_SHA256 = "f506bf1883e9998b30c5374d6e5e7fa60473b192deaf6327ce8ca92bc13c9a6e"
DEFAULT_LEN = 3026
VARIANT_LEN = 3033
RESET_OFFSET = 16
RESET_COMMAND = bytes.fromhex("c3010cfe00ccc6")
STATUS_OFFSET = 0xBBB
OLD_STATUS = bytes.fromhex("131f002000000000000000006ca1")
NEW_STATUS = bytes.fromhex("1b1f0020000000000000000080ab")


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def expected_variant(original):
    if len(original) != DEFAULT_LEN or sha256(original) != DEFAULT_SHA256:
        raise ValueError("default image must match the JTAG-validated SHA-256")
    if not original.startswith(bytes.fromhex("d901ed96")):
        raise ValueError("unexpected configuration stream start")
    if original[STATUS_OFFSET:STATUS_OFFSET+len(OLD_STATUS)] != OLD_STATUS:
        raise ValueError("unexpected terminal status command")
    result = (original[:RESET_OFFSET] + RESET_COMMAND
              + original[RESET_OFFSET:STATUS_OFFSET] + NEW_STATUS
              + original[STATUS_OFFSET+len(OLD_STATUS):])
    if len(result) != VARIANT_LEN or sha256(result) != VARIANT_SHA256:
        raise ValueError("pinned reset/reconfig image expectation mismatch")
    return result


def publish_create_only(outputs):
    if len({str(p.resolve()) for p, _ in outputs}) != len(outputs):
        raise ValueError("ROM and destination paths must be distinct")
    for path, data in outputs:
        if path.exists() and path.read_bytes() != data:
            raise ValueError("refusing to replace differing output: " + str(path))
    for path, data in outputs:
        if not path.exists():
            path.parent.mkdir(parents=True, exist_ok=True)
            with path.open("xb") as fh:
                fh.write(data)


def prepare(image, implementation, rom, bit, runner=subprocess.run):
    original = image.read_bytes()
    expected = expected_variant(original)
    if not implementation.is_file():
        raise ValueError("missing nextpnr implementation")
    with tempfile.TemporaryDirectory(prefix="ulx5m-reset-reconfig-") as folder:
        plain = Path(folder) / "plain.bit"
        variant = Path(folder) / "reset-reconfig.bit"
        for args in (("gmpack", str(implementation), str(plain)),
                     ("gmpack", "--reset", "--reconfig", str(implementation), str(variant))):
            result = runner(list(args), capture_output=True, text=True, check=False)
            if result.returncode:
                raise ValueError("gmpack failed: " + (result.stderr or result.stdout or "unknown").strip())
        if plain.read_bytes() != original:
            raise ValueError("gmpack default does not reproduce known JTAG-working image")
        if variant.read_bytes() != expected:
            raise ValueError("gmpack reset/reconfig differs outside the pinned command windows")
    rom_bytes = "".join("{:02x}\n".format(x) for x in expected).encode("ascii")
    publish_create_only([(rom, rom_bytes), (bit, expected)])
    return sha256(expected)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ("image", "implementation", "rom", "bit"):
        p.add_argument("--" + name, required=True, type=Path)
    args = p.parse_args()
    try:
        digest = prepare(args.image, args.implementation, args.rom, args.bit)
    except (OSError, ValueError, subprocess.SubprocessError) as exc:
        print("[FAIL] " + str(exc), file=sys.stderr)
        return 1
    print("[PASS] Exact default gmpack output matches hardware-tested image")
    print("[PASS] Reset command added at offset 0x10 (7 bytes); final status/CRC reconfig enabled")
    print("[PASS] 3033-byte reset/reconfig destination SHA-256=" + digest)
    print("[WARN] An early CFG reset may interrupt the transmitting FPGA fabric")
    print("[BLOCK] No JTAG, USB, SPI flash, or live CFG_CTRL operation")
    return 0


if __name__ == "__main__":
    sys.exit(main())
