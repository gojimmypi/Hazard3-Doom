#!/bin/bash
# -----------------------------------------------------------------------------
# File:        sweep-ulx3s-85f.sh
# Path:        scripts/sweep-ulx3s-85f.sh
#
# Project:     Hazard3-Doom
# Purpose:     Run fully routed ULX3S 85F nextpnr seed sweeps and record final
#              timing results and bitstreams.
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
HAZARD3_HDMI_EXTENDED_MODES="${HAZARD3_HDMI_EXTENDED_MODES:-1}"
SYNTH_PROFILE_STAMP="${SYNTH_DIR}/fpga_ulx3s.video-profile"
NETLIST="${SYNTH_DIR}/fpga_ulx3s.json"
LPF="${SYNTH_DIR}/fpga_ulx3s.lpf"

# shellcheck source=scripts/sweep-ecp5-common.sh
# shellcheck disable=SC1091
source "${COMMON_SCRIPT}"
echo "Include source: ${COMMON_SCRIPT}"

sweep_ecp5_init_tuning
TUNING_SUFFIX="$(sweep_ecp5_tuning_suffix)"
SWEEP_DIR="${REPO_ROOT}/build/ulx3s-seed-sweep${TUNING_SUFFIX}"
SWEEP_REL_DIR="${SWEEP_DIR#"${REPO_ROOT}"/}"

usage()
{
    cat >&2 <<EOF_USAGE
Usage: $0 SEED [SEED ...]
       $0 SEED[,SEED...]
       $0 START-END
       $0 --all

Route one or more nextpnr seeds for the ULX3S 85F Hazard3-Doom build.
Seeds must be decimal values from 1 through 260.
SWEEP_JOBS=N runs up to N routes concurrently (default: 4).
HAZARD3_HDMI_EXTENDED_MODES=0|1 selects standard/extended video.
SWEEP_SKIP_SYNTH=1 routes an already-frozen synthesized netlist.
EOF_USAGE
}

# Run shellcheck to ensure this is a good script.
# Specify the executable shell checker you want to use:
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

case "${HAZARD3_HDMI_EXTENDED_MODES}" in
0) VIDEO_PROFILE="standard" ;;
1) VIDEO_PROFILE="extended" ;;
*) echo "HAZARD3_HDMI_EXTENDED_MODES must be 0 or 1." >&2; exit 1 ;;
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

if [[ "${SWEEP_SKIP_SYNTH}" == "1" ]]; then
    recorded_profile=""
    if [[ -f "${SYNTH_PROFILE_STAMP}" ]]; then
        read -r recorded_profile < "${SYNTH_PROFILE_STAMP}" || true
    fi
    if [[ "${recorded_profile}" != "${VIDEO_PROFILE}" ]]; then
        echo "Frozen ULX3S 85F netlist video profile does not match requested ${VIDEO_PROFILE}." >&2
        exit 1
    fi
    printf 'Using existing synthesized ULX3S 85F netlist; synthesis skipped.\n'
else
    sweep_ecp5_require_tool make
    sweep_ecp5_require_tool yosys

    current_profile=""
    if [[ -f "${SYNTH_PROFILE_STAMP}" ]]; then
        read -r current_profile < "${SYNTH_PROFILE_STAMP}" || true
    fi
    if [[ "${current_profile}" != "${VIDEO_PROFILE}" ]]; then
        rm -f \
            "${NETLIST}" \
            "${SYNTH_DIR}/fpga_ulx3s.config" \
            "${SYNTH_DIR}/fpga_ulx3s.bit" \
            "${SYNTH_DIR}/fpga_ulx3s.svf"
    fi

    printf 'ULX3S 85F HDMI video profile: %s (extended modes=%s)\n' \
        "${VIDEO_PROFILE}" "${HAZARD3_HDMI_EXTENDED_MODES}"

    make -C "${SYNTH_DIR}" -f ULX3S.mk \
        HAZARD3_HDMI_EXTENDED_MODES="${HAZARD3_HDMI_EXTENDED_MODES}" synth
    printf '%s\n' "${VIDEO_PROFILE}" > "${SYNTH_PROFILE_STAMP}"
fi

[[ -s "${NETLIST}" ]] || {
    echo "Missing synthesized ULX3S 85F netlist: ${NETLIST}" >&2
    exit 1
}

netlist_sha256="$(sha256sum "${NETLIST}" | awk '{print $1}')"
mkdir -p "${SWEEP_DIR}"

{
    printf 'target=ulx3s-85f\n'
    printf 'device=um5g-85k\n'
    printf 'package=CABGA381\n'
    printf 'full_route=1\n'
    printf 'result_columns=seed,clk_sys_mhz,clk_video_mhz,clk_tmds_mhz,timing_status\n'
    printf 'video_profile=%s\n' "${VIDEO_PROFILE}"
    sweep_ecp5_write_tuning_metadata
    printf 'clk_sys_required_mhz=50.00\n'
    printf 'clk_video_required_mhz=50.00\n'
    printf 'clk_tmds_required_mhz=250.00\n'
    printf 'netlist_sha256=%s\n' "${netlist_sha256}"
    printf 'netlist=fpga_ulx3s.json\n'
    printf 'generated_utc=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
} > "${SWEEP_DIR}/metadata.txt"

printf 'ULX3S 85F routed sweep netlist SHA256: %s\n' "${netlist_sha256}"
printf 'ULX3S 85F routed sweep directory: %s\n' "${SWEEP_DIR}"

if [[ "${SWEEP_PREPARE_ONLY}" == "1" ]]; then
    printf 'ULX3S 85F frozen sweep netlist prepared; routing skipped.\n'
    exit 0
fi

sweep_ecp5_require_tool nextpnr-ecp5
sweep_ecp5_require_tool ecppack

run_seed()
{
    local seed="$1"
    local pnr_log="${SWEEP_DIR}/pnr-${seed}.log"
    local failed_log="${SWEEP_DIR}/pnr-${seed}-failed.log"
    local config="${SWEEP_DIR}/fpga_ulx3s-${seed}.config"
    local svf="${SWEEP_DIR}/fpga_ulx3s-${seed}.svf"
    local bit="${SWEEP_DIR}/fpga_ulx3s-${seed}.bit"
    local result="${SWEEP_DIR}/result-seed-${seed}.csv"
    local clk_sys clk_video clk_tmds timing_status

    printf '\nTrying ULX3S 85F nextpnr seed %s\n' "${seed}"
    rm -f "${pnr_log}" "${failed_log}" "${config}" "${svf}" "${bit}" "${result}"

    if ! nextpnr-ecp5 \
        --seed "${seed}" \
        "${SWEEP_NEXTPNR_ARGS[@]}" \
        --um5g-85k \
        --package CABGA381 \
        --lpf "${LPF}" \
        --json "${NETLIST}" \
        --textcfg "${config}" \
        --timing-allow-fail \
        --quiet \
        --log "${pnr_log}"; then
        printf '%d,ERROR,ERROR,ERROR,ERROR\n' "${seed}" > "${result}"
        [[ -f "${pnr_log}" ]] && mv "${pnr_log}" "${failed_log}"
        rm -f "${config}" "${svf}" "${bit}"
        return 1
    fi

    clk_sys="$(sweep_ecp5_extract_clock "${pnr_log}" "clk_sys")"
    clk_video="$(sweep_ecp5_extract_clock "${pnr_log}" "clk_video_pix")"
    clk_tmds="$(sweep_ecp5_extract_clock "${pnr_log}" "clk_tmds_x5")"

    timing_status="FAIL"
    if sweep_ecp5_clock_at_least "${clk_sys}" 50.00 &&
       sweep_ecp5_clock_at_least "${clk_video}" 50.00 &&
       sweep_ecp5_clock_at_least "${clk_tmds}" 250.00; then
        timing_status="PASS"
    fi

    if ! ecppack \
        --compress \
        --svf "${svf}" \
        --idcode 0x41113043 \
        "${config}" \
        "${bit}"; then
        printf '%d,%s,%s,%s,PACK_ERROR\n' \
            "${seed}" "${clk_sys}" "${clk_video}" "${clk_tmds}" > "${result}"
        [[ -f "${pnr_log}" ]] && mv "${pnr_log}" "${failed_log}"
        rm -f "${config}" "${svf}" "${bit}"
        return 1
    fi

    printf '%d,%s,%s,%s,%s\n' \
        "${seed}" "${clk_sys}" "${clk_video}" "${clk_tmds}" "${timing_status}" \
        > "${result}"

    rm -f "${failed_log}" "${config}" "${svf}"
    printf 'Seed %s: clk_sys=%s MHz, clk_video=%s MHz, clk_tmds=%s MHz, %s\n' \
        "${seed}" "${clk_sys}" "${clk_video}" "${clk_tmds}" "${timing_status}"
}

for seed in "${SWEEP_SEEDS[@]}"; do
    rm -f "${SWEEP_DIR}/result-seed-${seed}.csv"
done

printf 'Routing %d seed(s):' "${#SWEEP_SEEDS[@]}"
printf ' %s' "${SWEEP_SEEDS[@]}"
printf '\nConcurrent route jobs: %s\n' "${SWEEP_JOBS}"

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
    printf 'seed,clk_sys_mhz,clk_video_mhz,clk_tmds_mhz,timing_status\n'
    for seed in "${SWEEP_SEEDS[@]}"; do
        result="${SWEEP_DIR}/result-seed-${seed}.csv"
        if [[ -f "${result}" ]]; then
            cat "${result}"
        else
            printf '%d,MISSING,MISSING,MISSING,MISSING\n' "${seed}"
            status=1
        fi
    done
} > "${results_file}"

pass_count="$(awk -F, 'NR > 1 && $5 == "PASS" {count++} END {print count + 0}' "${results_file}")"
pass_seeds="$(awk -F, 'NR > 1 && $5 == "PASS" {if (s != "") s=s ", "; s=s $1} END {print s}' "${results_file}")"
printf '\nTiming-passing seeds: %s\n' "${pass_count}"
printf 'PASS seed values: %s\n' "${pass_seeds:-none}"
printf 'Results: %s\n' "${results_file}"

exit "${status}"
