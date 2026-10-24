#!/usr/bin/env python3
"""Replay an exact GateMate bitstream through the real CFG Wishbone RTL.

Offline Icarus only. Never writes FPGA, JTAG, USB or SPI flash.  It does not
prove that a whole-device configuration is supported by the GateMate silicon.
"""

import argparse
import hashlib
from pathlib import Path
import shutil
import subprocess
import tempfile

MAX_BYTES = 500000
SYNC = bytes.fromhex("d901ed96")
ROOT = Path(__file__).resolve().parents[1]


def check_fixture(path, expected_hash):
    data = path.read_bytes()
    actual = hashlib.sha256(data).hexdigest()
    if actual != expected_hash.lower():
        raise ValueError(f"SHA-256 mismatch: expected {expected_hash}, got {actual}")
    if not 16 <= len(data) <= MAX_BYTES or not data.startswith(SYNC):
        raise ValueError("Not a bounded raw GateMate configuration fixture")
    return data


def run_offline(image, sha256, abort_after=0):
    data = check_fixture(image, sha256)
    if abort_after and not 1 <= abort_after < len(data):
        raise ValueError("Abort position outside the payload")
    if not shutil.which("iverilog") or not shutil.which("vvp"):
        raise RuntimeError("Icarus Verilog (iverilog and vvp) is required; test not skipped")
    with tempfile.TemporaryDirectory(prefix="ulx5m-cfg-wb-full-") as directory:
        temp = Path(directory)
        hex_path = temp / "payload.hex"
        hex_path.write_text("".join(f"{byte:02x}\n" for byte in data), encoding="ascii")
        vvp_path = temp / "cfg-payload.vvp"
        subprocess.run([
            "iverilog", "-g2012", "-DULX5M_ENABLE_CFG_STREAM",
            "-s", "tb_ulx5m_cfg_stream_payload", "-o", str(vvp_path),
            str(ROOT / "rtl/ulx5m_cfg_stream_wb.v"),
            str(ROOT / "tests/tb_ulx5m_cfg_stream_payload.v"),
        ], check=True, cwd=ROOT)
        command = ["vvp", str(vvp_path), f"+HEX={hex_path}", f"+SIZE={len(data)}"]
        if abort_after:
            command.append(f"+ABORT_AFTER={abort_after}")
        subprocess.run(command, check=True, cwd=ROOT)
    print(f"[PASS] Fixture size={len(data)} SHA-256={sha256.lower()}")
    print("[BLOCK] No physical CFG_CTRL, flash, JTAG, or USB operation")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", required=True, type=Path)
    parser.add_argument("--sha256", required=True)
    parser.add_argument("--abort-after", type=int, default=0,
                        help="Inject controller ABORT after N accepted bytes")
    args = parser.parse_args()
    try:
        run_offline(args.image, args.sha256, args.abort_after)
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"[FAIL] {error}\n")


if __name__ == "__main__":
    main()
