#!/bin/bash
# -----------------------------------------------------------------------------
# Build the Hazard3 ULX5M-GS GateMate A1 phase-1 bitstream.
# -----------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
HAZARD3_ROOT="${HAZARD3_ROOT:-${REPO_ROOT}/third_party/Hazard3}"
HAZARD3_SYNTH="${HAZARD3_ROOT}/example_soc/synth"
BUILD_DIR="${REPO_ROOT}/build/ulx5m-gs/fpga"
BITSTREAM_OUTPUT="${REPO_ROOT}/build/fpga_ulx5m_gs.bit"
PNR_LOG_OUTPUT="${REPO_ROOT}/build/fpga_ulx5m_gs.pnr.log"
CLOCK_OUTPUT="${REPO_ROOT}/build/fpga_ulx5m_gs.clock_mhz"
ALLOW_TIMING_FAILURE="${ALLOW_TIMING_FAILURE:-0}"
FORCE_BITSTREAM_REBUILD="${FORCE_BITSTREAM_REBUILD:-0}"
ULX5M_SYS_CLK_MHZ="${ULX5M_SYS_CLK_MHZ:-12}"

case "${ULX5M_SYS_CLK_MHZ}" in
12|20|25)
    ;;
*)
    echo "ULX5M_SYS_CLK_MHZ must be 12, 20 or 25" >&2
    exit 1
    ;;
esac

require_tool()
{
    local tool="$1"

    if ! command -v "${tool}" >/dev/null 2>&1; then
        printf 'Missing required tool: %s\n' "${tool}" >&2
        exit 1
    fi
}

require_file()
{
    local path="$1"

    if [[ ! -f "${path}" ]]; then
        printf 'Missing required file: %s\n' "${path}" >&2
        exit 1
    fi
}

case "${ALLOW_TIMING_FAILURE}" in
0)
    timing_option=""
    ;;
1)
    timing_option="--timing-allow-fail"
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

require_tool make
require_tool yosys
require_tool nextpnr-himbaechel
require_tool gmpack
require_tool install
require_file "${HAZARD3_SYNTH}/ULX5M_GS.mk"
require_file "${HAZARD3_SYNTH}/fpga_ulx5m_gs.ccf"
require_file "${HAZARD3_SYNTH}/fpga_ulx5m_gs.sdc"
require_file "${HAZARD3_ROOT}/example_soc/soc/hazard3-boot-monitor.hex"
require_file "${HAZARD3_ROOT}/example_soc/soc/cache_tags_zero_12f.hex"

if [[ -s "${BITSTREAM_OUTPUT}" && "${FORCE_BITSTREAM_REBUILD}" == 0 ]]; then
    existing_clock=""
    if [[ -f "${CLOCK_OUTPUT}" ]]; then
        existing_clock="$(tr -d '\r\n' < "${CLOCK_OUTPUT}")"
    fi

    if [[ "${existing_clock}" == "${ULX5M_SYS_CLK_MHZ}" ]]; then
        printf 'Reusing existing ULX5M-GS %s MHz bitstream: %s\n' \
            "${ULX5M_SYS_CLK_MHZ}" "${BITSTREAM_OUTPUT}"
        printf 'Set FORCE_BITSTREAM_REBUILD=1 to rebuild it.\n'
        exit 0
    fi

    printf 'Existing ULX5M-GS bitstream clock is %s; rebuilding for %s MHz.\n' \
        "${existing_clock:-unknown}" "${ULX5M_SYS_CLK_MHZ}"
fi

# The selected clock is a synthesis define. Always remove the per-target build
# directory before a rebuild so make cannot reuse a JSON or routed image from a
# different ULX5M_SYS_CLK_MHZ selection.
rm -rf -- "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}" "${REPO_ROOT}/build"

pnr_options="--placer-heap-beta=0.6"
if [[ -n "${timing_option}" ]]; then
    pnr_options+=" ${timing_option}"
fi

printf 'ULX5M-GS system clock: %s MHz\n' "${ULX5M_SYS_CLK_MHZ}"
make -C "${HAZARD3_SYNTH}" -f ULX5M_GS.mk \
    BUILD_DIR="${BUILD_DIR}" \
    ULX5M_SYS_CLK_MHZ="${ULX5M_SYS_CLK_MHZ}" \
    PNR_OPT="${pnr_options}" \
    bit

require_file "${BUILD_DIR}/fpga_ulx5m_gs.bit"
require_file "${BUILD_DIR}/pnr.log"
install -m 0644 "${BUILD_DIR}/fpga_ulx5m_gs.bit" "${BITSTREAM_OUTPUT}"
install -m 0644 "${BUILD_DIR}/pnr.log" "${PNR_LOG_OUTPUT}"
printf '%s\n' "${ULX5M_SYS_CLK_MHZ}" > "${CLOCK_OUTPUT}"

printf 'ULX5M-GS bitstream: %s\n' "${BITSTREAM_OUTPUT}"
printf 'PNR log:            %s\n' "${PNR_LOG_OUTPUT}"
