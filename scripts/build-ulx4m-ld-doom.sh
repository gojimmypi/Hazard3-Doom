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
HAZARD3_ROOT="${HAZARD3_ROOT:-${ROOT_DIR}/third_party/Hazard3}"
SYNTH_DIR="${HAZARD3_ROOT}/example_soc/synth"
MONITOR_BUILD_DIR="${HAZARD3_BUILD_DIR:-${ROOT_DIR}/build}"
DOOM_BUILD_DIR="${HAZARD3_DOOM_BUILD_DIR:-${ROOT_DIR}/build/doom-image}"
FPGA_OUTPUT="${ROOT_DIR}/build/fpga_ulx4m_ld.bit"
MONITOR_OUTPUT="${MONITOR_BUILD_DIR}/hazard3-boot-monitor.elf"
MONITOR_BIN="${MONITOR_BUILD_DIR}/hazard3-boot-monitor.bin"
BOOT_HEX="${HAZARD3_ROOT}/example_soc/soc/hazard3-boot-monitor.hex"
DOOM_OUTPUT="${DOOM_BUILD_DIR}/hazard3-doom.h3d"
LITEDRAM_DIR="${HAZARD3_ROOT}/example_soc/third_party/LiteDRAM"
HAZARD3_ULX4M_SYS_CLK_MHZ="${HAZARD3_ULX4M_SYS_CLK_MHZ:-50}"

# Run shellcheck to ensure this is a good script.
# Specify the executable shell checker you want to use:
MY_SHELLCHECK="shellcheck"

# Check if the executable is available in the PATH
if command -v "$MY_SHELLCHECK" >/dev/null 2>&1; then
    "${MY_SHELLCHECK}" -x "${BASH_SOURCE[0]}" >&2 || exit 1
else
    echo "$MY_SHELLCHECK is not installed. Please install it if changes to this script have been made."
fi

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

case "${HAZARD3_ULX4M_SYS_CLK_MHZ}" in
25|40|50)
    ;;
*)
    echo "HAZARD3_ULX4M_SYS_CLK_MHZ must be 25, 40, or 50" >&2
    exit 1
    ;;
esac
HAZARD3_ULX4M_SYS_CLK_HZ=$((HAZARD3_ULX4M_SYS_CLK_MHZ * 1000000))

require_tool make
require_tool python3
require_file "${SYNTH_DIR}/ULX4M_LD_85F.mk"
require_file "${HAZARD3_ROOT}/scripts/synth_ecp5.mk"
require_executable "${HAZARD3_ROOT}/scripts/listfiles"
require_executable "${ROOT_DIR}/scripts/build-ulx4m-ld-bitstream.sh"
require_file "${HAZARD3_ROOT}/example_soc/libfpga/common/reset_sync.v"
require_file "${LITEDRAM_DIR}/litedram_ulx4m_cpu.v"
require_file "${LITEDRAM_DIR}/litedram_ulx4m_cpu_rom.init"
require_file "${LITEDRAM_DIR}/litedram_ulx4m_cpu_sram.init"
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
"${ROOT_DIR}/scripts/make-boot-hex.py" \
    "${MONITOR_BIN}" "${BOOT_HEX}" --bytes 0x10000 --load-address 0x40
require_file "${BOOT_HEX}"

printf '\nBuilding the Hazard3 ULX4M-LD 85F FPGA target with cold-boot monitor...\n'
HAZARD3_ROOT="${HAZARD3_ROOT}" \
HAZARD3_ULX4M_SYS_CLK_MHZ="${HAZARD3_ULX4M_SYS_CLK_MHZ}" \
    "${ROOT_DIR}/scripts/build-ulx4m-ld-bitstream.sh"

require_file "${FPGA_OUTPUT}"

printf '\nBuilding the shared 64 MiB Doom image...\n'
HAZARD3_DOOM_BUILD_DIR="${DOOM_BUILD_DIR}" \
HAZARD3_MEMORY_PROFILE=64m \
    "${ROOT_DIR}/doom/build-doom-image.sh"

require_file "${FPGA_OUTPUT}"
require_file "${MONITOR_OUTPUT}"
require_file "${DOOM_OUTPUT}"
require_file "${BOOT_HEX}"

printf '\nULX4M-LD 85F Doom build complete.\n'
printf '  FPGA:    %s\n' "${FPGA_OUTPUT}"
printf '  Monitor: %s\n' "${MONITOR_OUTPUT}"
printf '  Doom:    %s\n' "${DOOM_OUTPUT}"
printf '  Boot HEX:%s\n' "${BOOT_HEX}"
