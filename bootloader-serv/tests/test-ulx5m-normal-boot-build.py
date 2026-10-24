#!/usr/bin/env python3
"""Unified offline gate: host image/transport, RTL model, build safety."""
import pathlib
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent

def run(command, cwd=ROOT):
    print("+ " + " ".join(map(str, command)), flush=True)
    subprocess.run(list(map(str, command)), cwd=cwd, check=True)


def main():
    with tempfile.TemporaryDirectory(prefix="ulx5m-boot-check-") as d:
        exe = pathlib.Path(d) / "normal-boot"
        run(["gcc", "-std=c11", "-Wall", "-Wextra", "-Werror", "-pedantic",
             "-fsanitize=address,undefined", "-fno-omit-frame-pointer",
             "-Ifw", "-o", exe,
             "tests/test-ulx5m-normal-boot-integration.c",
             "fw/ulx5m_normal_boot.c", "fw/ulx5m_normal_image.c",
             "fw/ulx5m_flash_layout.c"])
        run([exe])
        run(["gcc", "-std=c11", "-Wall", "-Wextra", "-Wno-main",
             "-fsyntax-only", "-DBOARD_ULX5M_GS=1",
             "-DULX5M_SERV_TEST=1", "-DULX5M_NORMAL_BOOT_EXPERIMENT=1",
             "-DULX5M_DFU_STREAM_ONLY=1", "-Ifw",
             "fw/fw_ulx5m_flash_read.c", "fw/ulx5m_normal_boot.c",
             "fw/ulx5m_normal_image.c"])
        if shutil.which("iverilog") and shutil.which("vvp"):
            reset_sim = pathlib.Path(d) / "normal-boot-reset.vvp"
            run(["iverilog", "-g2012", "-s", "tb_ulx5m_normal_boot_reset",
                 "-o", reset_sim, "rtl/ulx5m_normal_boot_reset.v",
                 "tests/tb_ulx5m_normal_boot_reset.v"])
            run(["vvp", reset_sim])
            for define in ([], ["-DULX5M_ENABLE_CFG_STREAM"]):
                simulation = pathlib.Path(d) / ("enabled.vvp" if define else "blocked.vvp")
                run(["iverilog", "-g2012", *define, "-s",
                     "tb_ulx5m_cfg_stream_wb", "-o", simulation,
                     "rtl/ulx5m_cfg_stream_wb.v",
                     "tests/tb_ulx5m_cfg_stream_wb.v"])
                run(["vvp", simulation])
        else:
            print("[UNRUN] RTL simulations: Icarus Verilog unavailable")
    print("[PASS] Available integrated offline tests")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as exc:
        sys.exit(exc.returncode or 1)
