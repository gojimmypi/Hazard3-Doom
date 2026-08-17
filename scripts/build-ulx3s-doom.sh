#!/bin/bash
#
# Copyright (c) 2026 gojimmypi
# SPDX-License-Identifier: Apache-2.0
#
# file: scripts/build-ulx3s-doom.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
HAZARD3_ROOT="${HAZARD3_ROOT:-${ROOT_DIR}/third_party/Hazard3}"
SYNTH_DIR="${HAZARD3_ROOT}/example_soc/synth"
BOARD_BUILD_DIR="${ROOT_DIR}/build/ulx3s"
MONITOR_BUILD_DIR="${HAZARD3_BUILD_DIR:-${ROOT_DIR}/build}"
DOOM_BUILD_DIR="${HAZARD3_DOOM_BUILD_DIR:-${ROOT_DIR}/build/doom-image}"
FPGA_SOURCE="${SYNTH_DIR}/fpga_ulx3s.bit"
FPGA_OUTPUT="${BOARD_BUILD_DIR}/fpga_ulx3s.bit"
MONITOR_OUTPUT="${MONITOR_BUILD_DIR}/hazard3-boot-monitor.elf"
MONITOR_BIN="${MONITOR_BUILD_DIR}/hazard3-boot-monitor.bin"
BOOT_HEX="${HAZARD3_ROOT}/example_soc/soc/hazard3-boot-monitor.hex"
SDCARD_DIR="${ROOT_DIR}/build/sdcard"
DOOM_OUTPUT="${DOOM_BUILD_DIR}/hazard3-doom.h3d"

# Run shellcheck to ensure this is a good script.
# Specify the executable shell checker you want to use:
MY_SHELLCHECK="shellcheck"

# Check if the executable is available in the PATH
if command -v "$MY_SHELLCHECK" >/dev/null 2>&1; then
    # Run your command here
    shellcheck "$0" || exit 1
else
    echo "$MY_SHELLCHECK is not installed. Please install it if changes to this script have been made."
fi

require_file()
{
    local path="$1"

    [[ -f "${path}" ]] || {
        echo "Missing required file: ${path}" >&2
        echo "Initialize Hazard3 recursively or set HAZARD3_ROOT correctly." >&2
        exit 1
    }
}

require_executable()
{
    local path="$1"

    [[ -x "${path}" ]] || {
        echo "Missing required executable: ${path}" >&2
        echo "Initialize Hazard3 recursively or set HAZARD3_ROOT correctly." >&2
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

require_tool make
require_tool python3
require_file "${SYNTH_DIR}/ULX3S.mk"
require_file "${HAZARD3_ROOT}/scripts/synth_ecp5.mk"

require_executable "${HAZARD3_ROOT}/scripts/listfiles"
require_executable "${ROOT_DIR}/scripts/build-ulx3s-85f-bitstream.sh"

require_file "${HAZARD3_ROOT}/example_soc/libfpga/common/reset_sync.v"
require_file "${HAZARD3_ROOT}/example_soc/soc/cache_tags_zero.hex"
require_executable "${ROOT_DIR}/scripts/build.sh"
require_executable "${ROOT_DIR}/scripts/make-boot-hex.py"
require_executable "${ROOT_DIR}/doom/build-doom-image.sh"

printf 'Building the shared 50 MHz monitor with the 64 MiB map...\n'
HAZARD3_BUILD_DIR="${MONITOR_BUILD_DIR}" \
HAZARD3_MEMORY_PROFILE=64m \
HAZARD3_SYS_CLK_HZ=50000000 \
    "${ROOT_DIR}/scripts/build.sh"

require_file "${MONITOR_OUTPUT}"
require_file "${MONITOR_BIN}"

printf '\nEmbedding the resident monitor into ULX3S EBR initialization...\n'
"${ROOT_DIR}/scripts/make-boot-hex.py" \
    "${MONITOR_BIN}" "${BOOT_HEX}" --bytes 0x10000 --load-address 0x40

printf '\nBuilding the Hazard3 ULX3S 85F FPGA target with cold-boot monitor...\n'
FORCE_BITSTREAM_REBUILD=1 \
HAZARD3_ROOT="${HAZARD3_ROOT}" \
    "${ROOT_DIR}/scripts/build-ulx3s-85f-bitstream.sh"

mkdir -p "${BOARD_BUILD_DIR}"
require_file "${FPGA_SOURCE}"
cp "${FPGA_SOURCE}" "${FPGA_OUTPUT}"

printf '\nBuilding the shared 64 MiB Doom image...\n'
HAZARD3_DOOM_BUILD_DIR="${DOOM_BUILD_DIR}" \
HAZARD3_MEMORY_PROFILE=64m \
    "${ROOT_DIR}/doom/build-doom-image.sh"

require_file "${FPGA_OUTPUT}"
require_file "${MONITOR_OUTPUT}"
require_file "${DOOM_OUTPUT}"

mkdir -p "${SDCARD_DIR}"
cp "${DOOM_OUTPUT}" "${SDCARD_DIR}/DOOM.H3D"
if [[ -n "${HAZARD3_DOOM_WAD:-}" ]]; then
    require_file "${HAZARD3_DOOM_WAD}"
    cp "${HAZARD3_DOOM_WAD}" "${SDCARD_DIR}/DOOM.WAD"
fi

printf '\nULX3S 85F Doom build complete.\n'
printf '  FPGA:    %s\n' "${FPGA_OUTPUT}"
printf '  Monitor: %s\n' "${MONITOR_OUTPUT}"
printf '  Doom:    %s\n' "${DOOM_OUTPUT}"
printf '  SD H3D:  %s\n' "${SDCARD_DIR}/DOOM.H3D"
printf '  Boot HEX:%s\n' "${BOOT_HEX}"
