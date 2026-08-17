#!/bin/bash
#
# Copyright (c) 2026 gojimmypi
# SPDX-License-Identifier: Apache-2.0
#
# file: scripts/build-ulx4m-ld-bitstream.sh
#
# Build the ULX4M-LD 85F bitstream without modifying Hazard3's pinned
# fpgascripts submodule. Synthesis still uses the upstream makefile; P&R uses
# the analytical placer and a fixed seed owned by this integration project.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
HAZARD3_ROOT="${HAZARD3_ROOT:-${REPO_ROOT}/third_party/Hazard3}"
HAZARD3_SYNTH="${HAZARD3_ROOT}/example_soc/synth"
LITEDRAM_DIR="${HAZARD3_ROOT}/example_soc/third_party/LiteDRAM/generated"
BITSTREAM_OUTPUT="${HAZARD3_SYNTH}/fpga_ulx4m_ld.bit"
ALLOW_TIMING_FAILURE="${ALLOW_TIMING_FAILURE:-0}"
FORCE_BITSTREAM_REBUILD="${FORCE_BITSTREAM_REBUILD:-0}"

NEXTPNR_SEED="${NEXTPNR_SEED:-178}"

# See scripts/sweep.sh results:
#
# |   Seed |          `clk_sys` |
# | -----: | -----------------: |
# | **56** | **51.92 MHz PASS** |
# |    173 |     50.45 MHz PASS |
# |     76 |     50.40 MHz PASS |
# |     46 |     50.33 MHz PASS |
# |     33 |     50.31 MHz PASS |
# |    205 |     50.25 MHz PASS |
# |    201 |     50.16 MHz PASS |
# |     13 |     47.54 MHz      |
# | 809026061346936167   | 46.92 MHz |
# | 13174890808159154548 | 46.83 MHz |

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

    command -v "${tool}" >/dev/null 2>&1 || {
        echo "Missing required tool: ${tool}" >&2
        exit 1
    }
}

require_file()
{
    local path="$1"

    [[ -f "${path}" ]] || {
        echo "Missing required file: ${path}" >&2
        exit 1
    }
}

case "${ALLOW_TIMING_FAILURE}" in
0)
    timing_options=()
    ;;
1)
    timing_options=(--timing-allow-fail)
    ;;
*)
    echo "ALLOW_TIMING_FAILURE must be 0 or 1" >&2
    exit 1
    ;;
esac

case "${FORCE_BITSTREAM_REBUILD}" in
0|1)
    ;;
*)
    echo "FORCE_BITSTREAM_REBUILD must be 0 or 1" >&2
    exit 1
    ;;
esac

require_tool stat
if [[ -s "${BITSTREAM_OUTPUT}" && "${FORCE_BITSTREAM_REBUILD}" == 0 ]]; then
    printf 'Reusing existing ULX4M-LD 85F bitstream; nextpnr was not run.\n'
    stat -c '  %n (modified %y, %s bytes)' -- "${BITSTREAM_OUTPUT}"
    printf 'Set FORCE_BITSTREAM_REBUILD=1 to rebuild it.\n'
    exit 0
fi

require_tool make
require_tool yosys
require_tool nextpnr-ecp5
require_tool ecppack
require_file "${HAZARD3_SYNTH}/ULX4M_LD_85F.mk"
require_file "${HAZARD3_SYNTH}/fpga_ulx4m_ld.lpf"
require_file "${LITEDRAM_DIR}/litedram_ulx4m_cpu.v"
require_file "${LITEDRAM_DIR}/litedram_ulx4m_cpu_rom.init"
require_file "${LITEDRAM_DIR}/litedram_ulx4m_cpu_sram.init"

# Yosys is called indirectly here.
make -C "${HAZARD3_SYNTH}" -f ULX4M_LD_85F.mk synth

(
    cd "${HAZARD3_SYNTH}"

    printf 'nextpnr seed: %s\n' "${NEXTPNR_SEED}"
    if [[ "${ALLOW_TIMING_FAILURE}" == 1 ]]; then
        printf 'WARNING: timing failure is allowed for this development build.\n' >&2
    fi

    nextpnr-ecp5 \
        --seed "${NEXTPNR_SEED}" \
        --placer heap \
        --um-85k \
        --speed 8 \
        --package CABGA381 \
        --lpf fpga_ulx4m_ld.lpf \
        --json fpga_ulx4m_ld.json \
        --textcfg fpga_ulx4m_ld.config \
        "${timing_options[@]}" \
        --quiet \
        --log pnr.log

    ecppack \
        --compress \
        --svf fpga_ulx4m_ld.svf \
        --idcode 0x01113043 \
        fpga_ulx4m_ld.config \
        fpga_ulx4m_ld.bit
)

printf 'ULX4M-LD 85F bitstream: %s\n' \
    "${BITSTREAM_OUTPUT}"
