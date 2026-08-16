#!/bin/bash
#
# One-time persistent ULX3S programming for Hazard3-Doom cold boot.
# This uses the same direct SPI-flash target already present in ULX3S.mk.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
HAZARD3_ROOT="${HAZARD3_ROOT:-${ROOT_DIR}/third_party/Hazard3}"
BITSTREAM="${ROOT_DIR}/build/ulx3s/fpga_ulx3s.bit"

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
