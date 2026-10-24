#!/usr/bin/env python3
"""End-to-end offline U5IM C firmware -> CFG Wishbone RTL replay.

No physical FPGA programming, USB, JTAG, or flash operations. The primitive
in the Icarus replay is a stub; live full-device reconfiguration is blocked.
"""
import argparse
import hashlib
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
TESTS = ROOT / "tests"
FW = ROOT / "fw"
SYNC = bytes.fromhex("d901ed96")


def run(image: Path, sha256: str) -> None:
    source = image.read_bytes()
    digest = hashlib.sha256(source).hexdigest()
    if digest != sha256.lower():
        raise ValueError(f"Fixture SHA-256 mismatch: {digest}")
    if not 16 <= len(source) <= 500000 or not source.startswith(SYNC):
        raise ValueError("Not a bounded raw GateMate bitstream fixture")
    for tool in ("gcc", "iverilog", "vvp"):
        if shutil.which(tool) is None:
            raise RuntimeError(f"Required tool unavailable: {tool}")

    with tempfile.TemporaryDirectory(prefix="ulx5m-c-to-wb-") as directory:
        temp = Path(directory)
        exe = temp / "c-normal-boot"
        cmd = ["gcc", "-std=c11", "-Wall", "-Wextra", "-Werror", "-pedantic",
               "-I", str(FW), "-o", str(exe),
               str(TESTS / "test-ulx5m-normal-handoff-e2e.c"),
               str(FW / "ulx5m_normal_boot.c"),
               str(FW / "ulx5m_normal_image.c"),
               str(FW / "ulx5m_flash_layout.c")]
        subprocess.run(cmd, check=True, cwd=ROOT)

        bench = temp / "cfg-replay.vvp"
        subprocess.run([
            "iverilog", "-g2012", "-DULX5M_ENABLE_CFG_STREAM",
            "-s", "tb_ulx5m_cfg_stream_payload", "-o", str(bench),
            str(ROOT / "rtl/ulx5m_cfg_stream_wb.v"),
            str(TESTS / "tb_ulx5m_cfg_stream_payload.v"),
        ], check=True, cwd=ROOT)

        for mode in ("clean", "late-drift"):
            out = temp / (mode + ".trace")
            subprocess.run([str(exe), str(image.resolve()), str(out), mode],
                           check=True, cwd=ROOT)
            emitted = out.read_bytes()
            if len(emitted) != len(source):
                raise ValueError(f"{mode}: wrong byte count from C")
            if mode == "clean":
                if emitted != source:
                    raise ValueError("C emitted data different from verified payload")
                print("[PASS] C clean stream exactly matches SHA-pinned image", flush=True)
            else:
                if emitted[:-1] != source[:-1] or emitted[-1] != (source[-1] ^ 1):
                    raise ValueError("C drift fixture differs from expected last-byte flip")
                print("[PASS] C rejected late flash-data drift before FINISH", flush=True)

            hexdump = temp / (mode + ".hex")
            hexdump.write_text("".join(f"{b:02x}\n" for b in emitted), encoding="ascii")
            run_cmd = ["vvp", str(bench), f"+HEX={hexdump}",
                       f"+SIZE={len(emitted)}"]
            if mode == "late-drift":
                # Firmware emitted all bytes, then aborted instead of FINISH.
                run_cmd.append(f"+ABORT_AFTER={len(emitted)}")
            subprocess.run(run_cmd, check=True, cwd=ROOT)
            print(f"[PASS] {mode}: real C output replayed through Wishbone RTL", flush=True)

    print(f"[PASS] End-to-end offline stream length={len(source)}, SHA-256={digest}")
    print("[BLOCK] No device configuration, SPI flash writes, USB, or JTAG")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", required=True, type=Path)
    parser.add_argument("--sha256", required=True)
    args = parser.parse_args()
    try:
        run(args.image, args.sha256)
    except (OSError, RuntimeError, ValueError, subprocess.CalledProcessError) as err:
        print(f"[FAIL] {err}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
