#!/usr/bin/env python3
"""Compile/run read-only U5IM tests; optionally inspect a 4 MiB flash dump."""
import argparse
import subprocess
import tempfile
from pathlib import Path
import zlib

ROOT = Path(__file__).resolve().parents[1]
FW = ROOT / "fw"
TESTS = ROOT / "tests"


def compile_program(output, sources):
    cmd = ["gcc", "-std=c11", "-Wall", "-Wextra", "-Werror", "-O1",
           "-I", str(FW), "-I", str(TESTS), "-o", str(output)]
    cmd.extend(str(p) for p in sources)
    subprocess.run(cmd, check=True)


def create_test_image(path):
    import struct
    data = bytearray(b"\xff" * (4 * 1024 * 1024))
    payload = b"\xd9\x01\xed\x96" + bytes(range(256)) * 3
    hdr = bytearray(32)
    struct.pack_into("<4sIIIII", hdr, 0, b"U5IM", 1, 1, 256,
                     len(payload), zlib.crc32(payload))
    struct.pack_into("<I", hdr, 24, zlib.crc32(hdr))
    data[0x200000:0x200020] = hdr
    data[0x200100:0x200100 + len(payload)] = payload
    path.write_bytes(data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--flash", type=Path, help="Optional existing full 4 MiB flash dump (read only)")
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="ulx5m-normal-image-") as d:
        test_exe = Path(d) / "normal-image-tests"
        probe_exe = Path(d) / "normal-image-probe"
        common = [FW / "ulx5m_normal_image.c", FW / "ulx5m_flash_layout.c"]
        compile_program(test_exe, common + [
            FW / "ulx5m_at25ql321.c", TESTS / "ulx5m-at25ql321-mock.c",
            TESTS / "test-ulx5m-serv-normal-image.c"])
        subprocess.run([str(test_exe)], check=True)
        compile_program(probe_exe, common + [TESTS / "probe-ulx5m-serv-normal-image.c"])
        empty = Path(d) / "empty.bin"
        empty.write_bytes(b"\xff" * (4 * 1024 * 1024))
        subprocess.run([str(probe_exe), str(empty)], check=True)
        synthetic = Path(d) / "synthetic.bin"
        create_test_image(synthetic)
        subprocess.run([str(probe_exe), str(synthetic)], check=True)
        with synthetic.open("r+b") as f:
            f.seek(0x200100 + 20)
            f.write(b"\x00")
        reject = subprocess.run([str(probe_exe), str(synthetic)], check=False)
        if reject.returncode != 1:
            raise RuntimeError("Corrupted U5IM payload was not rejected")
        print("[PASS] CLI absent, synthetic candidate, and corrupted candidate")
        if args.flash is not None:
            subprocess.run([str(probe_exe), str(args.flash)], check=True)
            print("[NOTE] Flash observation does not authorize writing or booting")


if __name__ == "__main__":
    main()
