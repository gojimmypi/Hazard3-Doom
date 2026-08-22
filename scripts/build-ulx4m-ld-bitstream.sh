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
BUILD_DIR="${REPO_ROOT}/build"
BITSTREAM_OUTPUT="${BUILD_DIR}/fpga_ulx4m_ld.bit"
CONFIG_OUTPUT="${BUILD_DIR}/fpga_ulx4m_ld.config"
SVF_OUTPUT="${BUILD_DIR}/fpga_ulx4m_ld.svf"
PNR_LOG="${BUILD_DIR}/fpga_ulx4m_ld.pnr.log"
SEED_STAMP="${BUILD_DIR}/fpga_ulx4m_ld.seed"
ALLOW_TIMING_FAILURE="${ALLOW_TIMING_FAILURE:-0}"
FORCE_BITSTREAM_REBUILD="${FORCE_BITSTREAM_REBUILD:-0}"


# $ NEXTPNR_SEED=232 \
# ALLOW_TIMING_FAILURE=1 \
# ./scripts/build-ulx4m-ld-bitstream.sh
# make: Entering directory '/mnt/c/workspace/Hazard3-Doom/third_party/Hazard3/example_soc/synth'
# make: Nothing to be done for 'synth'.
# make: Leaving directory '/mnt/c/workspace/Hazard3-Doom/third_party/Hazard3/example_soc/synth'
# nextpnr seed: 232
# WARNING: timing failure is allowed for this development build.
# Warning: Max frequency for clock   '$glbnet$soc_u.sdram_enabled.litedram_target.litedram_u.litedram_user_clk': 67.41 MHz (FAIL at 75.01 MHz)
# Warning: Max frequency for clock                                                            '$glbnet$clk_sys': 43.58 MHz (FAIL at 50.00 MHz)
# Warning: Trellis limitation: DRIVE can only be set on 3V3 IO pins.
# 3 warnings, 0 errors
# ULX4M-LD 85F bitstream: /mnt/c/workspace/Hazard3-Doom/build/fpga_ulx4m_ld.bit
# ULX4M-LD seed stamp: /mnt/c/workspace/Hazard3-Doom/build/fpga_ulx4m_ld.seed (seed 232)

NEXTPNR_SEED="${NEXTPNR_SEED:-232}"

# See scripts/sweep-ulx4m-ld.sh results:
#
# ULX4M-LD 85F routed seed sweep results, 1-260.
#
# No seed met both the 50.00 MHz clk_sys and 75.01 MHz LiteDRAM targets.
# Ranking below uses the best balanced timing result, i.e. the highest
# minimum normalized margin across all constrained clocks.
#
# | Rank | Seed | clk_sys | LiteDRAM | Video | TMDS   | Result |
# | ---: | ---: | ------: | -------: | ----: | -----: | :----- |
# |    1 |  163 | 44.10   | 66.55    | 61.80 | 319.59 | FAIL   |
# |    2 |  232 | 43.58   | 67.41    | 62.37 | 332.78 | FAIL   |
# |    3 |  200 | 43.44   | 65.71    | 58.96 | 321.03 | FAIL   |
# |    4 |  247 | 43.00   | 65.47    | 62.29 | 307.13 | FAIL   |
# |    5 |   20 | 42.97   | 64.49    | 61.15 | 313.28 | FAIL   |
# |    6 |  181 | 42.96   | 65.96    | 66.25 | 334.22 | FAIL   |
# |    7 |   50 | 42.77   | 67.61    | 60.94 | 302.66 | FAIL   |
# |    8 |  204 | 42.71   | 65.60    | 69.78 | 321.85 | FAIL   |
# |    9 |   17 | 42.66   | 68.88    | 69.68 | 318.67 | FAIL   |
# |   10 |   22 | 42.55   | 70.32    | 66.18 | 285.06 | FAIL   |
#
# Selected seed: 163
#   clk_sys:        44.10 MHz / 50.00 MHz = 88.2% of target
#   LiteDRAM user:  66.55 MHz / 75.01 MHz = 88.7% of target
#   clk_video_pix:  61.80 MHz / 50.00 MHz = PASS
#   clk_tmds_x5:   319.59 MHz / 250.00 MHz = PASS
#
# Seed 163 is also the highest clk_sys result in the complete 260-seed sweep.
# Further seed searching is therefore unlikely to close the remaining timing
# gap; the next improvement should target the ULX4M-LD critical paths.


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

mkdir -p "${BUILD_DIR}"

require_tool make
require_tool yosys
require_tool nextpnr-ecp5
require_tool ecppack
require_file "${HAZARD3_SYNTH}/ULX4M_LD_85F.mk"
require_file "${HAZARD3_SYNTH}/fpga_ulx4m_ld.lpf"
require_file "${LITEDRAM_DIR}/litedram_ulx4m_cpu.v"
require_file "${LITEDRAM_DIR}/litedram_ulx4m_cpu_rom.init"
require_file "${LITEDRAM_DIR}/litedram_ulx4m_cpu_sram.init"

# Yosys is called indirectly here. Always let make verify that the synthesized
# netlist is current before deciding whether an existing bitstream can be reused.
make -C "${HAZARD3_SYNTH}" -f ULX4M_LD_85F.mk synth

require_file "${HAZARD3_SYNTH}/fpga_ulx4m_ld.json"

recorded_seed=""
if [[ -f "${SEED_STAMP}" ]]; then
    read -r recorded_seed < "${SEED_STAMP}" || true
fi

require_tool stat
if [[ -s "${BITSTREAM_OUTPUT}" && "${FORCE_BITSTREAM_REBUILD}" == 0 ]]; then
    if [[ "${recorded_seed}" == "${NEXTPNR_SEED}" &&
          "${BITSTREAM_OUTPUT}" -nt "${HAZARD3_SYNTH}/fpga_ulx4m_ld.json" ]]; then
        printf 'Reusing existing ULX4M-LD 85F bitstream built with seed %s; nextpnr was not run.\n' \
            "${NEXTPNR_SEED}"
        stat -c '  %n (modified %y, %s bytes)' -- "${BITSTREAM_OUTPUT}"
        printf 'Set FORCE_BITSTREAM_REBUILD=1 to rebuild it.\n'
        exit 0
    fi

    if [[ -z "${recorded_seed}" ]]; then
        printf 'Existing ULX4M-LD bitstream has no seed stamp. Rebuilding with seed %s.\n' \
            "${NEXTPNR_SEED}"
    elif [[ "${recorded_seed}" != "${NEXTPNR_SEED}" ]]; then
        printf 'Existing ULX4M-LD bitstream used seed %s; requested seed is %s. Rebuilding.\n' \
            "${recorded_seed}" "${NEXTPNR_SEED}"
    else
        printf 'Synthesized ULX4M-LD netlist is newer than the existing bitstream. Rebuilding.\n'
    fi
fi

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
        --textcfg "${CONFIG_OUTPUT}" \
        "${timing_options[@]}" \
        --quiet \
        --log "${PNR_LOG}"

    ecppack \
        --compress \
        --svf "${SVF_OUTPUT}" \
        --idcode 0x01113043 \
        "${CONFIG_OUTPUT}" \
        "${BITSTREAM_OUTPUT}"
)

printf '%s\n' "${NEXTPNR_SEED}" > "${SEED_STAMP}"

# Remove legacy P&R outputs from the Hazard3 synth directory after a successful
# build so the integration-owned artifacts have one canonical location.
rm -f \
    "${HAZARD3_SYNTH}/fpga_ulx4m_ld.config" \
    "${HAZARD3_SYNTH}/fpga_ulx4m_ld.bit" \
    "${HAZARD3_SYNTH}/fpga_ulx4m_ld.svf" \
    "${HAZARD3_SYNTH}/pnr.log"

printf 'ULX4M-LD 85F bitstream: %s\n' \
    "${BITSTREAM_OUTPUT}"
printf 'ULX4M-LD seed stamp: %s (seed %s)\n' \
    "${SEED_STAMP}" "${NEXTPNR_SEED}"
