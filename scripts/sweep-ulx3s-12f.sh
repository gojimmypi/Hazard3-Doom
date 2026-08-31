#!/bin/bash
# -----------------------------------------------------------------------------
# File:        sweep-ulx3s-12f.sh
# Path:        scripts/sweep-ulx3s-12f.sh
#
# Project:     Hazard3-Doom
# Purpose:     Run fully routed ULX3S 12F nextpnr seed sweeps and record final
#              timing results.
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

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
HAZARD3_ROOT="${HAZARD3_ROOT:-${REPO_ROOT}/third_party/Hazard3}"
SYNTH_DIR="${HAZARD3_ROOT}/example_soc/synth"
COMMON_SCRIPT="${SCRIPT_DIR}/sweep-ecp5-common.sh"
SWEEP_JOBS="${SWEEP_JOBS:-4}"
SWEEP_SKIP_SYNTH="${SWEEP_SKIP_SYNTH:-0}"
SWEEP_PREPARE_ONLY="${SWEEP_PREPARE_ONLY:-0}"
HAZARD3_MEMORY_PROFILE="${HAZARD3_MEMORY_PROFILE:-32m}"

NETLIST="${SYNTH_DIR}/fpga_ulx3s_12f.json"
LPF="${SYNTH_DIR}/fpga_ulx3s.lpf"
MAKEFILE="${SYNTH_DIR}/ULX3S_12F.mk"
SYNTH_LOG="${SYNTH_DIR}/synth.log"
SYNTH_PROFILE_STAMP="${SYNTH_DIR}/fpga_ulx3s_12f.memory-profile"
SYNTH_DURATION_STAMP="${SYNTH_DIR}/fpga_ulx3s_12f.synth-seconds"

# shellcheck source=scripts/sweep-ecp5-common.sh
# shellcheck disable=SC1091
source "${COMMON_SCRIPT}"
printf 'Include source: %s\n' "${COMMON_SCRIPT}" >&2

sweep_ecp5_init_tuning
TUNING_SUFFIX="$(sweep_ecp5_tuning_suffix)"
SWEEP_DIR="${REPO_ROOT}/build/ulx3s-12f-seed-sweep/${HAZARD3_MEMORY_PROFILE}${TUNING_SUFFIX}"
SWEEP_REL_DIR="${SWEEP_DIR#"${REPO_ROOT}"/}"

usage()
{
    cat >&2 <<EOF_USAGE
Usage: $0 SEED [SEED ...]
       $0 SEED[,SEED...]
       $0 START-END
       $0 --all

Route one or more nextpnr seeds for the ULX3S 12F Hazard3-Doom build.
Seeds must be decimal values from 1 through 260.
SWEEP_JOBS=N runs up to N routes concurrently (default: 4).
HAZARD3_MEMORY_PROFILE=32m|64m selects the SDRAM profile (default: 32m).
SWEEP_SKIP_SYNTH=1 routes an already-frozen synthesized netlist.
SWEEP_ROUTE_TIMEOUT_SECONDS=N limits each nextpnr route (default: 7200).
EOF_USAGE
}

# Run ShellCheck when available.
MY_SHELLCHECK="${MY_SHELLCHECK:-shellcheck}"

if command -v "${MY_SHELLCHECK}" >/dev/null 2>&1; then
    (
        cd -- "${REPO_ROOT}"
        "${MY_SHELLCHECK}" -x "scripts/$(basename -- "${BASH_SOURCE[0]}")"
    ) || exit 1
else
    echo "${MY_SHELLCHECK} is not installed. Please install it if changes to this script have been made."
fi

if (( $# == 1 )) && [[ "$1" == "--print-sweep-dir" ]]; then
    printf '%s\n' "${SWEEP_REL_DIR}"
    exit 0
fi

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
case "${HAZARD3_MEMORY_PROFILE}" in
32m|64m) ;;
*) echo "HAZARD3_MEMORY_PROFILE must be 32m or 64m." >&2; exit 1 ;;
esac

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
sweep_ecp5_require_file "${LPF}"

synthesis_seconds="NA"
if [[ -f "${SYNTH_DURATION_STAMP}" ]]; then
    read -r synthesis_seconds < "${SYNTH_DURATION_STAMP}" || true
fi
if [[ ! "${synthesis_seconds}" =~ ^[0-9]+$ ]]; then
    synthesis_seconds="NA"
fi

if [[ "${SWEEP_SKIP_SYNTH}" == "1" ]]; then
    recorded_profile=""
    if [[ -f "${SYNTH_PROFILE_STAMP}" ]]; then
        read -r recorded_profile < "${SYNTH_PROFILE_STAMP}" || true
    fi
    if [[ "${recorded_profile}" != "${HAZARD3_MEMORY_PROFILE}" ]]; then
        echo "Frozen ULX3S 12F netlist memory profile does not match requested ${HAZARD3_MEMORY_PROFILE}." >&2
        exit 1
    fi
    printf 'Using existing synthesized ULX3S 12F netlist; synthesis skipped.\n'
else
    sweep_ecp5_require_tool make
    sweep_ecp5_require_tool yosys
    sweep_ecp5_require_file "${MAKEFILE}"
    sweep_ecp5_require_file "${HAZARD3_ROOT}/example_soc/soc/cache_tags_zero_12f.hex"
    sweep_ecp5_require_file "${HAZARD3_ROOT}/example_soc/soc/hazard3-12f-bootstrap.hex"

    current_profile=""
    if [[ -f "${SYNTH_PROFILE_STAMP}" ]]; then
        read -r current_profile < "${SYNTH_PROFILE_STAMP}" || true
    fi
    if [[ "${current_profile}" != "${HAZARD3_MEMORY_PROFILE}" ]]; then
        rm -f \
            "${NETLIST}" \
            "${SYNTH_DIR}/fpga_ulx3s_12f.config" \
            "${SYNTH_DIR}/fpga_ulx3s_12f.bit" \
            "${SYNTH_DIR}/fpga_ulx3s_12f.svf" \
            "${SYNTH_DURATION_STAMP}"
    fi

    printf 'ULX3S 12F profile: compact 320x200, %s SDRAM\n' \
        "${HAZARD3_MEMORY_PROFILE}"

    synth_start_seconds="$(date +%s)"
    make -C "${SYNTH_DIR}" -f ULX3S_12F.mk \
        HAZARD3_MEMORY_PROFILE="${HAZARD3_MEMORY_PROFILE}" \
        HAZARD3_HDMI_EXTENDED_MODES=0 synth
    synthesis_seconds="$(( $(date +%s) - synth_start_seconds ))"
    printf '%s\n' "${synthesis_seconds}" > "${SYNTH_DURATION_STAMP}"
    printf '%s\n' "${HAZARD3_MEMORY_PROFILE}" > "${SYNTH_PROFILE_STAMP}"
fi

[[ -s "${NETLIST}" ]] || {
    echo "Missing synthesized ULX3S 12F netlist: ${NETLIST}" >&2
    exit 1
}
[[ -s "${SYNTH_LOG}" ]] || {
    echo "Missing ULX3S 12F synthesis log: ${SYNTH_LOG}" >&2
    exit 1
}

ebr_used="$(awk '$2 == "DP16KD" {used=$1} END {print used}' "${SYNTH_LOG}")"
if [[ -z "${ebr_used}" ]]; then
    echo "ERROR: Could not determine ULX3S 12F DP16KD usage from synth.log." >&2
    exit 1
fi
if (( ebr_used > 32 )); then
    echo "ERROR: ULX3S 12F synthesis uses ${ebr_used} DP16KD blocks; LFE5U-12F limit is 32." >&2
    exit 1
fi
if grep -Fq "ulx3s_frame_ram\\BANK_COUNT=" "${SYNTH_LOG}"; then
    echo "ERROR: ULX3S 12F synthesized the full EBR framebuffer hierarchy." >&2
    exit 1
fi

netlist_sha256="$(sha256sum "${NETLIST}" | awk '{print $1}')"
mkdir -p "${SWEEP_DIR}"

{
    printf 'target=ulx3s-12f\n'
    printf 'device=12k\n'
    printf 'speed=6\n'
    printf 'package=CABGA381\n'
    printf 'full_route=1\n'
    printf 'result_columns=seed,clk_sys_mhz,clk_video_mhz,clk_tmds_mhz,route_seconds,timing_status\n'
    printf 'hazard3_memory_profile=%s\n' "${HAZARD3_MEMORY_PROFILE}"
    printf 'dp16kd_used=%s\n' "${ebr_used}"
    sweep_ecp5_write_tuning_metadata
    printf 'clk_sys_required_mhz=40.00\n'
    printf 'clk_video_required_mhz=50.00\n'
    printf 'clk_tmds_required_mhz=250.00\n'
    printf 'synthesis_seconds=%s\n' "${synthesis_seconds}"
    printf 'netlist_sha256=%s\n' "${netlist_sha256}"
    printf 'netlist=fpga_ulx3s_12f.json\n'
    printf 'generated_utc=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
} > "${SWEEP_DIR}/metadata.txt"

printf 'ULX3S 12F synthesis check: compact profile, %s/32 DP16KD.\n' "${ebr_used}"
printf 'ULX3S 12F synthesis duration: %s seconds\n' "${synthesis_seconds}"
printf 'ULX3S 12F routed sweep netlist SHA256: %s\n' "${netlist_sha256}"
printf 'ULX3S 12F routed sweep directory: %s\n' "${SWEEP_DIR}"

if [[ "${SWEEP_PREPARE_ONLY}" == "1" ]]; then
    printf 'ULX3S 12F frozen sweep netlist prepared; routing skipped.\n'
    exit 0
fi

sweep_ecp5_require_tool nextpnr-ecp5
sweep_ecp5_require_tool timeout
sweep_ecp5_require_tool ecppack

run_seed()
{
    local seed="$1"
    local pnr_log="${SWEEP_DIR}/pnr-${seed}.log"
    local failed_log="${SWEEP_DIR}/pnr-${seed}-failed.log"
    local config="${SWEEP_DIR}/fpga_ulx3s_12f-${seed}.config"
    local svf="${SWEEP_DIR}/fpga_ulx3s_12f-${seed}.svf"
    local bit="${SWEEP_DIR}/fpga_ulx3s_12f-${seed}.bit"
    local result="${SWEEP_DIR}/result-seed-${seed}.csv"
    local clk_sys clk_video clk_tmds route_start_seconds route_seconds route_status
    local clk_sys_status clk_video_status clk_tmds_status timing_status

    printf '\nTrying ULX3S 12F nextpnr seed %s\n' "${seed}"
    rm -f "${pnr_log}" "${failed_log}" "${config}" "${svf}" "${bit}" "${result}"

    route_start_seconds="$(date +%s)"
    if sweep_ecp5_run_nextpnr \
        --seed "${seed}" \
        "${SWEEP_NEXTPNR_ARGS[@]}" \
        --12k \
        --speed 6 \
        --package CABGA381 \
        --lpf "${LPF}" \
        --json "${NETLIST}" \
        --textcfg "${config}" \
        --timing-allow-fail \
        --quiet \
        --log "${pnr_log}"; then
        route_status=0
    else
        route_status=$?
    fi
    route_seconds="$(( $(date +%s) - route_start_seconds ))"

    case "${route_status}" in
    0)
        ;;
    124|137)
        printf '%d,TIMEOUT,TIMEOUT,TIMEOUT,%s,TIMEOUT\n' \
            "${seed}" "${route_seconds}" > "${result}"
        rm -f "${config}" "${svf}" "${bit}"
        printf 'Seed %s: routing timed out after %ss (kill grace %ss, status %s).\n' \
            "${seed}" "${SWEEP_ROUTE_TIMEOUT_SECONDS}" \
            "${SWEEP_ROUTE_KILL_AFTER_SECONDS}" "${route_status}" >&2
        return 0
        ;;
    *)
        printf '%d,ERROR,ERROR,ERROR,%s,ERROR\n' "${seed}" "${route_seconds}" > "${result}"
        [[ -f "${pnr_log}" ]] && mv "${pnr_log}" "${failed_log}"
        rm -f "${config}" "${svf}" "${bit}"
        printf 'Seed %s: nextpnr route failed with status %s.\n' \
            "${seed}" "${route_status}" >&2
        return 1
        ;;
    esac

    clk_sys="$(sweep_ecp5_extract_clock "${pnr_log}" "clk_sys")"
    clk_video="$(sweep_ecp5_extract_clock "${pnr_log}" "clk_video_pix")"
    clk_tmds="$(sweep_ecp5_extract_clock "${pnr_log}" "clk_tmds_x5")"
    clk_sys_status="$(sweep_ecp5_extract_clock_status "${pnr_log}" "clk_sys")"
    clk_video_status="$(sweep_ecp5_extract_clock_status "${pnr_log}" "clk_video_pix")"
    clk_tmds_status="$(sweep_ecp5_extract_clock_status "${pnr_log}" "clk_tmds_x5")"

    timing_status="FAIL"
    if [[ "${clk_sys_status}" == "PASS" &&
          "${clk_video_status}" == "PASS" &&
          "${clk_tmds_status}" == "PASS" ]]; then
        timing_status="PASS"
    fi

    if ! ecppack \
        --compress \
        --svf "${svf}" \
        --idcode 0x21111043 \
        "${config}" \
        "${bit}"; then
        printf '%d,%s,%s,%s,%s,PACK_ERROR\n' \
            "${seed}" "${clk_sys}" "${clk_video}" "${clk_tmds}" \
            "${route_seconds}" > "${result}"
        [[ -f "${pnr_log}" ]] && mv "${pnr_log}" "${failed_log}"
        rm -f "${config}" "${svf}" "${bit}"
        return 1
    fi

    printf '%d,%s,%s,%s,%s,%s\n' \
        "${seed}" "${clk_sys}" "${clk_video}" "${clk_tmds}" \
        "${route_seconds}" "${timing_status}" > "${result}"

    rm -f "${failed_log}" "${config}" "${svf}"
    printf 'Seed %s: clk_sys=%s MHz, clk_video=%s MHz, clk_tmds=%s MHz, route=%ss, %s\n' \
        "${seed}" "${clk_sys}" "${clk_video}" "${clk_tmds}" \
        "${route_seconds}" "${timing_status}"
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
    printf 'seed,clk_sys_mhz,clk_video_mhz,clk_tmds_mhz,route_seconds,timing_status\n'
    for seed in "${SWEEP_SEEDS[@]}"; do
        result="${SWEEP_DIR}/result-seed-${seed}.csv"
        if [[ -f "${result}" ]]; then
            cat "${result}"
        else
            printf '%d,MISSING,MISSING,MISSING,MISSING,MISSING\n' "${seed}"
            status=1
        fi
    done
} > "${results_file}"

pass_count="$(awk -F, 'NR > 1 && $6 == "PASS" {count++} END {print count + 0}' "${results_file}")"
pass_seeds="$(awk -F, 'NR > 1 && $6 == "PASS" {if (s != "") s=s ", "; s=s $1} END {print s}' "${results_file}")"
timeout_count="$(awk -F, 'NR > 1 && $6 == "TIMEOUT" {count++} END {print count + 0}' "${results_file}")"
timeout_seeds="$(awk -F, 'NR > 1 && $6 == "TIMEOUT" {if (s != "") s=s ", "; s=s $1} END {print s}' "${results_file}")"
printf '\nTiming-passing seeds: %s\n' "${pass_count}"
printf 'PASS seed values: %s\n' "${pass_seeds:-none}"
printf 'Timed-out seeds: %s\n' "${timeout_count}"
printf 'TIMEOUT seed values: %s\n' "${timeout_seeds:-none}"
printf 'Results: %s\n' "${results_file}"

exit "${status}"
