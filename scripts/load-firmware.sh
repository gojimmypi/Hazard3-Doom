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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
GDB="${GDB:-/opt/riscv/bin/riscv32-unknown-elf-gdb}"
ELF="${1:-${ROOT_DIR}/build/hazard3-boot-monitor.elf}"

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

if [[ ! -x "${GDB}" ]]; then
    echo "Missing RISC-V GDB executable: ${GDB}" >&2
    exit 1
fi

if [[ ! -f "${ELF}" ]]; then
    echo "Missing firmware ELF: ${ELF}" >&2
    echo "Run ${ROOT_DIR}/scripts/build.sh first or use the file in the prebuilt ./bin/ directory." >&2
    exit 1
fi

# The GDB expression $pc must be passed literally rather than expanded by Bash.
# shellcheck disable=SC2016
if "${GDB}" \
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
        "      (For Windows: WinUSB or libusbK, not FTDI)." \
        "" \
        "Useful checks:" \
        "  pgrep -af openocd" \
        "  ss -ltnp | grep ':3333'" \
        "" >&2

    exit "${rc}"
fi