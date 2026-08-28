#!/bin/bash
# -----------------------------------------------------------------------------
# File:        build-ulx3s-12f-doom.sh
# Path:        scripts/build-ulx3s-12f-doom.sh
#
# Project:     Hazard3-Doom
# Purpose:     Build the complete ULX3S 12F monitor, FPGA bitstream, Doom
#              image, and staging package.
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

# Complete ULX3S 12F compact build. Board wiring and software features remain
# aligned with ULX3S 85F; only EBR-heavy memory/video storage is specialized.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
HAZARD3_ROOT="${HAZARD3_ROOT:-${ROOT_DIR}/third_party/Hazard3}"
SYNTH_DIR="${HAZARD3_ROOT}/example_soc/synth"
BOARD_BUILD_DIR="${ROOT_DIR}/build/ulx3s-12f"
MONITOR_BUILD_DIR="${HAZARD3_BUILD_DIR:-${BOARD_BUILD_DIR}/monitor}"
DOOM_BUILD_DIR="${HAZARD3_DOOM_BUILD_DIR:-${BOARD_BUILD_DIR}/doom-image}"
SDCARD_DIR="${BOARD_BUILD_DIR}/sdcard"
FPGA_OUTPUT="${ROOT_DIR}/build/fpga_ulx3s_12f.bit"
MONITOR_OUTPUT="${MONITOR_BUILD_DIR}/hazard3-boot-monitor.elf"
PROGRAMMING_PACKAGE="${BOARD_BUILD_DIR}/hazard3-doom-ulx3s-12f.zip"
DOOM_OUTPUT="${DOOM_BUILD_DIR}/hazard3-doom.h3d"
MEMORY_PROFILE="${HAZARD3_MEMORY_PROFILE:-32m}"
VIDEO_RESOLUTION="${HAZARD3_DOOM_HDMI_RESOLUTION:-320x200}"

require_file()
{
    local path="$1"
    [[ -f "${path}" ]] || { echo "Missing required file: ${path}" >&2; exit 1; }
}

require_executable()
{
    local path="$1"
    [[ -x "${path}" ]] || { echo "Missing required executable: ${path}" >&2; exit 1; }
}

case "${MEMORY_PROFILE}" in
32m|64m) ;;
*)
    echo "Unsupported HAZARD3_MEMORY_PROFILE: ${MEMORY_PROFILE} (use 32m or 64m)" >&2
    exit 1
    ;;
esac

if [[ "${VIDEO_RESOLUTION}" != "320x200" ]]; then
    echo "ULX3S 12F supports only HAZARD3_DOOM_HDMI_RESOLUTION=320x200." >&2
    exit 1
fi

require_file "${SYNTH_DIR}/ULX3S_12F.mk"
require_file "${SYNTH_DIR}/fpga_ulx3s.lpf"
require_file "${HAZARD3_ROOT}/example_soc/soc/cache_tags_zero_12f.hex"
require_file "${HAZARD3_ROOT}/example_soc/soc/hazard3-12f-bootstrap.hex"
require_executable "${ROOT_DIR}/scripts/build.sh"
require_executable "${ROOT_DIR}/scripts/build-ulx3s-12f-bitstream.sh"
require_executable "${ROOT_DIR}/scripts/package-fpga-console-firmware.py"
require_executable "${ROOT_DIR}/doom/build-doom-image.sh"

printf 'Building ULX3S 12F monitor in external SDRAM (%s profile)...\n' "${MEMORY_PROFILE}"
HAZARD3_BUILD_DIR="${MONITOR_BUILD_DIR}" \
HAZARD3_MONITOR_LINKER_SCRIPT="${ROOT_DIR}/src/link-12f-sdram.ld" \
HAZARD3_MEMORY_PROFILE="${MEMORY_PROFILE}" \
HAZARD3_SYS_CLK_HZ=40000000 \
    "${ROOT_DIR}/scripts/build.sh"
require_file "${MONITOR_OUTPUT}"

printf '\nBuilding the shared ULX3S board design for the LFE5U-12F profile...\n'
FORCE_BITSTREAM_REBUILD=1 \
HAZARD3_MEMORY_PROFILE="${MEMORY_PROFILE}" \
HAZARD3_ROOT="${HAZARD3_ROOT}" \
    "${ROOT_DIR}/scripts/build-ulx3s-12f-bitstream.sh"
require_file "${FPGA_OUTPUT}"

printf '\nPackaging the matched ULX3S 12F FPGA image and console firmware...\n'
"${ROOT_DIR}/scripts/package-fpga-console-firmware.py" \
    "${FPGA_OUTPUT}" "${MONITOR_OUTPUT}" "${PROGRAMMING_PACKAGE}" \
    --board ulx3s-12f
require_file "${PROGRAMMING_PACKAGE}"

printf '\nBuilding the 320x200 Doom image (%s profile)...\n' "${MEMORY_PROFILE}"
HAZARD3_DOOM_BUILD_DIR="${DOOM_BUILD_DIR}" \
HAZARD3_MEMORY_PROFILE="${MEMORY_PROFILE}" \
HAZARD3_DOOM_HDMI_RESOLUTION=320x200 \
    "${ROOT_DIR}/doom/build-doom-image.sh"
require_file "${DOOM_OUTPUT}"

mkdir -p "${BOARD_BUILD_DIR}" "${SDCARD_DIR}"
printf '%s\n' "${MEMORY_PROFILE}" > "${BOARD_BUILD_DIR}/memory-profile.txt"
printf 'compact-320x200-sdram-scanout\n' > "${BOARD_BUILD_DIR}/video-profile.txt"
cp "${DOOM_OUTPUT}" "${SDCARD_DIR}/DOOM.H3D"
if [[ -n "${HAZARD3_DOOM_WAD:-}" ]]; then
    require_file "${HAZARD3_DOOM_WAD}"
    cp "${HAZARD3_DOOM_WAD}" "${SDCARD_DIR}/DOOM.WAD"
fi

printf '\nULX3S 12F Doom build complete.\n'
printf '  FPGA:    %s\n' "${FPGA_OUTPUT}"
printf '  Monitor: %s\n' "${MONITOR_OUTPUT}"
printf '  Package: %s\n' "${PROGRAMMING_PACKAGE}"
printf '  Doom:    %s\n' "${DOOM_OUTPUT}"
printf '  SD H3D:  %s\n' "${SDCARD_DIR}/DOOM.H3D"
printf '  Profile: %s SDRAM, 320x200 compact scanout\n' "${MEMORY_PROFILE}"
printf '\nAfter programming the FPGA and starting OpenOCD, run:\n'
printf '  ./scripts/load-firmware-12f.sh\n'
