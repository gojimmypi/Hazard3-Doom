#!/usr/bin/env python3
"""Host-only C handoff run on a real GateMate .bit fixture (no flash writes)."""
import argparse
import hashlib
from pathlib import Path
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", type=Path, required=True)
    parser.add_argument("--sha256", required=True, help="Expected SHA-256 of the fixture")
    args = parser.parse_args()
    data = args.image.read_bytes()
    actual = hashlib.sha256(data).hexdigest()
    if actual != args.sha256.lower():
        parser.error(f"Fixture SHA-256 mismatch: {actual}")
    if len(data) < 16 or data[:4] != bytes.fromhex("d901ed96"):
        parser.error("Not a raw GateMate configuration bitstream")
    root = Path(__file__).resolve().parents[1]
    fw = root / "fw"
    with tempfile.TemporaryDirectory(prefix="ulx5m-normal-handoff-") as temp:
        exe = Path(temp) / "handoff-payload"
        cmd = ["gcc", "-std=c11", "-Wall", "-Wextra", "-Werror", "-pedantic",
               "-fsanitize=address,undefined", "-fno-omit-frame-pointer",
               "-I", str(fw), "-o", str(exe),
               str(root / "tests/test-ulx5m-normal-handoff-payload.c"),
               str(fw / "ulx5m_normal_boot.c"),
               str(fw / "ulx5m_normal_image.c"),
               str(fw / "ulx5m_flash_layout.c")]
        subprocess.run(cmd, check=True)
        subprocess.run([str(exe), str(args.image.resolve())], check=True)
    print(f"[PASS] Exact {len(data)}-byte GateMate fixture SHA-256 verified")
    print("[BLOCK] No SPI flash writes, FPGA commands, or hardware operations")


if __name__ == "__main__":
    main()
