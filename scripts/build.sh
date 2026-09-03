#!/bin/bash
# -----------------------------------------------------------------------------
# File:        build.sh
# Path:        scripts/build.sh
#
# Project:     Hazard3-Doom
# Purpose:     Build the shared Hazard3 resident monitor firmware and
#              boot-memory outputs.
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

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SRC_DIR="${ROOT_DIR}/src"
DOOM_DIR="${ROOT_DIR}/doom"
BUILD_DIR="${HAZARD3_BUILD_DIR:-${ROOT_DIR}/build}"
TOOLCHAIN_PREFIX="${TOOLCHAIN_PREFIX:-/opt/riscv/bin/riscv32-unknown-elf-}"
CC="${TOOLCHAIN_PREFIX}gcc"
OBJCOPY="${TOOLCHAIN_PREFIX}objcopy"
OUTPUT_ELF="${BUILD_DIR}/hazard3-boot-monitor.elf"
OUTPUT_MAP="${BUILD_DIR}/hazard3-boot-monitor.map"
OUTPUT_BIN="${BUILD_DIR}/hazard3-boot-monitor.bin"
LINKER_SCRIPT="${HAZARD3_MONITOR_LINKER_SCRIPT:-${SRC_DIR}/link.ld}"

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

require_tool()
{
    local tool="$1"

    if [[ "${tool}" == */* ]]; then
        [[ -x "${tool}" ]] || {
            echo "Missing required executable: ${tool}" >&2
            exit 1
        }
    else
        command -v "${tool}" >/dev/null 2>&1 || {
            echo "Missing required tool: ${tool}" >&2
            exit 1
        }
    fi
}

require_file()
{
    local path="$1"

    [[ -f "${path}" ]] || {
        echo "Missing required file: ${path}" >&2
        exit 1
    }
}

memory_profile="${HAZARD3_MEMORY_PROFILE:-64m}"
case "${memory_profile}" in
64m)
    memory_profile_flags=()
    ;;
32m)
    memory_profile_flags=(-DHAZARD3_SDRAM_32MB)
    ;;
*)
    echo "Unsupported HAZARD3_MEMORY_PROFILE: ${memory_profile} (use 64m or 32m)" >&2
    exit 1
    ;;
esac

system_clock_hz="${HAZARD3_SYS_CLK_HZ:-50000000}"
case "${system_clock_hz}" in
25000000|40000000|50000000)
    ;;
*)
    echo "Unsupported HAZARD3_SYS_CLK_HZ: ${system_clock_hz} (use 25000000, 40000000 or 50000000)" >&2
    exit 1
    ;;
esac

require_tool "${CC}"
require_tool "${OBJCOPY}"
require_file "${SRC_DIR}/start.S"
require_file "${SRC_DIR}/main.c"
require_file "${SRC_DIR}/sao_console.c"
require_file "${SRC_DIR}/sao_console.h"
require_file "${SRC_DIR}/i2cdriver_hdmi.c"
require_file "${SRC_DIR}/i2cdriver_hdmi.h"
require_file "${SRC_DIR}/sd_spi.c"
require_file "${SRC_DIR}/sd_spi.h"
require_file "${SRC_DIR}/fat_ro.c"
require_file "${SRC_DIR}/fat_ro.h"
require_file "${SRC_DIR}/sd_boot.c"
require_file "${SRC_DIR}/sd_boot.h"
require_file "${LINKER_SCRIPT}"
require_file "${DOOM_DIR}/hazard3_sao.c"
require_file "${DOOM_DIR}/hazard3_sao.h"

mkdir -p "${BUILD_DIR}"

system_clock_flags=("-DHAZARD3_SYS_CLK_HZ=${system_clock_hz}u")
system_clock_mhz="$((system_clock_hz / 1000000))"
build_date="${HAZARD3_BUILD_DATE:-$(date +%Y%m%d)}"
firmware_build_flags=(
    "-DHAZARD3_FIRMWARE_MEMORY_PROFILE=\"${memory_profile}\""
    "-DHAZARD3_FIRMWARE_SYS_CLK_MHZ=${system_clock_mhz}"
    "-DHAZARD3_FIRMWARE_BUILD_DATE=\"${build_date}\""
)

printf 'Hazard3 SDRAM profile: %s\n' "${memory_profile}"
printf 'Hazard3 system clock: %s Hz\n' "${system_clock_hz}"
printf 'Hazard3 firmware build date: %s\n' "${build_date}"
printf 'Monitor output: %s\n' "${OUTPUT_ELF}"

"${CC}" \
    -march=rv32imc_zicsr_zifencei_zba_zbb_zbs \
    -mabi=ilp32 \
    -Os \
    -ffunction-sections \
    -fdata-sections \
    -fomit-frame-pointer \
    -g3 \
    -ffreestanding \
    -fno-builtin \
    -nostdlib \
    -nostartfiles \
    -Wl,-T,"${LINKER_SCRIPT}" \
    -Wl,--gc-sections \
    -Wl,-Map,"${OUTPUT_MAP}" \
    -I"${ROOT_DIR}" \
    -I"${DOOM_DIR}" \
    "${memory_profile_flags[@]}" \
    "${system_clock_flags[@]}" \
    "${firmware_build_flags[@]}" \
    "${SRC_DIR}/start.S" \
    "${SRC_DIR}/main.c" \
    "${SRC_DIR}/sd_spi.c" \
    "${SRC_DIR}/fat_ro.c" \
    "${SRC_DIR}/sd_boot.c" \
    "${SRC_DIR}/sao_console.c" \
    "${SRC_DIR}/i2cdriver_hdmi.c" \
    "${DOOM_DIR}/hazard3_sao.c" \
    "${DOOM_DIR}/doom_image_loader.c" \
    "${DOOM_DIR}/doom_wad_loader.c" \
    "${DOOM_DIR}/doom_port_smoke.c" \
    "${DOOM_DIR}/sdram_exec_test.c" \
    "${DOOM_DIR}/sdram_exec_payload.S" \
    -o "${OUTPUT_ELF}"

"${OBJCOPY}" -O binary "${OUTPUT_ELF}" "${OUTPUT_BIN}"
printf 'Monitor binary: %s\n' "${OUTPUT_BIN}"
