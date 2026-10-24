#!/usr/bin/env python3
"""Verify and prepare a reconfig-status walking-LED image for the isolated probe.

Only temporary gmpack subprocesses and create-only build outputs are used.
This script cannot access FPGA/JTAG/USB/SPI hardware or modify source files.
"""
import argparse
import hashlib
from pathlib import Path
import subprocess
import sys
import tempfile

DEFAULT_SHA256 = "68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd"
RECONFIG_SHA256 = "2400c521eb10acd5e496f327e2366c36c3849548891033ce6891fc73469f5eac"
SIZE = 3026
OFFSET = 0xBBB
BEFORE = bytes.fromhex("131f002000000000000000006ca1")
AFTER = bytes.fromhex("1b1f0020000000000000000080ab")


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def validate_original(data):
    if len(data) != SIZE or sha256(data) != DEFAULT_SHA256 or not data.startswith(bytes.fromhex("d901ed96")):
        raise ValueError("original must be exact JTAG-validated walking-LED bitstream")
    if data[OFFSET:OFFSET + len(BEFORE)] != BEFORE:
        raise ValueError("unexpected original command envelope")


def validate_reconfig(original, variant):
    validate_original(original)
    expected = original[:OFFSET] + AFTER + original[OFFSET + len(BEFORE):]
    if len(variant) != SIZE or variant != expected or sha256(variant) != RECONFIG_SHA256:
        raise ValueError("reconfig option changed more than the pinned status command and CRC")


def publish_create_only(files):
    # Check all destinations before creating any. Never overwrite differing data.
    for path, data in files:
        if path.exists() and path.read_bytes() != data:
            raise ValueError("refusing to overwrite a different build output: " + str(path))
    for path, data in files:
        if not path.exists():
            path.parent.mkdir(parents=True, exist_ok=True)
            with path.open("xb") as out:
                out.write(data)


def prepare(image, implementation, rom, bit, runner=subprocess.run):
    if rom == bit:
        raise ValueError("ROM and bitstream outputs must differ")
    original = image.read_bytes()
    validate_original(original)
    if not implementation.is_file():
        raise ValueError("missing original nextpnr implementation")
    with tempfile.TemporaryDirectory(prefix="ulx5m-cfg-dest-") as folder:
        default_out = Path(folder) / "default.bit"
        reconfig_out = Path(folder) / "reconfig.bit"
        for args in (["gmpack", str(implementation), str(default_out)],
                     ["gmpack", "--reconfig", str(implementation), str(reconfig_out)]):
            result = runner(args, capture_output=True, text=True, check=False)
            if result.returncode != 0:
                raise ValueError("gmpack failed: " + (result.stderr or result.stdout or "unknown error").strip())
        if default_out.read_bytes() != original:
            raise ValueError("nextpnr input did not exactly reproduce the JTAG-validated image")
        variant = reconfig_out.read_bytes()
        validate_reconfig(original, variant)
    contents = "".join("{:02x}\n".format(byte) for byte in variant).encode("ascii")
    publish_create_only([(rom, contents), (bit, variant)])
    return sha256(variant)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", required=True, type=Path)
    parser.add_argument("--implementation", required=True, type=Path)
    parser.add_argument("--rom", required=True, type=Path)
    parser.add_argument("--bit", required=True, type=Path)
    args = parser.parse_args()
    try:
        digest = prepare(args.image, args.implementation, args.rom, args.bit)
    except (OSError, UnicodeError, ValueError, subprocess.SubprocessError) as exc:
        print("[FAIL] " + str(exc), file=sys.stderr)
        return 1
    print("[PASS] JTAG-working default reproduced exactly by gmpack")
    print("[PASS] Reconfig destination differs only at offset 0xbbb (14 command/CRC bytes)")
    print("[PASS] 3026-byte reconfig destination SHA-256=" + digest)
    print("[BLOCK] No JTAG, flash, USB or CC_CFG_CTRL hardware operation")
    return 0


if __name__ == "__main__":
    sys.exit(main())
