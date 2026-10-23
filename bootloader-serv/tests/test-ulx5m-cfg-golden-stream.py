#!/usr/bin/env python3
"""Simulate the Phase 3 sequencer with all bytes of the frozen seed-147 .bit.

Read-only: creates a temporary hex file and vvp build, not a .bit file.
--check-only validates the input without requiring Icarus Verilog.
"""

import argparse
import hashlib
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

SHA256 = "8232dd932ff2ea40b2945de6ed1202be5e7dc75960464419cc0ffa95a75901f8"
SIZE = 414867
MAGIC = bytes.fromhex("d9 01 ed 96")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--golden-bit", required=True)
    parser.add_argument("--check-only", action="store_true")
    args = parser.parse_args()
    path = Path(args.golden_bit)
    try:
        bitstream = path.read_bytes()
    except OSError as exc:
        parser.error(str(exc))
    digest = hashlib.sha256(bitstream).hexdigest()
    if len(bitstream) != SIZE or digest != SHA256 or not bitstream.startswith(MAGIC):
        print("[REJECT] Golden seed-147 size, hash or prefix mismatch", file=sys.stderr)
        return 1
    print("[PASS] Golden seed-147 .bit input: %d bytes, SHA-256 %s" % (SIZE, digest), flush=True)
    if args.check_only:
        print("[NOTE] --check-only: Icarus simulation was not run")
        return 0
    if not shutil.which("iverilog") or not shutil.which("vvp"):
        print("[REJECT] iverilog and vvp required (run in WSL)", file=sys.stderr)
        return 1

    tests = Path(__file__).resolve().parent
    model = tests.parent / "rtl" / "ulx5m_cfg_handoff_model.v"
    tb = tests / "tb_ulx5m_cfg_golden_stream.v"
    if not model.is_file() or not tb.is_file():
        print("[REJECT] Missing Phase 3 controller or Phase 4 testbench", file=sys.stderr)
        return 1

    with tempfile.TemporaryDirectory(prefix="ulx5m-cfg-golden-") as tmp:
        hexfile = Path(tmp) / "golden.hex"
        hexfile.write_text("".join("%02x\n" % b for b in bitstream), encoding="ascii")
        executable = Path(tmp) / "model.vvp"
        cmd = ["iverilog", "-g2012", "-s", "tb_ulx5m_cfg_golden_stream", "-o",
               str(executable), str(model), str(tb)]
        if subprocess.call(cmd) != 0:
            return 1
        return subprocess.call(["vvp", str(executable), "+IMAGE_HEX=" + str(hexfile)])


if __name__ == "__main__":
    sys.exit(main())
