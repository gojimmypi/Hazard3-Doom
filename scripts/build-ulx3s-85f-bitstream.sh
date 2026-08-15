#!/bin/bash
#
# file: scripts/build-ulx3s-85f-bitstream.sh
#
# Build the ULX3S 85F bitstream using nextpnr's analytical placer.
# The pinned fpgascripts submodule uses randomized SA placement, which
# routes this design extremely slowly.
#
# The third_party/Hazard3/scripts directory is an old, pinned submodule.
# Run nextpnr directly with its analytical placer and a fixed seed.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
HAZARD3_ROOT="${HAZARD3_ROOT:-${REPO_ROOT}/third_party/Hazard3}"
HAZARD3_SYNTH="${HAZARD3_ROOT}/example_soc/synth"
BITSTREAM_OUTPUT="${HAZARD3_SYNTH}/fpga_ulx3s.bit"
ALLOW_TIMING_FAILURE="${ALLOW_TIMING_FAILURE:-0}"
FORCE_BITSTREAM_REBUILD="${FORCE_BITSTREAM_REBUILD:-0}"

NEXTPNR_SEED="${NEXTPNR_SEED:-56}"
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
    printf '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n'
    printf 'Reusing existing ULX3S 85F bitstream in %s\n' "${BITSTREAM_OUTPUT}"
    printf 'nextpnr was not run!!!\n'
    stat -c 'bitstream:  %n (modified %y, %s bytes)' -- "${BITSTREAM_OUTPUT}"
    printf 'Set FORCE_BITSTREAM_REBUILD=1 to rebuild it.\n'
    printf '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n'
    exit 0
fi

require_tool make
require_tool yosys
require_tool nextpnr-ecp5
require_tool ecppack

# Yosys is called indirectly here.
make -C "${HAZARD3_SYNTH}" -f ULX3S.mk synth

# Run P&R directly instead of the pinned fpgascripts recipe.
(
    cd "${HAZARD3_SYNTH}"

    printf 'nextpnr seed: %s\n' "${NEXTPNR_SEED}"
    if [[ "${ALLOW_TIMING_FAILURE}" == 1 ]]; then
        printf 'WARNING: timing failure is allowed for this development build.\n' >&2
    fi

    nextpnr-ecp5 \
        --seed "${NEXTPNR_SEED}" \
        --placer heap \
        --um5g-85k \
        --package CABGA381 \
        --lpf fpga_ulx3s.lpf \
        --json fpga_ulx3s.json \
        --textcfg fpga_ulx3s.config \
        "${timing_options[@]}" \
        --quiet \
        --log pnr.log

    ecppack \
        --compress \
        --svf fpga_ulx3s.svf \
        --idcode 0x41113043 \
        fpga_ulx3s.config \
        fpga_ulx3s.bit
)

printf 'ULX3S 85F bitstream: %s\n' "${BITSTREAM_OUTPUT}"
