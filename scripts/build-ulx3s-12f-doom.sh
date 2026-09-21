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
BUILD_DIR="${ROOT_DIR}/build"
BOARD_BUILD_DIR="${BUILD_DIR}/ulx3s-12f"
BUILD_LOG="${BUILD_DIR}/build-ulx3s-12f-doom.log"
IS_WSL=0
kernel_release=""
kernel_release="$(uname -r 2>/dev/null || true)"

if [[ -n "${WSL_DISTRO_NAME:-}" || -n "${WSL_INTEROP:-}" ]] ||
    [[ "${kernel_release,,}" == *microsoft* ]]; then
    IS_WSL=1
fi

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

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
HAZARD3_ROOT="${HAZARD3_ROOT:-${ROOT_DIR}/third_party/Hazard3}"
SYNTH_DIR="${HAZARD3_ROOT}/example_soc/synth"
BOARD_BUILD_DIR="${ROOT_DIR}/build/ulx3s-12f"
MONITOR_BUILD_DIR="${HAZARD3_BUILD_DIR:-${BOARD_BUILD_DIR}/monitor}"
DOOM_BUILD_DIR="${HAZARD3_DOOM_BUILD_DIR:-${BOARD_BUILD_DIR}/doom-image}"
SDCARD_DIR="${BOARD_BUILD_DIR}/sdcard"
FPGA_OUTPUT="${ROOT_DIR}/build/fpga_ulx3s_12f.bit"
FPGA_NETLIST="${ROOT_DIR}/build/fpga_ulx3s_12f.json"
PNR_LOG="${ROOT_DIR}/build/fpga_ulx3s_12f.pnr.log"
MONITOR_OUTPUT="${MONITOR_BUILD_DIR}/hazard3-boot-monitor.elf"
DOOM_OUTPUT="${DOOM_BUILD_DIR}/hazard3-doom.h3img"
BOOTSTRAP_BUILD_DIR="${BOARD_BUILD_DIR}/bootstrap"
BOOTSTRAP_ELF="${BOOTSTRAP_BUILD_DIR}/hazard3-12f-bootstrap.elf"
BOOTSTRAP_MAP="${BOOTSTRAP_BUILD_DIR}/hazard3-12f-bootstrap.map"
BOOTSTRAP_BIN="${BOOTSTRAP_BUILD_DIR}/hazard3-12f-bootstrap.bin"
BOOT_HEX_BUILD="${BOOTSTRAP_BUILD_DIR}/hazard3-12f-bootstrap.hex"
BOOT_HEX_SOURCE="${HAZARD3_ROOT}/example_soc/soc/hazard3-12f-bootstrap.hex"
BOOT_HEX_OUTPUT="${BOARD_BUILD_DIR}/hazard3-12f-bootstrap.hex"
BOOT_HEX_BACKUP=""
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

require_tool()
{
    local tool="$1"
    command -v "${tool}" >/dev/null 2>&1 || { echo "Missing required tool: ${tool}" >&2; exit 1; }
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

printf 'ULX3S 12F build configuration: system clock=40 MHz, SDRAM profile=%s, video=%s\n' \
    "${MEMORY_PROFILE}" "${VIDEO_RESOLUTION}"

require_file "${SYNTH_DIR}/ULX3S_12F.mk"
require_file "${SYNTH_DIR}/fpga_ulx3s.lpf"
require_file "${HAZARD3_ROOT}/example_soc/soc/cache_tags_zero_12f.hex"
require_file "${BOOT_HEX_SOURCE}"
require_file "${ROOT_DIR}/src/bootstrap-12f.S"
require_file "${ROOT_DIR}/src/link-12f-bootstrap.ld"
require_executable "${ROOT_DIR}/scripts/build.sh"
require_executable "${ROOT_DIR}/scripts/build-ulx3s-12f-bitstream.sh"
require_executable "${ROOT_DIR}/scripts/make-boot-hex.py"
require_executable "${ROOT_DIR}/doom/build-doom-image.sh"
require_tool "${TOOLCHAIN_PREFIX}gcc"
require_tool "${TOOLCHAIN_PREFIX}objcopy"

printf 'Building ULX3S 12F UART bootstrap for the 1 KiB EBR window...\n'
mkdir -p "${BOOTSTRAP_BUILD_DIR}"
"${TOOLCHAIN_PREFIX}gcc" \
    -march=rv32imc \
    -mabi=ilp32 \
    -Os \
    -ffreestanding \
    -nostdlib \
    -nostartfiles \
    -Wl,-T,"${ROOT_DIR}/src/link-12f-bootstrap.ld" \
    -Wl,--gc-sections \
    -Wl,-Map,"${BOOTSTRAP_MAP}" \
    "${ROOT_DIR}/src/bootstrap-12f.S" \
    -o "${BOOTSTRAP_ELF}"
"${TOOLCHAIN_PREFIX}objcopy" -O binary "${BOOTSTRAP_ELF}" "${BOOTSTRAP_BIN}"
"${ROOT_DIR}/scripts/make-boot-hex.py" \
    "${BOOTSTRAP_BIN}" "${BOOT_HEX_BUILD}" --bytes 0x400 --load-address 0x40
cp "${BOOT_HEX_BUILD}" "${BOOT_HEX_OUTPUT}"

printf '\nBuilding ULX3S 12F monitor in external SDRAM (%s profile)...\n' "${MEMORY_PROFILE}"
HAZARD3_BUILD_DIR="${MONITOR_BUILD_DIR}" \
HAZARD3_MONITOR_LINKER_SCRIPT="${ROOT_DIR}/src/link-12f-sdram.ld" \
HAZARD3_MEMORY_PROFILE="${MEMORY_PROFILE}" \
HAZARD3_SYS_CLK_HZ=40000000 \
    "${ROOT_DIR}/scripts/build.sh"
require_file "${MONITOR_OUTPUT}"

restore_boot_hex_source()
{
    if [[ -n "${BOOT_HEX_BACKUP}" && -f "${BOOT_HEX_BACKUP}" ]]; then
        cp -p "${BOOT_HEX_BACKUP}" "${BOOT_HEX_SOURCE}"
        rm -f "${BOOT_HEX_BACKUP}"
        BOOT_HEX_BACKUP=""
    fi
}

printf '\nBuilding the shared ULX3S board design for the LFE5U-12F profile...\n'
# Hazard3 currently names the 12F preload from its tracked top-level RTL.
# Substitute the project bootstrap only for synthesis, then restore the exact
# original file so a normal build does not leave the Hazard3 submodule dirty.
BOOT_HEX_BACKUP="$(mktemp "${BOOTSTRAP_BUILD_DIR}/hazard3-12f-bootstrap.backup.XXXXXX")"
cp -p "${BOOT_HEX_SOURCE}" "${BOOT_HEX_BACKUP}"
trap restore_boot_hex_source EXIT
cp "${BOOT_HEX_BUILD}" "${BOOT_HEX_SOURCE}"
# The preload contents are FPGA initialization data. Remove the generated
# netlist so synthesis cannot reuse one containing an older bootstrap image.
rm -f "${FPGA_NETLIST}"
FORCE_BITSTREAM_REBUILD=1 \
HAZARD3_MEMORY_PROFILE="${MEMORY_PROFILE}" \
HAZARD3_ROOT="${HAZARD3_ROOT}" \
    "${ROOT_DIR}/scripts/build-ulx3s-12f-bitstream.sh"
restore_boot_hex_source
trap - EXIT
require_file "${FPGA_OUTPUT}"

printf '\nBuilding the 320x200 Doom image (%s profile)...\n' "${MEMORY_PROFILE}"
HAZARD3_DOOM_BUILD_DIR="${DOOM_BUILD_DIR}" \
HAZARD3_MEMORY_PROFILE="${MEMORY_PROFILE}" \
HAZARD3_DOOM_HDMI_RESOLUTION=320x200 \
    "${ROOT_DIR}/doom/build-doom-image.sh"
require_file "${DOOM_OUTPUT}"

mkdir -p "${BOARD_BUILD_DIR}" "${SDCARD_DIR}"
printf '%s\n' "${MEMORY_PROFILE}" > "${BOARD_BUILD_DIR}/memory-profile.txt"
printf 'compact-320x200-sdram-scanout\n' > "${BOARD_BUILD_DIR}/video-profile.txt"
cp "${DOOM_OUTPUT}" "${SDCARD_DIR}/DOOM.IMG"
if [[ -n "${HAZARD3_DOOM_WAD:-}" ]]; then
    require_file "${HAZARD3_DOOM_WAD}"
    cp "${HAZARD3_DOOM_WAD}" "${SDCARD_DIR}/DOOM.WAD"
fi

printf '\nULX3S 12F Doom build complete.\n'
printf '  FPGA:    %s\n' "${FPGA_OUTPUT}"
printf '  Monitor: %s\n' "${MONITOR_OUTPUT}"
printf '  Doom:    %s\n' "${DOOM_OUTPUT}"
printf '  Log:     %s\n' "${BUILD_LOG}"
print_final_timing_summary "${PNR_LOG}"
printf '  SD H3IMG:  %s\n' "${SDCARD_DIR}/DOOM.IMG"
printf '  Bootstrap: %s\n' "${BOOTSTRAP_ELF}"
printf '  Bootstrap HEX: %s\n' "${BOOT_HEX_OUTPUT}"
printf '  Profile: %s SDRAM, 320x200 compact scanout\n\n' "${MEMORY_PROFILE}"
printf 'To load the FPGA bitstream into SRAM (temporary; lost on power-cycle):\n\n'
if (( IS_WSL == 1 )); then
    printf '  ./bin/fujprog-v48-win64.exe  ./build/fpga_ulx3s_12f.bit\n\n'
else
    printf '  fujprog  ./build/fpga_ulx3s_12f.bit\n\n'
fi
printf 'After programming the FPGA, run:\n\n'
printf '  ./scripts/load-firmware-12f.sh\n\n'
printf 'The loader reuses OpenOCD on localhost:3333 or starts it automatically.\n\n'
printf 'To load Doom executable:\n\n'
printf '  ./doom/upload-doom-image.py  ./build/ulx3s-12f/doom-image/hazard3-doom.h3img  --port /dev/ttyS7\n\n'
printf 'To load Doom WAD:\n\n'
printf '  ./doom/upload-wad.py  ./wads/DOOM1.WAD  --port /dev/ttyS7  --launch\n\n'
