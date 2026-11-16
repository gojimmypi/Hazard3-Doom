#!/bin/bash
# -----------------------------------------------------------------------------
# File:        sweep-peek.sh
# Path:        scripts/sweep-peek.sh
#
# Project:     Hazard3-Doom
# Purpose:     Run placement-only ULX3S 85F nextpnr seed sweeps against one
#              synthesized netlist.
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

# Verify this script against the recorded inventory without blocking normal execution.
"$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/inventory.sh" \
    --check-file "${BASH_SOURCE[0]}" || true

# File: scripts/sweep-peek.sh
#
# Example:
#
#  SWEEP_JOBS=8 ./scripts/sweep-peek.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
HAZARD3_ROOT="${HAZARD3_ROOT:-${REPO_ROOT}/third_party/Hazard3}"
SYNTH_DIR="${HAZARD3_ROOT}/example_soc/synth"
BUILD_DIR="${REPO_ROOT}/build"
SWEEP_JOBS="${SWEEP_JOBS:-4}"
HAZARD3_HDMI_EXTENDED_MODES="${HAZARD3_HDMI_EXTENDED_MODES:-0}"
NETLIST="${BUILD_DIR}/fpga_ulx3s_85f.json"
SYNTH_LOG="${BUILD_DIR}/fpga_ulx3s_85f.synth.log"
SYNTH_PROFILE_STAMP="${BUILD_DIR}/fpga_ulx3s_85f.video-profile"
SYS_CLK_PROFILE_STAMP="${BUILD_DIR}/fpga_ulx3s_85f.sys-clk-mhz"
REGISTERED_HITS_PROFILE_STAMP="${BUILD_DIR}/fpga_ulx3s_85f.registered-read-hits"
SRAM_WRITE_BUFFER_PROFILE_STAMP="${BUILD_DIR}/fpga_ulx3s_85f.sram-write-buffer"
SRAM_DUAL_PORT_PROFILE_STAMP="${BUILD_DIR}/fpga_ulx3s_85f.sram-dual-port-rw"
CACHE_TAG_PIPELINE_PROFILE_STAMP="${BUILD_DIR}/fpga_ulx3s_85f.cache-tag-pipeline"
TAG_RAM_MODE_PROFILE_STAMP="${BUILD_DIR}/fpga_ulx3s_85f.tag-ram-mode"
CACHE_ADDR_PIPELINE_PROFILE_STAMP="${BUILD_DIR}/fpga_ulx3s_85f.cache-addr-pipeline"
MONITOR_SYS_CLK_STAMP="${BUILD_DIR}/ulx3s-85f/monitor-sys-clk-mhz"

# shellcheck source=scripts/ecp5-board-defaults.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/ecp5-board-defaults.sh"
ecp5_ulx3s_85f_clock_profile

# Shared system-clock detection also used by the fully routed ULX3S 85F sweep.
# shellcheck source=scripts/sweep-ecp5-common.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/sweep-ecp5-common.sh"

usage()
{
    echo "Usage: $0 [seed]" >&2
    echo "  no seed  Sweep seeds 1 through 260" >&2
    echo "  seed     Run placement-only check for one seed (1-2147483647)" >&2
    echo "  SWEEP_JOBS=N  Run up to N placement checks concurrently (default: 4)" >&2
    echo "  HAZARD3_HDMI_EXTENDED_MODES=0|1  Select standard or extended video profile (default: 0)" >&2
    echo "  HAZARD3_ULX3S_85F_SYS_CLK_MHZ=25|40|50  Select the actual system clock" >&2
    echo "  HAZARD3_ULX3S_85F_REGISTERED_READ_HITS=0|1  Register cache-hit responses"
    echo "  HAZARD3_ULX3S_85F_SRAM_WRITE_BUFFER=0|1  Buffer on-chip SRAM writes (default 1)" >&2
    echo "  HAZARD3_ULX3S_85F_SRAM_DUAL_PORT_RW=0|1  Independent SRAM R/W ports (default 0)" >&2
    echo "  HAZARD3_ULX3S_85F_CACHE_TAG_PIPELINE=0|1  Register cache tag-hit decision (default 0)" >&2
    echo "  HAZARD3_ULX3S_85F_TAG_RAM_MODE=0|1|2  Original / registered tag / split way RAM" >&2
    echo "  HAZARD3_ULX3S_85F_CACHE_ADDR_PIPELINE=0|1  Capture AHB address before cache RAM access" >&2
}

require_tool()
{
    local tool="$1"

    command -v "${tool}" >/dev/null 2>&1 || {
        echo "Missing required tool: ${tool}" >&2
        exit 1
    }
}

if (( $# > 1 )); then
    usage
    exit 1
fi

if [[ ! "${SWEEP_JOBS}" =~ ^[1-9][0-9]*$ ]]; then
    echo "Invalid SWEEP_JOBS: ${SWEEP_JOBS}; expected a positive integer." >&2
    usage
    exit 1
fi

case "${HAZARD3_HDMI_EXTENDED_MODES}" in
0)
    VIDEO_PROFILE="vga640-standard"
    ;;
1)
    VIDEO_PROFILE="vga640-extended"
    ;;
*)
    echo "HAZARD3_HDMI_EXTENDED_MODES must be 0 or 1" >&2
    usage
    exit 1
    ;;
esac

SWEEP_DIR="${BUILD_DIR}/ulx3s-placement-sweep/${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}mhz/${VIDEO_PROFILE}/rh${HAZARD3_ULX3S_85F_REGISTERED_READ_HITS}/swb${HAZARD3_ULX3S_85F_SRAM_WRITE_BUFFER}/dp${HAZARD3_ULX3S_85F_SRAM_DUAL_PORT_RW}/tagp${HAZARD3_ULX3S_85F_CACHE_TAG_PIPELINE}/trm${HAZARD3_ULX3S_85F_TAG_RAM_MODE}/cap${HAZARD3_ULX3S_85F_CACHE_ADDR_PIPELINE}"

if (( $# == 1 )); then
    seed_arg="$1"

    if ! sweep_ecp5_valid_seed "${seed_arg}"; then
        echo "Invalid seed: ${seed_arg}; expected 1-2147483647." >&2
        usage
        exit 1
    fi
    seed_arg="${REPLY}"

    seeds=("${seed_arg}")
    results_file="${SWEEP_DIR}/results-seed-${seed_arg}.csv"
else
    mapfile -t seeds < <(seq 1 260)
    results_file="${SWEEP_DIR}/results.csv"
fi

require_tool make
require_tool yosys
require_tool nextpnr-ecp5
require_tool sha256sum
mkdir -p "${BUILD_DIR}"

[[ -f "${SYNTH_DIR}/fpga_ulx3s.lpf" ]] || {
    echo "Missing ${SYNTH_DIR}/fpga_ulx3s.lpf" >&2
    exit 1
}

monitor_sys_clock=""
if [[ -f "${MONITOR_SYS_CLK_STAMP}" ]]; then
    read -r monitor_sys_clock < "${MONITOR_SYS_CLK_STAMP}" || true
fi
if [[ "${monitor_sys_clock}" != "${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}" ]]; then
    if [[ "${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}" != 25 || -n "${monitor_sys_clock}" ]]; then
        printf 'ERROR: ULX3S 85F monitor preload clock is %s; requested %s MHz.\n' \
            "${monitor_sys_clock:-unrecorded}" "${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}" >&2
        exit 1
    fi
    printf 'WARNING: Legacy 25 MHz monitor has no clock stamp; verify its provenance.\n' >&2
fi

netlist_sha256_before=""
if [[ -s "${NETLIST}" ]]; then
    netlist_sha256_before="$(sha256sum "${NETLIST}" | awk '{print $1}')"
fi

current_video_profile=""
if [[ -f "${SYNTH_PROFILE_STAMP}" ]]; then
    read -r current_video_profile < "${SYNTH_PROFILE_STAMP}" || true
fi
current_sys_clock=""
if [[ -f "${SYS_CLK_PROFILE_STAMP}" ]]; then
    read -r current_sys_clock < "${SYS_CLK_PROFILE_STAMP}" || true
fi

if [[ ! -s "${NETLIST}" ||
      "${current_video_profile}" != "${VIDEO_PROFILE}" ||
      "${current_sys_clock}" != "${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}" ||
      "$(cat "${REGISTERED_HITS_PROFILE_STAMP}" 2>/dev/null || true)" != "${HAZARD3_ULX3S_85F_REGISTERED_READ_HITS}" ||
      "$(cat "${SRAM_WRITE_BUFFER_PROFILE_STAMP}" 2>/dev/null || true)" != "${HAZARD3_ULX3S_85F_SRAM_WRITE_BUFFER}" ||
      "$(cat "${SRAM_DUAL_PORT_PROFILE_STAMP}" 2>/dev/null || true)" != "${HAZARD3_ULX3S_85F_SRAM_DUAL_PORT_RW}" ||
      "$(cat "${CACHE_TAG_PIPELINE_PROFILE_STAMP}" 2>/dev/null || true)" != "${HAZARD3_ULX3S_85F_CACHE_TAG_PIPELINE}" ||
      "$(cat "${TAG_RAM_MODE_PROFILE_STAMP}" 2>/dev/null || true)" != "${HAZARD3_ULX3S_85F_TAG_RAM_MODE}" ||
      "$(cat "${CACHE_ADDR_PIPELINE_PROFILE_STAMP}" 2>/dev/null || true)" != "${HAZARD3_ULX3S_85F_CACHE_ADDR_PIPELINE}" ]]; then
    if [[ -n "${current_video_profile}" &&
          "${current_video_profile}" != "${VIDEO_PROFILE}" ]]; then
        printf 'HDMI video profile changed: %s -> %s\n' \
            "${current_video_profile}" "${VIDEO_PROFILE}"
    elif [[ -s "${NETLIST}" ]]; then
        printf 'HDMI video profile is not recorded; rebuilding for %s mode.\n' \
            "${VIDEO_PROFILE}"
    else
        printf 'Synthesized ULX3S netlist is missing; building for %s mode.\n' \
            "${VIDEO_PROFILE}"
    fi

    if [[ "${current_sys_clock}" != "${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}" ]]; then
        printf 'System clock profile changed: %s -> %s MHz\n' \
            "${current_sys_clock:-unrecorded}" "${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}"
    fi
    rm -f \
        "${NETLIST}" \
        "${SYNTH_LOG}"
fi

printf 'ULX3S 85F profile: %s MHz, HDMI %s (extended modes=%s)\n' \
    "${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}" "${VIDEO_PROFILE}" "${HAZARD3_HDMI_EXTENDED_MODES}"

# Always ask make to ensure the synthesized netlist is current. This is a no-op
# when the selected profile and source dependencies are already up to date.
if make -C "${SYNTH_DIR}" -f ULX3S.mk \
    CHIPNAME="${BUILD_DIR}/fpga_ulx3s_85f" \
    HAZARD3_ULX3S_85F_SYS_CLK_MHZ="${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}" \
    HAZARD3_ULX3S_85F_REGISTERED_READ_HITS="${HAZARD3_ULX3S_85F_REGISTERED_READ_HITS}" \
    HAZARD3_ULX3S_85F_SRAM_WRITE_BUFFER="${HAZARD3_ULX3S_85F_SRAM_WRITE_BUFFER}" \
    HAZARD3_ULX3S_85F_SRAM_DUAL_PORT_RW="${HAZARD3_ULX3S_85F_SRAM_DUAL_PORT_RW}" \
    HAZARD3_ULX3S_85F_CACHE_TAG_PIPELINE="${HAZARD3_ULX3S_85F_CACHE_TAG_PIPELINE}" \
    HAZARD3_ULX3S_85F_TAG_RAM_MODE="${HAZARD3_ULX3S_85F_TAG_RAM_MODE}" \
    HAZARD3_ULX3S_85F_CACHE_ADDR_PIPELINE="${HAZARD3_ULX3S_85F_CACHE_ADDR_PIPELINE}" \
    HAZARD3_HDMI_EXTENDED_MODES="${HAZARD3_HDMI_EXTENDED_MODES}" synth; then
    synth_status=0
else
    synth_status=$?
fi
if [[ -f "${SYNTH_DIR}/synth.log" ]]; then
    mv -f "${SYNTH_DIR}/synth.log" "${SYNTH_LOG}"
fi
(( synth_status == 0 )) || exit "${synth_status}"

[[ -s "${NETLIST}" ]] || {
    echo "Synthesis completed without creating ${NETLIST}" >&2
    exit 1
}
[[ -s "${SYNTH_LOG}" ]] || {
    echo "Synthesis completed without creating ${SYNTH_LOG}" >&2
    exit 1
}

printf '%s\n' "${VIDEO_PROFILE}" > "${SYNTH_PROFILE_STAMP}"
printf '%s\n' "${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}" > "${SYS_CLK_PROFILE_STAMP}"
printf '%s\n' "${HAZARD3_ULX3S_85F_REGISTERED_READ_HITS}" > "${REGISTERED_HITS_PROFILE_STAMP}"
printf '%s\n' "${HAZARD3_ULX3S_85F_SRAM_WRITE_BUFFER}" > "${SRAM_WRITE_BUFFER_PROFILE_STAMP}"
printf '%s\n' "${HAZARD3_ULX3S_85F_SRAM_DUAL_PORT_RW}" > "${SRAM_DUAL_PORT_PROFILE_STAMP}"
printf '%s\n' "${HAZARD3_ULX3S_85F_CACHE_TAG_PIPELINE}" > "${CACHE_TAG_PIPELINE_PROFILE_STAMP}"
printf '%s\n' "${HAZARD3_ULX3S_85F_TAG_RAM_MODE}" > "${TAG_RAM_MODE_PROFILE_STAMP}"
printf '%s\n' "${HAZARD3_ULX3S_85F_CACHE_ADDR_PIPELINE}" > "${CACHE_ADDR_PIPELINE_PROFILE_STAMP}"

netlist_sha256="$(sha256sum "${NETLIST}" | awk '{print $1}')"
if [[ -n "${netlist_sha256_before}" &&
      "${netlist_sha256_before}" != "${netlist_sha256}" ]]; then
    printf 'Synthesized netlist changed; invalidating routed FPGA artifacts.\n'
    rm -f \
        "${BUILD_DIR}/fpga_ulx3s_85f.config" \
        "${BUILD_DIR}/fpga_ulx3s_85f.bit" \
        "${BUILD_DIR}/fpga_ulx3s_85f.svf"
fi

mkdir -p "${SWEEP_DIR}"

{
    printf 'video_profile=%s\n' "${VIDEO_PROFILE}"
    printf 'system_clock_mhz=%s\n' "${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}"
    printf 'registered_read_hits=%s\n' "${HAZARD3_ULX3S_85F_REGISTERED_READ_HITS}"
    printf 'sram_write_buffer=%s\n' "${HAZARD3_ULX3S_85F_SRAM_WRITE_BUFFER}"
    printf 'sram_dual_port_rw=%s\n' "${HAZARD3_ULX3S_85F_SRAM_DUAL_PORT_RW}"
    printf 'cache_tag_pipeline=%s\n' "${HAZARD3_ULX3S_85F_CACHE_TAG_PIPELINE}"
    printf 'tag_ram_mode=%s\n' "${HAZARD3_ULX3S_85F_TAG_RAM_MODE}"
    printf 'cache_addr_pipeline=%s\n' "${HAZARD3_ULX3S_85F_CACHE_ADDR_PIPELINE}"
    printf 'device=85k\n'
    printf 'speed=6\n'
    printf 'hazard3_hdmi_extended_modes=%s\n' "${HAZARD3_HDMI_EXTENDED_MODES}"
    printf 'netlist_sha256=%s\n' "${netlist_sha256}"
    printf 'netlist=fpga_ulx3s_85f.json\n'
    printf 'generated_utc=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
} > "${SWEEP_DIR}/metadata.txt"

printf 'Placement sweep netlist SHA256: %s\n' "${netlist_sha256}"
printf 'Placement sweep directory: %s\n' "${SWEEP_DIR}"

extract_clock()
{
    local log="$1"
    local clock="$2"
    local value

    value="$(
        grep "Max frequency for clock.*${clock}" "${log}" 2>/dev/null |
            tail -n 1 |
            sed -E 's/.*: ([0-9.]+) MHz.*/\1/' || true
    )"

    if [[ -z "${value}" ]]; then
        value="NA"
    fi

    printf '%s\n' "${value}"
}

run_seed()
{
    local seed="$1"
    local log="${SWEEP_DIR}/seed-${seed}.log"
    local result="${SWEEP_DIR}/result-seed-${seed}.csv"
    local clk_sys clk_video clk_tmds sys_clock

    echo "=== placement seed ${seed} ==="

    if ! nextpnr-ecp5 \
        --placer heap \
        --85k --speed 6 \
        --package CABGA381 \
        --lpf "${SYNTH_DIR}/fpga_ulx3s.lpf" \
        --json "${NETLIST}" \
        --seed "${seed}" \
        --timing-allow-fail \
        --no-route \
        >"${log}" 2>&1; then
        printf "%d,ERROR,ERROR,ERROR\n" "${seed}" > "${result}"
        echo "Seed ${seed}: nextpnr placement failed; see ${log}" >&2
        return 1
    fi

    # At 25 MHz clk_sys aliases the oscillator; 40/50 MHz use the system PLL.
    if ! sys_clock="$(sweep_ecp5_ulx3s_85f_system_clock "${log}")"; then
        printf '%d,ERROR,ERROR,ERROR\n' "${seed}" > "${result}"
        return 1
    fi
    clk_sys="$(extract_clock "${log}" "${sys_clock}")"
    clk_video="$(extract_clock "${log}" "clk_video_pix")"
    clk_tmds="$(extract_clock "${log}" "clk_tmds_x5")"

    printf "%d,%s,%s,%s\n" \
        "${seed}" "${clk_sys}" "${clk_video}" "${clk_tmds}" > "${result}"
    printf 'Seed %s system clock reported as %s\n' "${seed}" "${sys_clock}"
    cat "${result}"
}

for seed in "${seeds[@]}"; do
    rm -f "${SWEEP_DIR}/result-seed-${seed}.csv"
done

printf "Concurrent placement jobs: %s\n" "${SWEEP_JOBS}"

status=0
running=0

for seed in "${seeds[@]}"; do
    run_seed "${seed}" &
    running=$((running + 1))

    if (( running >= SWEEP_JOBS )); then
        if ! wait -n; then
            status=1
        fi
        running=$((running - 1))
    fi
done

while (( running > 0 )); do
    if ! wait -n; then
        status=1
    fi
    running=$((running - 1))
done

{
    printf "seed,clk_sys_mhz,clk_video_mhz,clk_tmds_mhz\n"
    for seed in "${seeds[@]}"; do
        result="${SWEEP_DIR}/result-seed-${seed}.csv"
        if [[ -f "${result}" ]]; then
            cat "${result}"
        else
            printf "%d,MISSING,MISSING,MISSING\n" "${seed}"
            status=1
        fi
    done
} > "${results_file}"

echo
echo "Results: ${results_file}"

exit "${status}"
