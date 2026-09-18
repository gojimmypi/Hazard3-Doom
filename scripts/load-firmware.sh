#!/bin/bash
# -----------------------------------------------------------------------------
# File:        load-firmware.sh
# Path:        scripts/load-firmware.sh
#
# Project:     Hazard3-Doom
# Purpose:     Load, verify, start, and disconnect the Hazard3 resident
#              monitor through GDB/OpenOCD.
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

if [[ -z "${GDB:-}" ]]; then
    if [[ -x /opt/riscv/bin/riscv32-unknown-elf-gdb ]]; then
        GDB="/opt/riscv/bin/riscv32-unknown-elf-gdb"
    elif command -v riscv-none-elf-gdb >/dev/null 2>&1; then
        GDB="riscv-none-elf-gdb"
    else
        echo "ERROR: RISC-V GDB not found" >&2
        exit 1
    fi
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

ELF="${1:-${ROOT_DIR}/build/hazard3-boot-monitor.elf}"

# Run shellcheck to ensure this is a good script.
# Specify the executable shell checker you want to use:
MY_SHELLCHECK="shellcheck"

# Check if the executable is available in the PATH
if command -v "$MY_SHELLCHECK" >/dev/null 2>&1; then
    "${MY_SHELLCHECK}" -x "${BASH_SOURCE[0]}" >&2 || exit 1
else
    echo "$MY_SHELLCHECK is not installed. Please install it if changes to this script have been made."
fi

if [[ "${GDB}" == */* ]]; then
    [[ -x "${GDB}" ]] || {
        echo "Missing RISC-V GDB executable: ${GDB}" >&2
        exit 1
    }
else
    command -v "${GDB}" >/dev/null 2>&1 || {
        echo "Missing RISC-V GDB executable on PATH: ${GDB}" >&2
        exit 1
    }
fi

if [[ ! -f "${ELF}" ]]; then
    echo "Missing firmware ELF: ${ELF}" >&2
    echo "Run a monitor build first, or pass the board-specific monitor ELF from build/<board>/monitor/." >&2
    exit 1
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

if ! openocd_ready; then
    printf '%s\n' \
        "ERROR: OpenOCD GDB server is not listening on localhost:3333." \
        "Start OpenOCD first, or use ./scripts/load-firmware-12f.sh for the ULX3S 12F automatic flow." \
        >&2
    exit 1
fi

is_12f_sdram_monitor()
{
    local header

    # The ULX3S 12F monitor is linked into SDRAM with entry 0x20000040.
    header="$(od -An -tx1 -N28 -- "${ELF}" 2>/dev/null | tr -d '[:space:]')" || return 1
    [[ "${header:0:8}" == "7f454c46" && "${header:48:8}" == "40000020" ]]
}

load_firmware_with_gdb()
{
    if is_12f_sdram_monitor; then
        command -v python3 >/dev/null 2>&1 || {
            echo "ERROR: python3 is required for ULX3S 12F direct-read verification." >&2
            return 1
        }
        printf '%s\n' 'Verifying ULX3S 12F monitor with direct target reads.'
        python3 "${SCRIPT_DIR}/load-firmware-direct-verify.py" \
            --gdb "${GDB}" \
            --work-dir "${ROOT_DIR}" \
            "${ELF}"
        return
    fi

    # The GDB expression $pc must be passed literally rather than expanded by Bash.
    # shellcheck disable=SC2016
    "${GDB}" \
        --batch \
        --quiet \
        "${ELF}" \
        -ex 'set confirm off' \
        -ex 'set pagination off' \
        -ex 'set remotetimeout 120' \
        -ex 'target extended-remote localhost:3333' \
        -ex 'monitor halt' \
        -ex 'load' \
        -ex 'compare-sections' \
        -ex 'set $pc = _start' \
        -ex 'monitor resume' \
        -ex 'disconnect'
}

if load_firmware_with_gdb
then
    : # gdb success
else
    rc=$?

    printf '%s\n' \
        "" \
        "ERROR: GDB failed (exit status ${rc})." \
        "" \
        "Check the following:" \
        "  - OpenOCD is running and listening on localhost:3333." \
        "  - OpenOCD successfully detected the FPGA/JTAG target." \
        "  - Another OpenOCD instance is not already running." \
        "  - PuTTY or another serial/JTAG application is not holding the device." \
        "  - Hazard3-Doom web console flasher is not connected." \
        "  - The ULX3S USB device US1 is connected and using the expected driver." \
        "      (For Windows OpenOCD: WinUSB or libusbK, not the FTDI FTDIBUS/D2XX driver)." \
        "      LIBUSB_ERROR_NOT_SUPPORTED usually means the FT231X is still bound to FTDIBUS/D2XX." \
        "      (For native Linux: verify OpenOCD udev/raw USB permissions)." \
        "      After installing OpenOCD on Linux, unplug and reconnect the ULX3S." \
        "" \
        "Useful checks:" \
        "  pgrep -af openocd" \
        "  ss -ltnp | grep ':3333'" \
        "  lsusb -d 0403:6015" \
        "" >&2

    exit "${rc}"
fi