#!/bin/bash
# -----------------------------------------------------------------------------
# File:        load-firmware-12f.sh
# Path:        scripts/load-firmware-12f.sh
#
# Project:     Hazard3-Doom
# Purpose:     Start or reuse OpenOCD, then load the ULX3S 12F SDRAM-resident
#              monitor through GDB.
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

# Load the ULX3S 12F SDRAM-resident monitor after FPGA configuration.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
ELF="${1:-${ROOT_DIR}/build/ulx3s-12f/monitor/hazard3-boot-monitor.elf}"
OPENOCD_LOG="${HAZARD3_OPENOCD_LOG:-${ROOT_DIR}/build/ulx3s-12f/openocd.log}"
OPENOCD_PID=""

# Run ShellCheck to ensure this is a good script.
# Specify the executable shell checker you want to use:
MY_SHELLCHECK="shellcheck"

# Check if the executable is available in the PATH.
if command -v "${MY_SHELLCHECK}" >/dev/null 2>&1; then
    "${MY_SHELLCHECK}" -x "${BASH_SOURCE[0]}" >&2 || exit 1
else
    printf '%s\n' \
        "${MY_SHELLCHECK} is not installed. Please install it if changes to this script have been made." \
        >&2
fi

openocd_ready()
{
    local table

    # Inspect listener tables without connecting to the GDB server. A TCP
    # connect probe is visible to OpenOCD as a malformed GDB connection.
    for table in /proc/net/tcp /proc/net/tcp6; do
        [[ -r "${table}" ]] || continue
        if awk '
            NR > 1 && $4 == "0A" {
                split($2, address, ":")
                if (toupper(address[2]) == "0D05") {
                    found = 1
                    exit
                }
            }
            END { exit(found ? 0 : 1) }
        ' "${table}"; then
            return 0
        fi
    done

    # A Windows OpenOCD launched through WSL may not appear in WSL's /proc
    # socket tables. Query the Windows listener table as a passive fallback.
    if command -v netstat.exe >/dev/null 2>&1; then
        if netstat.exe -an -p tcp 2>/dev/null | awk '
            toupper($1) == "TCP" {
                state = toupper($NF)
                sub(/\r$/, "", state)
                if (state == "LISTENING" && $2 ~ /:3333$/) {
                    found = 1
                    exit
                }
            }
            END { exit(found ? 0 : 1) }
        '; then
            return 0
        fi
    fi

    return 1
}

cleanup()
{
    if [[ -n "${OPENOCD_PID}" ]] && kill -0 "${OPENOCD_PID}" 2>/dev/null; then
        kill "${OPENOCD_PID}" 2>/dev/null || true
        wait "${OPENOCD_PID}" 2>/dev/null || true
    fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [[ ! -f "${ELF}" ]]; then
    printf 'Missing firmware ELF: %s\n' "${ELF}" >&2
    printf 'Run ./scripts/build-ulx3s-12f-doom.sh first.\n' >&2
    exit 1
fi

if openocd_ready; then
    printf '%s\n' \
        'Reusing OpenOCD already listening on localhost:3333.' \
        'Expected target: ULX3S 12F or a compatible ULX3S auto-detect config.'
else
    mkdir -p "$(dirname -- "${OPENOCD_LOG}")"
    printf 'Starting OpenOCD for ULX3S 12F...\n'
    if [[ -n "${OPENOCD:-}" ]]; then
        "${SCRIPT_DIR}/start-openocd.sh" ulx3s-12f "${OPENOCD}" >"${OPENOCD_LOG}" 2>&1 &
    else
        "${SCRIPT_DIR}/start-openocd.sh" ulx3s-12f >"${OPENOCD_LOG}" 2>&1 &
    fi
    OPENOCD_PID=$!

    for _ in {1..50}; do
        if openocd_ready; then
            break
        fi
        if ! kill -0 "${OPENOCD_PID}" 2>/dev/null; then
            break
        fi
        sleep 0.2
    done

    if ! openocd_ready; then
        printf '%s\n' \
            "ERROR: OpenOCD did not start a GDB server on localhost:3333." \
            "OpenOCD log: ${OPENOCD_LOG}" \
            "" \
            "On Windows/WSL, LIBUSB_ERROR_NOT_SUPPORTED normally means the ULX3S FT231X" \
            "is still bound to the FTDI FTDIBUS/D2XX driver. Use Zadig to select WinUSB" \
            "or libusbK for OpenOCD. Windows fujprog uses the native FTDI driver, so" \
            "switching between fujprog and OpenOCD may require changing that driver." \
            >&2
        if [[ -f "${OPENOCD_LOG}" ]]; then
            printf '\nLast OpenOCD log lines:\n' >&2
            tail -n 20 "${OPENOCD_LOG}" >&2
        fi
        exit 1
    fi
fi

printf 'Loading ULX3S 12F monitor: %s\n' "${ELF}"
"${SCRIPT_DIR}/load-firmware.sh" "${ELF}"
printf 'ULX3S 12F monitor loaded and started.\n'
