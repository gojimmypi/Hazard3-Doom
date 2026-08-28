#!/bin/bash
# -----------------------------------------------------------------------------
# File:        sweep-ulx3s-12f.sh
# Path:        scripts/sweep-ulx3s-12f.sh
#
# Project:     Hazard3-Doom
# Purpose:     Run fully routed ULX3S 12F nextpnr seed sweeps and record
#              final timing results.
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

# File: scripts/sweep-ulx3s-12f.sh
#
# Route ULX3S 12F nextpnr seeds against one synthesized compact-profile
# netlist and record final routed clock timing. The netlist and LPF are
# read-only inputs while seed-specific routes may run concurrently.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
HAZARD3_ROOT="${HAZARD3_ROOT:-${REPO_ROOT}/third_party/Hazard3}"
SYNTH_DIR="${HAZARD3_ROOT}/example_soc/synth"
SWEEP_JOBS="${SWEEP_JOBS:-4}"
HAZARD3_MEMORY_PROFILE="${HAZARD3_MEMORY_PROFILE:-32m}"

NETLIST="${SYNTH_DIR}/fpga_ulx3s_12f.json"
LPF="${SYNTH_DIR}/fpga_ulx3s.lpf"
MAKEFILE="${SYNTH_DIR}/ULX3S_12F.mk"
SYNTH_LOG="${SYNTH_DIR}/synth.log"
SYNTH_PROFILE_STAMP="${SYNTH_DIR}/fpga_ulx3s_12f.memory-profile"
SWEEP_DIR="${REPO_ROOT}/build/ulx3s-12f-seed-sweep/${HAZARD3_MEMORY_PROFILE}"

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

Examples:
    $0 55
    $0 1 12 26 33 46 55
    $0 1,12,26,33,46,55
    $0 1-32
    SWEEP_JOBS=8 $0 --all
EOF_USAGE
}

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

append_seed()
{
    local seed_value="$1"

    if (( seed_value < 1 || seed_value > 260 )); then
        echo "Invalid seed: ${seed_value}; expected a decimal value from 1 through 260." >&2
        usage
        exit 1
    fi

    if [[ -z "${seen_seeds[${seed_value}]+x}" ]]; then
        seeds+=("${seed_value}")
        seen_seeds["${seed_value}"]=1
    fi
}

extract_clock()
{
    local log="$1"
    local clock="$2"
    local value

    # nextpnr reports timing after placement and again after routing. Keep the
    # final match so the CSV contains routed, not placement-only, timing.
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

clock_at_least()
{
    local value="$1"
    local minimum="$2"

    [[ "${value}" =~ ^[0-9]+([.][0-9]+)?$ ]] || return 1
    awk -v value="${value}" -v minimum="${minimum}" \
        'BEGIN { exit !(value >= minimum) }'
}

if (( $# == 0 )); then
    usage
    exit 1
fi

if [[ ! "${SWEEP_JOBS}" =~ ^[1-9][0-9]*$ ]]; then
    echo "Invalid SWEEP_JOBS: ${SWEEP_JOBS}; expected a positive integer." >&2
    usage
    exit 1
fi

case "${HAZARD3_MEMORY_PROFILE}" in
32m|64m)
    ;;
*)
    echo "HAZARD3_MEMORY_PROFILE must be 32m or 64m." >&2
    exit 1
    ;;
esac

seeds=()
declare -A seen_seeds=()

if (( $# == 1 )) && [[ "$1" == "--all" ]]; then
    mapfile -t seeds < <(seq 1 260)
    results_file="${SWEEP_DIR}/results.csv"
else
    for arg in "$@"; do
        if [[ "${arg}" == "--all" ]]; then
            echo "--all cannot be combined with explicit seeds." >&2
            usage
            exit 1
        fi

        IFS=',' read -r -a arg_seeds <<< "${arg}"
        for seed_arg in "${arg_seeds[@]}"; do
            if [[ "${seed_arg}" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                seed_first=$((10#${BASH_REMATCH[1]}))
                seed_last=$((10#${BASH_REMATCH[2]}))

                if (( seed_first < 1 || seed_first > 260 ||
                      seed_last < 1 || seed_last > 260 ||
                      seed_first > seed_last )); then
                    echo "Invalid seed range: ${seed_arg}; expected start-end within 1-260." >&2
                    usage
                    exit 1
                fi

                while (( seed_first <= seed_last )); do
                    append_seed "${seed_first}"
                    seed_first=$((seed_first + 1))
                done
            elif [[ "${seed_arg}" =~ ^[0-9]+$ ]]; then
                append_seed "$((10#${seed_arg}))"
            else
                echo "Invalid seed: ${seed_arg}; expected 1-260 or a range such as 1-32." >&2
                usage
                exit 1
            fi
        done
    done

    if (( ${#seeds[@]} == 1 )); then
        results_file="${SWEEP_DIR}/results-seed-${seeds[0]}.csv"
    else
        results_file="${SWEEP_DIR}/results-selected.csv"
    fi
fi

require_tool make
require_tool yosys
require_tool nextpnr-ecp5
require_tool ecppack
require_tool sha256sum
require_tool awk
require_tool grep
require_tool sed
require_file "${MAKEFILE}"
require_file "${LPF}"
require_file "${HAZARD3_ROOT}/example_soc/soc/cache_tags_zero_12f.hex"
require_file "${HAZARD3_ROOT}/example_soc/soc/hazard3-12f-bootstrap.hex"

mkdir -p "${SWEEP_DIR}"

current_profile=""
if [[ -f "${SYNTH_PROFILE_STAMP}" ]]; then
    read -r current_profile < "${SYNTH_PROFILE_STAMP}" || true
fi

if [[ "${current_profile}" != "${HAZARD3_MEMORY_PROFILE}" ]]; then
    if [[ -n "${current_profile}" ]]; then
        printf 'ULX3S 12F SDRAM profile changed: %s -> %s\n' \
            "${current_profile}" "${HAZARD3_MEMORY_PROFILE}"
    else
        printf 'ULX3S 12F SDRAM profile is not recorded; rebuilding for %s.\n' \
            "${HAZARD3_MEMORY_PROFILE}"
    fi

    rm -f \
        "${NETLIST}" \
        "${SYNTH_DIR}/fpga_ulx3s_12f.config" \
        "${SYNTH_DIR}/fpga_ulx3s_12f.bit" \
        "${SYNTH_DIR}/fpga_ulx3s_12f.svf"
fi

netlist_sha256_before=""
if [[ -s "${NETLIST}" ]]; then
    netlist_sha256_before="$(sha256sum "${NETLIST}" | awk '{print $1}')"
fi

printf 'ULX3S 12F profile: compact 320x200, %s SDRAM\n' \
    "${HAZARD3_MEMORY_PROFILE}"

# Synthesize once before starting concurrent routes. make tracks the Verilog,
# compact cache-tag preload, bootstrap preload, and memory-profile inputs. This
# is a no-op when the existing synthesized netlist is already current.
make -C "${SYNTH_DIR}" -f ULX3S_12F.mk \
    HAZARD3_MEMORY_PROFILE="${HAZARD3_MEMORY_PROFILE}" \
    HAZARD3_HDMI_EXTENDED_MODES=0 synth

[[ -s "${NETLIST}" ]] || {
    echo "Synthesis completed without creating ${NETLIST}" >&2
    exit 1
}

[[ -s "${SYNTH_LOG}" ]] || {
    echo "Synthesis completed without creating ${SYNTH_LOG}" >&2
    exit 1
}

printf '%s\n' "${HAZARD3_MEMORY_PROFILE}" > "${SYNTH_PROFILE_STAMP}"

ebr_used="$(
    awk '$2 == "DP16KD" {used=$1} END {print used}' "${SYNTH_LOG}"
)"
if [[ -z "${ebr_used}" ]]; then
    echo "ERROR: Could not determine ULX3S 12F DP16KD usage from synth.log." >&2
    exit 1
fi
if (( ebr_used > 32 )); then
    echo "ERROR: ULX3S 12F synthesis uses ${ebr_used} DP16KD blocks; LFE5U-12F limit is 32." >&2
    echo "The 12F build must use the compact SDRAM scanout/cache profile before nextpnr." >&2
    exit 1
fi
if grep -Fq "ulx3s_frame_ram\\BANK_COUNT=" "${SYNTH_LOG}"; then
    echo "ERROR: ULX3S 12F synthesized the full EBR framebuffer hierarchy." >&2
    echo "Expected ulx3s_hdmi_sdram_scanout selected by HAZARD3_ULX3S_12F." >&2
    exit 1
fi

printf 'ULX3S 12F synthesis check: compact profile, %s/32 DP16KD.\n' \
    "${ebr_used}"

netlist_sha256="$(sha256sum "${NETLIST}" | awk '{print $1}')"
if [[ -n "${netlist_sha256_before}" &&
      "${netlist_sha256_before}" != "${netlist_sha256}" ]]; then
    printf 'Synthesized ULX3S 12F netlist changed; sweep will use the new netlist.\n'
fi

{
    printf 'target=ulx3s-12f\n'
    printf 'device=12k\n'
    printf 'package=CABGA381\n'
    printf 'placer=heap\n'
    printf 'full_route=1\n'
    printf 'hazard3_memory_profile=%s\n' "${HAZARD3_MEMORY_PROFILE}"
    printf 'clk_sys_required_mhz=40.00\n'
    printf 'clk_video_required_mhz=50.00\n'
    printf 'clk_tmds_required_mhz=250.00\n'
    printf 'dp16kd_used=%s\n' "${ebr_used}"
    printf 'netlist_sha256=%s\n' "${netlist_sha256}"
    printf 'netlist=fpga_ulx3s_12f.json\n'
    printf 'generated_utc=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
} > "${SWEEP_DIR}/metadata.txt"

printf 'ULX3S 12F routed sweep netlist SHA256: %s\n' "${netlist_sha256}"
printf 'ULX3S 12F routed sweep directory: %s\n' "${SWEEP_DIR}"
printf 'Routing %d seed(s):' "${#seeds[@]}"
printf ' %s' "${seeds[@]}"
printf '\n'
printf 'Concurrent route jobs: %s\n' "${SWEEP_JOBS}"

run_seed()
{
    local seed="$1"
    local pnr_log="${SWEEP_DIR}/pnr-${seed}.log"
    local failed_log="${SWEEP_DIR}/pnr-${seed}-failed.log"
    local config="${SWEEP_DIR}/fpga_ulx3s_12f-${seed}.config"
    local svf="${SWEEP_DIR}/fpga_ulx3s_12f-${seed}.svf"
    local bit="${SWEEP_DIR}/fpga_ulx3s_12f-${seed}.bit"
    local result="${SWEEP_DIR}/result-seed-${seed}.csv"
    local clk_sys clk_video clk_tmds timing_status

    printf '\nTrying nextpnr seed %s\n' "${seed}"

    # Prevent an unsuccessful rerun from being mistaken for artifacts from an
    # earlier run of the same seed.
    rm -f \
        "${pnr_log}" \
        "${failed_log}" \
        "${config}" \
        "${svf}" \
        "${bit}" \
        "${result}"

    if ! nextpnr-ecp5 \
        --seed "${seed}" \
        --placer heap \
        --12k \
        --speed 6 \
        --package CABGA381 \
        --lpf "${LPF}" \
        --json "${NETLIST}" \
        --textcfg "${config}" \
        --timing-allow-fail \
        --quiet \
        --log "${pnr_log}"; then
        printf '%d,ERROR,ERROR,ERROR,ERROR\n' "${seed}" > "${result}"
        printf 'Seed %s nextpnr failed; see %s\n' "${seed}" "${pnr_log}" >&2
        if [[ -f "${pnr_log}" ]]; then
            mv "${pnr_log}" "${failed_log}"
        fi
        rm -f "${config}" "${svf}" "${bit}"
        return 1
    fi

    clk_sys="$(extract_clock "${pnr_log}" "clk_sys")"
    clk_video="$(extract_clock "${pnr_log}" "clk_video_pix")"
    clk_tmds="$(extract_clock "${pnr_log}" "clk_tmds_x5")"

    timing_status="FAIL"
    if clock_at_least "${clk_sys}" 40.00 &&
       clock_at_least "${clk_video}" 50.00 &&
       clock_at_least "${clk_tmds}" 250.00; then
        timing_status="PASS"
    fi

    if ! ecppack \
        --compress \
        --svf "${svf}" \
        --idcode 0x21111043 \
        "${config}" \
        "${bit}"; then
        printf '%d,%s,%s,%s,PACK_ERROR\n' \
            "${seed}" "${clk_sys}" "${clk_video}" "${clk_tmds}" > "${result}"
        printf 'Seed %s ecppack failed.\n' "${seed}" >&2
        if [[ -f "${pnr_log}" ]]; then
            mv "${pnr_log}" "${failed_log}"
        fi
        rm -f "${config}" "${svf}" "${bit}"
        return 1
    fi

    if [[ ! -s "${pnr_log}" || ! -s "${bit}" ]]; then
        printf '%d,%s,%s,%s,ARTIFACT_ERROR\n' \
            "${seed}" "${clk_sys}" "${clk_video}" "${clk_tmds}" > "${result}"
        printf 'Seed %s completed but expected artifacts are missing or empty.\n' \
            "${seed}" >&2
        if [[ -f "${pnr_log}" ]]; then
            mv "${pnr_log}" "${failed_log}"
        fi
        rm -f "${config}" "${svf}" "${bit}"
        return 1
    fi

    printf '%d,%s,%s,%s,%s\n' \
        "${seed}" "${clk_sys}" "${clk_video}" "${clk_tmds}" "${timing_status}" \
        > "${result}"

    # Match scripts/sweep.sh: retain the useful routed log and testable bitstream,
    # but remove intermediate config/SVF files.
    rm -f "${failed_log}" "${config}" "${svf}"

    printf 'Seed %s: clk_sys=%s MHz, clk_video=%s MHz, clk_tmds=%s MHz, %s\n' \
        "${seed}" "${clk_sys}" "${clk_video}" "${clk_tmds}" "${timing_status}"
}

for seed in "${seeds[@]}"; do
    rm -f "${SWEEP_DIR}/result-seed-${seed}.csv"
done

run_status=0
running=0

for seed in "${seeds[@]}"; do
    run_seed "${seed}" &
    running=$((running + 1))

    if (( running >= SWEEP_JOBS )); then
        if ! wait -n; then
            run_status=1
        fi
        running=$((running - 1))
    fi
done

while (( running > 0 )); do
    if ! wait -n; then
        run_status=1
    fi
    running=$((running - 1))
done

{
    printf 'seed,clk_sys_mhz,clk_video_mhz,clk_tmds_mhz,timing_status\n'
    for seed in "${seeds[@]}"; do
        result="${SWEEP_DIR}/result-seed-${seed}.csv"
        if [[ -f "${result}" ]]; then
            cat "${result}"
        else
            printf '%d,MISSING,MISSING,MISSING,MISSING\n' "${seed}"
            run_status=1
        fi
    done
} > "${results_file}"

echo
echo "Results: ${results_file}"

# Timing FAIL is a valid sweep result and does not make the script fail.
# Return nonzero only for real synthesis, nextpnr, packaging, or artifact errors.
exit "${run_status}"
