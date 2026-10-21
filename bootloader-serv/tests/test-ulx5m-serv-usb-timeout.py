#!/usr/bin/env python3
"""Compile and run the GateMate USB microcode receive-timeout RTL test.

Runs offline in WSL using Icarus Verilog; never accesses USB, JTAG or flash.
"""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build-ulx5m-gs"
SOURCE_ROM = BUILD / "usb_trans_mc.hex"
TEST_ROM = BUILD / "usb_trans_mc-timeout-test.hex"
TEST_VVP = BUILD / "usb-trans-timeout-test.vvp"


def main():
    BUILD.mkdir(exist_ok=True)
    if not SOURCE_ROM.is_file():
        raise SystemExit(
            "Missing build-ulx5m-gs/usb_trans_mc.hex. "
            "First run: make -f Makefile.ulx5m-gs flash-read-serv"
        )
    original = SOURCE_ROM.read_text(encoding="ascii").splitlines()
    generated = subprocess.check_output(
        [sys.executable, "cores/usb/utils/microcode.py"],
        cwd=ROOT, text=True,
    ).splitlines()
    if original != generated:
        raise SystemExit(
            "Stale USB microcode ROM. Run: "
            "make -f Makefile.ulx5m-gs build-ulx5m-gs/usb_trans_mc.hex"
        )
    if generated.count("70c8") != 5:
        raise SystemExit("Expected five EVT_RTO(200) instructions")
    if not 1 <= len(original) <= 256:
        raise SystemExit(f"Unexpected microcode ROM length: {len(original)}")
    for word in original:
        if len(word) != 4 or any(c not in "0123456789abcdefABCDEF" for c in word):
            raise SystemExit(f"Invalid microcode word: {word!r}")
    # Keep the synthesis ROM unchanged. Pad a test-only copy with NOPs.
    TEST_ROM.write_text("\n".join(original + ["0000"] * (256 - len(original))) + "\n", encoding="ascii")
    subprocess.run(
        [
            "iverilog", "-g2012", "-Icores/usb/rtl", "-s", "tb_ulx5m_serv_usb_timeout",
            "-o", str(TEST_VVP.relative_to(ROOT)),
            "cores/usb/rtl/usb_trans.v", "tests/tb_ulx5m_serv_usb_timeout.v",
        ],
        cwd=ROOT,
        check=True,
    )
    subprocess.run(["vvp", str(TEST_VVP.relative_to(ROOT))], cwd=ROOT, check=True)


if __name__ == "__main__":
    main()
