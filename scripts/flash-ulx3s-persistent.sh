#!/bin/bash
# -----------------------------------------------------------------------------
# File:        flash-ulx3s-persistent.sh
# Path:        scripts/flash-ulx3s-persistent.sh
#
# Project:     Hazard3-Doom
# Purpose:     Program the built ULX3S 85F bitstream into persistent SPI
#              flash for cold boot.
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

#
# One-time persistent ULX3S programming for Hazard3-Doom cold boot.
# This uses the same direct SPI-flash target already present in ULX3S.mk.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
HAZARD3_ROOT="${HAZARD3_ROOT:-${ROOT_DIR}/third_party/Hazard3}"
BITSTREAM="${ROOT_DIR}/build/fpga_ulx3s.bit"

command -v ujprog >/dev/null 2>&1 || {
    echo "Missing required tool: ujprog" >&2
    exit 1
}

[[ -s "${BITSTREAM}" ]] || {
    echo "Missing bitstream: ${BITSTREAM}" >&2
    echo "Run ./scripts/build-ulx3s-doom.sh first." >&2
    exit 1
}

printf '%s\n' \
    "Programming the ULX3S configuration SPI flash with:" \
    "  ${BITSTREAM}" \
    "This is persistent programming, not the temporary SRAM/JTAG load."

ujprog -j flash "${BITSTREAM}"
printf 'Persistent ULX3S flash programming complete.\n'
