#!/bin/bash
# -----------------------------------------------------------------------------
# File:        sweep-ulx5m-gs.sh
# Path:        scripts/sweep-ulx5m-gs.sh
#
# Project:     Hazard3-Doom
# Purpose:     Run fully routed ULX5M-GS GateMate A1 nextpnr seed sweeps and
#              record final timing results.
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

"$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/inventory.sh" \
    --check-file "${BASH_SOURCE[0]}" || true

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
HAZARD3_ROOT="${HAZARD3_ROOT:-${REPO_ROOT}/third_party/Hazard3}"
SYNTH_DIR="${HAZARD3_ROOT}/example_soc/synth"
BUILD_DIR="${REPO_ROOT}/build"
SYNTH_BUILD_DIR="${BUILD_DIR}/ulx5m-gs/sweep-synth"
COMMON_SCRIPT="${SCRIPT_DIR}/sweep-ecp5-common.sh"
SWEEP_JOBS="${SWEEP_JOBS:-2}"
SWEEP_SKIP_SYNTH="${SWEEP_SKIP_SYNTH:-0}"
SWEEP_PREPARE_ONLY="${SWEEP_PREPARE_ONLY:-0}"
ULX5M_SYS_CLK_MHZ="${ULX5M_SYS_CLK_MHZ:-12}"
# shellcheck source=scripts/gatemate-board-defaults.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/gatemate-board-defaults.sh"
gatemate_board_defaults ulx5m-gs
SWEEP_ULX5M_HEAP_BETA="${SWEEP_ULX5M_HEAP_BETA:-${GATEMATE_DEFAULT_NEXTPNR_HEAP_BETA}}"
SWEEP_NEXTPNR_EXTRA_ARGS="${SWEEP_NEXTPNR_EXTRA_ARGS:-}"
SWEEP_ROUTE_TIMEOUT_SECONDS="${SWEEP_ROUTE_TIMEOUT_SECONDS:-7200}"
SWEEP_ROUTE_KILL_AFTER_SECONDS="${SWEEP_ROUTE_KILL_AFTER_SECONDS:-30}"
NETLIST="${SYNTH_BUILD_DIR}/fpga_ulx5m_gs.json"
SYNTH_LOG="${SYNTH_BUILD_DIR}/synth.log"
CCF="${SYNTH_DIR}/fpga_ulx5m_gs.ccf"
SDC="${SYNTH_DIR}/fpga_ulx5m_gs.sdc"

# shellcheck source=scripts/sweep-ecp5-common.sh
# shellcheck disable=SC1091
source "${COMMON_SCRIPT}"
echo "Include source: ${COMMON_SCRIPT}" >&2

beta_suffix="${SWEEP_ULX5M_HEAP_BETA//./p}"
SWEEP_DIR="${BUILD_DIR}/ulx5m-gs-seed-sweep-beta${beta_suffix}"
SWEEP_REL_DIR="${SWEEP_DIR#"${REPO_ROOT}"/}"

usage()
{
    cat >&2 <<EOF_USAGE
Usage: $0 SEED [SEED ...]
       $0 SEED[,SEED...]
       $0 START-END
       $0 --all

Route one or more nextpnr-himbaechel seeds for the ULX5M-GS GateMate A1
Hazard3-Doom build. Seeds must be decimal values from 1 through 260.
SWEEP_JOBS=N runs up to N routes concurrently (default: 2).
ULX5M_SYS_CLK_MHZ=N selects the system clock: 12, 20 or 25 (default: 12).
SWEEP_ULX5M_HEAP_BETA=N selects the HeAP beta value (default: ${GATEMATE_DEFAULT_NEXTPNR_HEAP_BETA}).
SWEEP_SKIP_SYNTH=1 routes an already-frozen synthesized netlist.
SWEEP_ROUTE_TIMEOUT_SECONDS=N limits each nextpnr route (default: 7200).
SWEEP_NEXTPNR_EXTRA_ARGS may contain additional whitespace-separated args.
EOF_USAGE
}

MY_SHELLCHECK="${MY_SHELLCHECK:-shellcheck}"
if command -v "${MY_SHELLCHECK}" >/dev/null 2>&1; then
    (
        cd -- "${REPO_ROOT}"
        "${MY_SHELLCHECK}" -x "scripts/$(basename -- "${BASH_SOURCE[0]}")"
    ) || exit 1
else
    echo "${MY_SHELLCHECK} is not installed. Please install it if changes to this script have been made." >&2
fi

if (( $# == 1 )) && [[ "$1" == "--print-sweep-dir" ]]; then
    printf '%s\n' "${SWEEP_REL_DIR}"
    exit 0
fi

case "${ULX5M_SYS_CLK_MHZ}" in
12|20|25) ;;
*) echo "ULX5M_SYS_CLK_MHZ must be 12, 20 or 25." >&2; exit 1 ;;
esac

case "${SWEEP_SKIP_SYNTH}" in
0|1) ;;
*) echo "SWEEP_SKIP_SYNTH must be 0 or 1." >&2; exit 1 ;;
esac
case "${SWEEP_PREPARE_ONLY}" in
0|1) ;;
*) echo "SWEEP_PREPARE_ONLY must be 0 or 1." >&2; exit 1 ;;
esac
if [[ ! "${SWEEP_JOBS}" =~ ^[1-9][0-9]*$ ]]; then
    echo "Invalid SWEEP_JOBS: ${SWEEP_JOBS}; expected a positive integer." >&2
    exit 1
fi
if [[ ! "${SWEEP_ULX5M_HEAP_BETA}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "SWEEP_ULX5M_HEAP_BETA must be a nonnegative decimal value." >&2
    exit 1
fi
if [[ ! "${SWEEP_ROUTE_TIMEOUT_SECONDS}" =~ ^[1-9][0-9]*$ ]]; then
    echo "SWEEP_ROUTE_TIMEOUT_SECONDS must be a positive integer." >&2
    exit 1
fi
if [[ ! "${SWEEP_ROUTE_KILL_AFTER_SECONDS}" =~ ^[1-9][0-9]*$ ]]; then
    echo "SWEEP_ROUTE_KILL_AFTER_SECONDS must be a positive integer." >&2
    exit 1
fi

if [[ "${SWEEP_PREPARE_ONLY}" != "1" ]]; then
    if (( $# == 0 )); then
        usage
        exit 1
    fi
    sweep_ecp5_parse_seeds usage "$@"
    results_file="$(sweep_ecp5_results_filename "${SWEEP_DIR}")"
fi

sweep_ecp5_require_tool sha256sum
sweep_ecp5_require_tool awk
sweep_ecp5_require_tool grep
sweep_ecp5_require_tool sed
sweep_ecp5_require_file "${CCF}"
sweep_ecp5_require_file "${SDC}"
mkdir -p "${BUILD_DIR}" "${SYNTH_BUILD_DIR}"

synthesis_seconds="NA"
if [[ "${SWEEP_SKIP_SYNTH}" == "1" ]]; then
    printf 'Using existing synthesized ULX5M-GS netlist; synthesis skipped.\n'
else
    sweep_ecp5_require_tool make
    sweep_ecp5_require_tool yosys

    rm -f "${NETLIST}" "${SYNTH_LOG}"
    synth_start_seconds="$(date +%s)"
    make -C "${SYNTH_DIR}" -f ULX5M_GS.mk \
        ULX5M_SYS_CLK_MHZ="${ULX5M_SYS_CLK_MHZ}" \
        BUILD_DIR="${SYNTH_BUILD_DIR}" \
        synth
    synthesis_seconds="$(( $(date +%s) - synth_start_seconds ))"
fi

[[ -s "${NETLIST}" ]] || {
    echo "Missing synthesized ULX5M-GS netlist: ${NETLIST}" >&2
    exit 1
}
[[ -s "${SYNTH_LOG}" ]] || {
    echo "Missing ULX5M-GS synthesis log: ${SYNTH_LOG}" >&2
    exit 1
}

netlist_sha256="$(sha256sum "${NETLIST}" | awk '{print $1}')"
mkdir -p "${SWEEP_DIR}"

{
    printf 'target=ulx5m-gs\n'
    printf 'device=CCGM1A1\n'
    printf 'full_route=1\n'
    printf 'result_columns=seed,clk_sys_mhz,route_seconds,timing_status\n'
    printf 'router=router2\n'
    printf 'placer=heap\n'
    printf 'placer_heap_beta=%s\n' "${SWEEP_ULX5M_HEAP_BETA}"
    printf 'extra_args=%s\n' "${SWEEP_NEXTPNR_EXTRA_ARGS}"
    printf 'route_timeout_seconds=%s\n' "${SWEEP_ROUTE_TIMEOUT_SECONDS}"
    printf 'route_kill_after_seconds=%s\n' "${SWEEP_ROUTE_KILL_AFTER_SECONDS}"
    printf 'clk_sys_required_mhz=%s.00\n' "${ULX5M_SYS_CLK_MHZ}"
    printf 'synthesis_seconds=%s\n' "${synthesis_seconds}"
    printf 'netlist_sha256=%s\n' "${netlist_sha256}"
    printf 'netlist=ulx5m-gs/sweep-synth/fpga_ulx5m_gs.json\n'
    printf 'ccf=fpga_ulx5m_gs.ccf\n'
    printf 'sdc=fpga_ulx5m_gs.sdc\n'
    printf 'generated_utc=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    if command -v nextpnr-himbaechel >/dev/null 2>&1; then
        printf 'nextpnr_version=%s\n' "$(nextpnr-himbaechel --version 2>&1 | head -n 1)"
    fi
} > "${SWEEP_DIR}/metadata.txt"

printf 'ULX5M-GS synthesis duration: %s seconds\n' "${synthesis_seconds}"
printf 'ULX5M-GS routed sweep netlist SHA256: %s\n' "${netlist_sha256}"
printf 'ULX5M-GS routed sweep directory: %s\n' "${SWEEP_DIR}"
printf 'ULX5M-GS system clock: %s MHz\n' "${ULX5M_SYS_CLK_MHZ}"
printf 'ULX5M-GS HeAP beta: %s\n' "${SWEEP_ULX5M_HEAP_BETA}"

if [[ "${SWEEP_PREPARE_ONLY}" == "1" ]]; then
    printf 'ULX5M-GS frozen sweep netlist prepared; routing skipped.\n'
    exit 0
fi

sweep_ecp5_require_tool nextpnr-himbaechel
sweep_ecp5_require_tool timeout
sweep_ecp5_require_tool gmpack

extra_args=()
if [[ -n "${SWEEP_NEXTPNR_EXTRA_ARGS}" ]]; then
    read -r -a extra_args <<< "${SWEEP_NEXTPNR_EXTRA_ARGS}"
fi

run_seed()
{
    local seed="$1"
    local log="${SWEEP_DIR}/pnr-${seed}.log"
    local impl="${SWEEP_DIR}/fpga_ulx5m_gs-${seed}.txt"
    local bit="${SWEEP_DIR}/fpga_ulx5m_gs-${seed}.bit"
    local result="${SWEEP_DIR}/result-seed-${seed}.csv"
    local clk_sys clk_sys_status timing_status
    local route_start_seconds route_start_time route_end_seconds route_end_time
    local route_seconds route_status

    printf '\nTrying ULX5M-GS nextpnr-himbaechel seed %s\n' "${seed}"
    rm -f "${log}" "${impl}" "${bit}" "${result}"

    route_start_seconds="$(date +%s)"
    route_start_time="$(date '+%Y-%m-%d %H:%M:%S %Z')"
    printf 'Seed %s route start: %s\n' "${seed}" "${route_start_time}"

    set +e
    timeout \
        --signal=TERM \
        --kill-after="${SWEEP_ROUTE_KILL_AFTER_SECONDS}s" \
        "${SWEEP_ROUTE_TIMEOUT_SECONDS}s" \
        nextpnr-himbaechel \
            --seed "${seed}" \
            --device CCGM1A1 \
            --json "${NETLIST}" \
            -o "ccf=${CCF}" \
            -o "out=${impl}" \
            --sdc "${SDC}" \
            --router router2 \
            --placer-heap-beta="${SWEEP_ULX5M_HEAP_BETA}" \
            --timing-allow-fail \
            "${extra_args[@]}" \
            -l "${log}"
    route_status=$?
    set -e

    route_end_seconds="$(date +%s)"
    route_end_time="$(date '+%Y-%m-%d %H:%M:%S %Z')"
    route_seconds="$((route_end_seconds - route_start_seconds))"

    printf 'Seed %s route end:   %s\n' "${seed}" "${route_end_time}"
    printf 'Seed %s route elapsed: %ss\n' "${seed}" "${route_seconds}"

    case "${route_status}" in
    0)
        ;;
    124|137)
        printf '%d,TIMEOUT,%s,TIMEOUT\n' \
            "${seed}" "${route_seconds}" > "${result}"
        rm -f "${impl}" "${bit}"
        printf 'Seed %s: routing timed out after %ss (kill grace %ss, status %s).\n' \
            "${seed}" "${SWEEP_ROUTE_TIMEOUT_SECONDS}" \
            "${SWEEP_ROUTE_KILL_AFTER_SECONDS}" "${route_status}" >&2
        return 0
        ;;
    *)
        printf '%d,ERROR,%s,ERROR\n' \
            "${seed}" "${route_seconds}" > "${result}"
        rm -f "${impl}" "${bit}"
        printf 'Seed %s: nextpnr-himbaechel route failed with status %s.\n' \
            "${seed}" "${route_status}" >&2
        return 1
        ;;
    esac

    clk_sys="$(sweep_ecp5_extract_clock "${log}" "clk_sys")"
    clk_sys_status="$(sweep_ecp5_extract_clock_status "${log}" "clk_sys")"
    timing_status="FAIL"
    if [[ "${clk_sys_status}" == "PASS" ]]; then
        timing_status="PASS"
    fi

    if [[ "${timing_status}" == "PASS" ]]; then
        if ! gmpack "${impl}" "${bit}"; then
            printf '%d,%s,%s,PACK_ERROR\n' \
                "${seed}" "${clk_sys}" "${route_seconds}" > "${result}"
            rm -f "${impl}" "${bit}"
            return 1
        fi
        printf 'Seed %s bitstream: %s\n' "${seed}" "${bit}"
    else
        rm -f "${bit}"
    fi

    printf '%d,%s,%s,%s\n' \
        "${seed}" "${clk_sys}" "${route_seconds}" "${timing_status}" > "${result}"
    rm -f "${impl}"
    cat "${result}"
}

for seed in "${SWEEP_SEEDS[@]}"; do
    rm -f "${SWEEP_DIR}/result-seed-${seed}.csv"
done

printf 'Routing %d seed(s):' "${#SWEEP_SEEDS[@]}"
printf ' %s' "${SWEEP_SEEDS[@]}"
printf '\nConcurrent route jobs: %s\n' "${SWEEP_JOBS}"
printf 'Per-seed nextpnr timeout: %ss (+%ss kill grace)\n' \
    "${SWEEP_ROUTE_TIMEOUT_SECONDS}" "${SWEEP_ROUTE_KILL_AFTER_SECONDS}"

status=0
running=0
for seed in "${SWEEP_SEEDS[@]}"; do
    run_seed "${seed}" &
    running=$((running + 1))
    if (( running >= SWEEP_JOBS )); then
        wait -n || status=1
        running=$((running - 1))
    fi
done
while (( running > 0 )); do
    wait -n || status=1
    running=$((running - 1))
done

{
    printf 'seed,clk_sys_mhz,route_seconds,timing_status\n'
    for seed in "${SWEEP_SEEDS[@]}"; do
        result="${SWEEP_DIR}/result-seed-${seed}.csv"
        if [[ -f "${result}" ]]; then
            cat "${result}"
        else
            printf '%d,MISSING,MISSING,MISSING\n' "${seed}"
            status=1
        fi
    done
} > "${results_file}"

pass_count="$(awk -F, 'NR > 1 && $4 == "PASS" {count++} END {print count + 0}' "${results_file}")"
pass_seeds="$(awk -F, 'NR > 1 && $4 == "PASS" {if (s != "") s=s ", "; s=s $1} END {print s}' "${results_file}")"
timeout_count="$(awk -F, 'NR > 1 && $4 == "TIMEOUT" {count++} END {print count + 0}' "${results_file}")"
timeout_seeds="$(awk -F, 'NR > 1 && $4 == "TIMEOUT" {if (s != "") s=s ", "; s=s $1} END {print s}' "${results_file}")"

printf 'Timing-passing seeds: %s\n' "${pass_count}"
printf 'Timing-passing seed values: %s\n' "${pass_seeds:-none}"
printf 'Timed-out seeds: %s\n' "${timeout_count}"
printf 'TIMEOUT seed values: %s\n' "${timeout_seeds:-none}"
printf 'Results: %s\n' "${results_file}"

exit "${status}"
