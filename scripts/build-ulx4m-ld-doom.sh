#!/bin/bash
# -----------------------------------------------------------------------------
# File:        build-ulx4m-ld-doom.sh
# Path:        scripts/build-ulx4m-ld-doom.sh
#
# Project:     Hazard3-Doom
# Purpose:     Build the complete ULX4M-LD monitor, FPGA bitstream, and Doom
#              image.
#
# Copyright (c) 2026 gojimmypi
#
# Licensed under the Apache License, Version 2.0.
#
# SPDX-License-Identifier: Apache-2.0
#
# This software is provided under the terms of the applicable license.
# See LICENSES/Apache-2.0.txt for the complete license terms.
# See LICENSING.md for project licensing policy and scope.
# -----------------------------------------------------------------------------

# file: scripts/build-ulx4m-ld-doom.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
BOARD_BUILD_DIR="${BUILD_DIR}/ulx4m-ld"
BUILD_LOG="${BUILD_DIR}/build-ulx4m-ld-doom.log"

if ! command -v tee >/dev/null 2>&1; then
    echo "ERROR: tee is required to capture the build log" >&2
    exit 1
fi

mkdir -p "${BUILD_DIR}"
exec > >(tee "${BUILD_LOG}") 2>&1
printf 'Build log: %s\n' "${BUILD_LOG}"

# Run shellcheck to ensure this is a good script.
# Specify the executable shell checker you want to use:
MY_SHELLCHECK="shellcheck"

# Check if the executable is available in the PATH
if command -v "$MY_SHELLCHECK" >/dev/null 2>&1; then
    "${MY_SHELLCHECK}" -x "${BASH_SOURCE[0]}" >&2 || exit 1
else
    echo "$MY_SHELLCHECK is not installed. Please install it if changes to this script have been made."
fi

if [[ -z "${TOOLCHAIN_PREFIX:-}" ]]; then
    if [[ -x /opt/riscv/bin/riscv32-unknown-elf-gcc ]]; then
        TOOLCHAIN_PREFIX="/opt/riscv/bin/riscv32-unknown-elf-"
    elif command -v riscv-none-elf-gcc >/dev/null 2>&1; then
        TOOLCHAIN_PREFIX="riscv-none-elf-"
    else
        echo "ERROR: RISC-V GCC toolchain not found" >&2
        exit 1
    fi
fi
export TOOLCHAIN_PREFIX

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
HAZARD3_ROOT="${HAZARD3_ROOT:-${ROOT_DIR}/third_party/Hazard3}"
SYNTH_DIR="${HAZARD3_ROOT}/example_soc/synth"
BOARD_BUILD_DIR="${ROOT_DIR}/build/ulx4m-ld"
MONITOR_BUILD_DIR="${HAZARD3_BUILD_DIR:-${BOARD_BUILD_DIR}/monitor}"
DOOM_BUILD_DIR="${HAZARD3_DOOM_BUILD_DIR:-${BOARD_BUILD_DIR}/doom-image}"
FPGA_OUTPUT="${ROOT_DIR}/build/fpga_ulx4m_ld.bit"
PNR_LOG="${ROOT_DIR}/build/fpga_ulx4m_ld.pnr.log"
MONITOR_OUTPUT="${MONITOR_BUILD_DIR}/hazard3-boot-monitor.elf"
MONITOR_BIN="${MONITOR_BUILD_DIR}/hazard3-boot-monitor.bin"
BOOT_HEX_WORK="${HAZARD3_ROOT}/example_soc/soc/hazard3-boot-monitor.hex"
BOOT_HEX_OUTPUT="${BOARD_BUILD_DIR}/hazard3-boot-monitor.hex"
DOOM_OUTPUT="${DOOM_BUILD_DIR}/hazard3-doom.h3img"
LITEDRAM_DIR="${HAZARD3_ROOT}/example_soc/third_party/LiteDRAM"
HAZARD3_ULX4M_SYS_CLK_MHZ="${HAZARD3_ULX4M_SYS_CLK_MHZ:-40}"
ULX4M_LITEDRAM_CPU="${ULX4M_LITEDRAM_CPU:-serv}"


require_file()
{
    local path="$1"

    [[ -f "${path}" ]] || {
        echo "Missing required file: ${path}" >&2
        echo "Initialize Hazard3 or set HAZARD3_ROOT correctly." >&2
        exit 1
    }
}

require_executable()
{
    local path="$1"

    [[ -x "${path}" ]] || {
        echo "Missing required executable: ${path}" >&2
        echo "Initialize Hazard3 or set HAZARD3_ROOT correctly." >&2
        exit 1
    }
}

require_tool()
{
    local tool="$1"

    command -v "${tool}" >/dev/null 2>&1 || {
        echo "Missing required tool: ${tool}" >&2
        exit 1
    }
}

print_final_timing_summary()
{
    local pnr_log="$1"
    local timing_lines
    local timing_line

    if [[ ! -f "${pnr_log}" ]]; then
        printf '  Final timing: unavailable (missing %s)\n' "${pnr_log}"
        return
    fi

    if ! command -v awk >/dev/null 2>&1; then
        printf '  Final timing: unavailable (awk not found; see %s)\n' "${pnr_log}"
        return
    fi

    timing_lines="$(
        awk '
        /Max frequency for clock/ {
            clock = $0
            sub(/^.*clock /, "", clock)
            sub(/: .*$/, "", clock)
            if (!(clock in seen)) {
                order[++count] = clock
                seen[clock] = 1
            }
            line = $0
            sub(/^Info: /, "", line)
            last[clock] = line
        }
        END {
            for (i = 1; i <= count; ++i) {
                print last[order[i]]
            }
        }' "${pnr_log}"
    )"

    if [[ -z "${timing_lines}" ]]; then
        printf '  Final timing: unavailable (no clock results in %s)\n' "${pnr_log}"
        return
    fi

    printf '  Final timing:\n'
    while IFS= read -r timing_line; do
        printf '    %s\n' "${timing_line}"
    done <<< "${timing_lines}"
}

case "${HAZARD3_ULX4M_SYS_CLK_MHZ}" in
25|40|50)
    ;;
*)
    echo "HAZARD3_ULX4M_SYS_CLK_MHZ must be 25, 40, or 50" >&2
    exit 1
    ;;
esac
HAZARD3_ULX4M_SYS_CLK_HZ=$((HAZARD3_ULX4M_SYS_CLK_MHZ * 1000000))

case "${ULX4M_LITEDRAM_CPU}" in
serv)
    LITEDRAM_GENERATED_DIR="${LITEDRAM_DIR}/generated-serv"
    ;;
vexrisc)
    LITEDRAM_GENERATED_DIR="${LITEDRAM_DIR}/generated-vexrisc"
    ;;
*)
    echo "ULX4M_LITEDRAM_CPU must be serv or vexrisc" >&2
    exit 1
    ;;
esac

printf 'ULX4M-LD build configuration: system clock=%s MHz, LiteDRAM CPU=%s\n' \
    "${HAZARD3_ULX4M_SYS_CLK_MHZ}" "${ULX4M_LITEDRAM_CPU}"

require_tool make
require_tool install
require_tool python3
require_file "${SYNTH_DIR}/ULX4M_LD_85F.mk"
require_file "${HAZARD3_ROOT}/scripts/synth_ecp5.mk"
require_executable "${HAZARD3_ROOT}/scripts/listfiles"
require_executable "${ROOT_DIR}/scripts/build-ulx4m-ld-bitstream.sh"
require_file "${HAZARD3_ROOT}/example_soc/libfpga/common/reset_sync.v"
require_file "${LITEDRAM_DIR}/litedram_ulx4m_cpu.v"
require_file "${LITEDRAM_GENERATED_DIR}/litedram_ulx4m_cpu.v"
require_file "${LITEDRAM_GENERATED_DIR}/litedram_ulx4m_cpu_rom.init"
require_file "${LITEDRAM_GENERATED_DIR}/litedram_ulx4m_cpu_sram.init"
require_executable "${ROOT_DIR}/scripts/build.sh"
require_executable "${ROOT_DIR}/scripts/make-boot-hex.py"
require_executable "${ROOT_DIR}/doom/build-doom-image.sh"

printf 'Building the shared %s MHz monitor with the 64 MiB map...\n' \
    "${HAZARD3_ULX4M_SYS_CLK_MHZ}"
HAZARD3_BUILD_DIR="${MONITOR_BUILD_DIR}" \
HAZARD3_MEMORY_PROFILE=64m \
HAZARD3_SYS_CLK_HZ="${HAZARD3_ULX4M_SYS_CLK_HZ}" \
    "${ROOT_DIR}/scripts/build.sh"

require_file "${MONITOR_OUTPUT}"
require_file "${MONITOR_BIN}"

printf '\nEmbedding the resident monitor into ULX4M EBR initialization...\n'
mkdir -p "${BOARD_BUILD_DIR}"
"${ROOT_DIR}/scripts/make-boot-hex.py" \
    "${MONITOR_BIN}" "${BOOT_HEX_WORK}" --bytes 0x10000 --load-address 0x40
require_file "${BOOT_HEX_WORK}"
install -m 0644 "${BOOT_HEX_WORK}" "${BOOT_HEX_OUTPUT}"

printf '\nBuilding the Hazard3 ULX4M-LD 85F FPGA target with cold-boot monitor...\n'
HAZARD3_ROOT="${HAZARD3_ROOT}" \
HAZARD3_ULX4M_SYS_CLK_MHZ="${HAZARD3_ULX4M_SYS_CLK_MHZ}" \
ULX4M_LITEDRAM_CPU="${ULX4M_LITEDRAM_CPU}" \
    "${ROOT_DIR}/scripts/build-ulx4m-ld-bitstream.sh"

require_file "${FPGA_OUTPUT}"

printf '\nBuilding the shared 64 MiB Doom image...\n'
HAZARD3_DOOM_BUILD_DIR="${DOOM_BUILD_DIR}" \
HAZARD3_MEMORY_PROFILE=64m \
    "${ROOT_DIR}/doom/build-doom-image.sh"

require_file "${FPGA_OUTPUT}"
require_file "${MONITOR_OUTPUT}"
require_file "${DOOM_OUTPUT}"
require_file "${BOOT_HEX_OUTPUT}"

printf '\nULX4M-LD 85F Doom build complete.\n'
printf '  FPGA:    %s\n' "${FPGA_OUTPUT}"
printf '  Monitor: %s\n' "${MONITOR_OUTPUT}"
printf '  Doom:    %s\n' "${DOOM_OUTPUT}"
printf '  Log:     %s\n' "${BUILD_LOG}"
print_final_timing_summary "${PNR_LOG}"
printf '  Boot HEX: %s\n' "${BOOT_HEX_OUTPUT}"
printf '  Profile: 64m address map, %s MHz, LiteDRAM CPU=%s\n\n' \
    "${HAZARD3_ULX4M_SYS_CLK_MHZ}" "${ULX4M_LITEDRAM_CPU}"
printf 'To program the ULX4M user bitstream through the protected DFU path:\n\n'
printf '  ./scripts/ulx4m-bootloader.sh program-user ./build/fpga_ulx4m_ld.bit\n\n'
printf 'Follow the BTN3/DFU prompts. This programs the persistent user slot.\n'
printf 'After the requested cold boot, the resident monitor starts automatically.\n'
printf 'No separate firmware-load step is required.\n\n'
printf 'To load Doom executable:\n\n'
printf '  ./doom/upload-doom-image.py  ./build/ulx4m-ld/doom-image/hazard3-doom.h3img  --port /dev/ttyS7\n\n'
printf 'To load Doom WAD:\n\n'
printf '  ./doom/upload-wad.py  ./wads/DOOM1.WAD  --port /dev/ttyS7  --launch\n\n'
