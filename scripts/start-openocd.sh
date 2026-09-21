#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File:        start-openocd.sh
# Path:        scripts/start-openocd.sh
#
# Project:     Hazard3-Doom
# Purpose:     Start OpenOCD on Linux or WSL with the selected Hazard3-Doom
#              board configuration.
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

usage() {
    cat <<'EOF_USAGE'
Usage:
  ./scripts/start-openocd.sh [BOARD] [OPENOCD]
  ./scripts/start-openocd.sh [OPENOCD]
  ./scripts/start-openocd.sh -h | --help

Start the Hazard3-Doom OpenOCD server for BOARD.
The default board is ulx3s-85f.

Arguments:
  BOARD      Optional board/configuration selector:
               ulx3s-85f      openocd/ulx3s-85f-openocd.cfg (default)
               ulx3s-12f      openocd/ulx3s-12f-openocd.cfg
               ulx3s          openocd/ulx3s-openocd.cfg
                              compatibility auto-detect; no fixed work area
               ulx3s-doom     openocd/ulx3s-openocd-doom.cfg
                              compatibility auto-detect; no fixed work area
               ulx4m          openocd/ulx4m-openocd.cfg
               ulx4m-tigard   openocd/ulx4m-openocd-tigard.cfg
               icebreaker     openocd/icebreaker-openocd.cfg
             ulx4m-ld and ulx4m-ld-tigard are accepted aliases.
  OPENOCD    Optional OpenOCD executable path or command name.

Options:
  -h, --help Show this help and exit.

OpenOCD selection when OPENOCD is omitted:
  - Native Linux uses "openocd" from PATH.
  - WSL with Windows interop, a Windows-mounted repository, and
    bin/openocd.exe uses the bundled Windows executable.
  - Other WSL configurations use native "openocd" from PATH.

Examples:
  ./scripts/start-openocd.sh
  ./scripts/start-openocd.sh ulx3s-85f
  ./scripts/start-openocd.sh ulx3s-12f
  ./scripts/start-openocd.sh ulx4m
  ./scripts/start-openocd.sh ulx4m-tigard
  ./scripts/start-openocd.sh icebreaker
  ./scripts/start-openocd.sh /usr/local/bin/openocd
  ./scripts/start-openocd.sh ulx3s-85f ./bin/openocd.exe

The board-specific ULX3S selectors make the memory assumptions explicit.
Use ulx3s-85f or ulx3s-12f for normal board-specific debugging.
EOF_USAGE
}

BOARD="ulx3s-85f"
BOARD_WAS_DEFAULT=1

case "${1:-}" in
-h|--help)
    usage
    exit 0
    ;;
ulx3s-85f|ulx3s-12f|ulx3s|ulx3s-doom|ulx4m|ulx4m-ld|ulx4m-tigard|ulx4m-ld-tigard|icebreaker)
    BOARD="$1"
    BOARD_WAS_DEFAULT=0
    shift
    ;;
-*)
    printf 'ERROR: Unknown option: %s\n\n' "$1" >&2
    usage >&2
    exit 2
    ;;
esac

if (( $# > 1 )); then
    printf 'ERROR: Expected at most BOARD and OPENOCD arguments.\n\n' >&2
    usage >&2
    exit 2
fi

kernel_release="$(uname -r 2>/dev/null || true)"
IS_WSL=0
if [[ -n "${WSL_DISTRO_NAME:-}" || -n "${WSL_INTEROP:-}" ]] ||
    [[ "${kernel_release,,}" == *microsoft* ]]; then
    IS_WSL=1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

WSL_INTEROP_AVAILABLE=0
REPO_ON_WINDOWS_FS=0

if (( IS_WSL == 1 )); then
    if [[ -n "${WSL_INTEROP:-}" ]] ||
        [[ -e /proc/sys/fs/binfmt_misc/WSLInterop ]] ||
        command -v cmd.exe >/dev/null 2>&1; then
        WSL_INTEROP_AVAILABLE=1
    fi

    fs_type="$(stat -f -c '%T' "${ROOT_DIR}" 2>/dev/null || true)"

    case "${ROOT_DIR}" in
    /mnt/[a-zA-Z]|/mnt/[a-zA-Z]/*)
        REPO_ON_WINDOWS_FS=1
        ;;
    esac

    case "${fs_type}" in
    9p|drvfs)
        REPO_ON_WINDOWS_FS=1
        ;;
    esac
fi

if [[ $# -ge 1 ]]; then
    OPENOCD="$1"
elif (( IS_WSL == 1 && WSL_INTEROP_AVAILABLE == 1 && REPO_ON_WINDOWS_FS == 1 )) &&
    [[ -f "${ROOT_DIR}/bin/openocd.exe" ]]; then
    OPENOCD="${ROOT_DIR}/bin/openocd.exe"
else
    OPENOCD="openocd"
fi

case "${BOARD}" in
ulx3s-85f)
    OPENOCD_CONFIG="${ROOT_DIR}/openocd/ulx3s-85f-openocd.cfg"
    ;;
ulx3s-12f)
    OPENOCD_CONFIG="${ROOT_DIR}/openocd/ulx3s-12f-openocd.cfg"
    ;;
ulx3s)
    OPENOCD_CONFIG="${ROOT_DIR}/openocd/ulx3s-openocd.cfg"
    ;;
ulx3s-doom)
    OPENOCD_CONFIG="${ROOT_DIR}/openocd/ulx3s-openocd-doom.cfg"
    ;;
ulx4m|ulx4m-ld)
    OPENOCD_CONFIG="${ROOT_DIR}/openocd/ulx4m-openocd.cfg"
    ;;
ulx4m-tigard|ulx4m-ld-tigard)
    OPENOCD_CONFIG="${ROOT_DIR}/openocd/ulx4m-openocd-tigard.cfg"
    ;;
icebreaker)
    OPENOCD_CONFIG="${ROOT_DIR}/openocd/icebreaker-openocd.cfg"
    ;;
esac

if [[ "${OPENOCD}" == */* ]]; then
    if [[ ! -f "${OPENOCD}" ]]; then
        printf 'ERROR: OpenOCD not found:\n  %s\n' "${OPENOCD}" >&2
        exit 1
    fi
    OPENOCD_RESOLVED="${OPENOCD}"
elif ! OPENOCD_RESOLVED="$(command -v "${OPENOCD}")"; then
    printf 'ERROR: OpenOCD not found in PATH:\n  %s\n' "${OPENOCD}" >&2
    exit 1
fi

if [[ ! -f "${OPENOCD_CONFIG}" ]]; then
    printf 'ERROR: OpenOCD configuration not found:\n  %s\n' \
        "${OPENOCD_CONFIG}" >&2
    exit 1
fi

OPENOCD_CONFIG_ARG="${OPENOCD_CONFIG}"

if (( IS_WSL == 1 )); then
    if [[ "${OPENOCD,,}" == *.exe ]]; then
        if ! command -v wslpath >/dev/null 2>&1; then
            printf 'ERROR: wslpath is required when using Windows OpenOCD:\n  %s\n' \
                "${OPENOCD}" >&2
            exit 1
        fi

        OPENOCD_CONFIG_ARG="$(wslpath -w "${OPENOCD_CONFIG}")"
    fi
elif [[ "${OPENOCD,,}" == *.exe ]]; then
    printf 'ERROR: Windows OpenOCD cannot be used from native Linux:\n  %s\n' \
        "${OPENOCD}" >&2
    printf 'Install and use the native Linux OpenOCD executable instead.\n' >&2
    exit 1
fi

print_target_summary()
{
    local default_note=""

    if (( BOARD_WAS_DEFAULT == 1 )); then
        default_note=" (default)"
    fi

    printf 'Target selection:\n'
    printf '  Selector:       %s%s\n' "${BOARD}" "${default_note}"

    case "${BOARD}" in
    ulx3s-85f)
        printf '  Board:          ULX3S 85F\n'
        printf '  FPGA:           LFE5U-85F\n'
        printf '  JTAG IDCODE:    0x41113043\n'
        printf '  GDB server:     localhost:3333\n'
        printf '  Adapter:        onboard FT231X, ft232r bit-bang JTAG\n'
        printf '  Adapter speed:  1000 kHz OpenOCD setting\n'
        printf '\nMemory map:\n'
        printf '  Internal SRAM:  0x00000000-0x0001ffff  128 KiB\n'
        printf '    monitor/stack: 0x00000000-0x0000ffff\n'
        printf '    Doom screen:  0x00010000-0x0001f9ff\n'
        printf '    OpenOCD work: 0x0001fa00-0x0001ffff  0x600 bytes\n'
        printf '  SDRAM:          0x20000000-0x23ffffff  64 MiB\n'
        printf '    Doom image:   0x20100000-0x203fffff\n'
        printf '    Doom heap:    0x20400000-0x22bfffff\n'
        printf '    IWAD:         0x22c00000-0x23bfffff\n'
        printf '    video:        0x23c00000-0x23ffffff\n'
        printf '\nOpenOCD checksum work area:\n'
        printf '  0x0001fa00 size 0x600, backup enabled.\n'
        printf '  GDB compare-sections can use the target-side CRC helper.\n'
        ;;
    ulx3s-12f)
        printf '  Board:          ULX3S 12F\n'
        printf '  FPGA:           LFE5U-12F\n'
        printf '  JTAG IDCODE:    0x21111043\n'
        printf '  GDB server:     localhost:3333\n'
        printf '  Adapter:        onboard FT231X, ft232r bit-bang JTAG\n'
        printf '  Adapter speed:  1000 kHz OpenOCD setting\n'
        printf '\nMemory map:\n'
        printf '  Bootstrap SRAM: 0x00000000-0x000003ff  1 KiB\n'
        printf '  SDRAM:          0x20000000-0x21ffffff  32 MiB\n'
        printf '    monitor load: 0x20000040\n'
        printf '    Doom image:   0x20100000-0x203fffff\n'
        printf '    Doom heap:    0x20400000-0x20ffffff\n'
        printf '    IWAD:         0x21000000-0x21bfffff\n'
        printf '    video:        0x21c00000-0x21ffffff\n'
        printf '\nOpenOCD checksum work area:\n'
        printf '  none - the 85F internal-SRAM work area is not valid on the 12F.\n'
        printf '  compare-sections falls back to direct target reads.\n'
        printf '  OpenOCD may print a working-memory warning during that fallback.\n'
        ;;
    ulx3s|ulx3s-doom)
        printf '  Board:          ULX3S compatibility auto-detect\n'
        printf '  FPGA IDCODEs:   0x21111043 (12F), 0x41113043 (85F)\n'
        printf '  GDB server:     localhost:3333\n'
        printf '  Adapter:        onboard FT231X, ft232r bit-bang JTAG\n'
        printf '  Adapter speed:  1000 kHz OpenOCD setting\n'
        printf '\nMemory/work-area policy:\n'
        printf '  No fixed work area is configured because the 12F and 85F\n'
        printf '  internal-memory layouts differ. Use ulx3s-85f or ulx3s-12f\n'
        printf '  when the exact board is known.\n'
        ;;
    ulx4m|ulx4m-ld)
        printf '  Board:          ULX4M-LD\n'
        printf '  GDB server:     localhost:3333\n'
        printf '  Config:         ULX4M onboard debug path\n'
        ;;
    ulx4m-tigard|ulx4m-ld-tigard)
        printf '  Board:          ULX4M-LD\n'
        printf '  GDB server:     localhost:3333\n'
        printf '  Config:         external Tigard JTAG\n'
        ;;
    icebreaker)
        printf '  Board:          iCEBreaker\n'
        printf '  GDB server:     localhost:3333\n'
        ;;
    esac
}

printf 'Repository root:\n  %s\n\n' "${ROOT_DIR}"
print_target_summary
printf '\nOpenOCD executable:\n  %s\n\n' "${OPENOCD_RESOLVED}"
printf 'OpenOCD version:\n'
"${OPENOCD}" --version 2>&1 || true
printf '\nUsing config:\n  %s\n\n' "${OPENOCD_CONFIG_ARG}"
printf 'Starting OpenOCD...\n\n'

exec "${OPENOCD}" -d2 -f "${OPENOCD_CONFIG_ARG}"
