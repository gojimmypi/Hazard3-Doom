#!/bin/bash
#
# Copyright (c) 2026 gojimmypi
# SPDX-License-Identifier: Apache-2.0
#
# File: scripts/sweep-peek-ulx3s-12f.sh
#
# Run placement-only ULX3S 12F nextpnr seed checks against one synthesized
# compact-profile netlist. Use the ranked results to select a small set of
# seeds for the full routed scripts/sweep-ulx3s-12f.sh sweep.

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
SWEEP_DIR="${REPO_ROOT}/build/ulx3s-12f-placement-sweep/${HAZARD3_MEMORY_PROFILE}"

usage()
{
    cat >&2 <<EOF_USAGE
Usage: $0 SEED [SEED ...]
       $0 SEED[,SEED...]
       $0 START-END
       $0 --all

Run placement-only timing checks for ULX3S 12F nextpnr seeds.
Seeds must be decimal values from 1 through 260.
SWEEP_JOBS=N runs up to N placements concurrently (default: 4).
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
    ranked_file="${SWEEP_DIR}/ranked.csv"
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
        ranked_file="${SWEEP_DIR}/ranked-seed-${seeds[0]}.csv"
    else
        results_file="${SWEEP_DIR}/results-selected.csv"
        ranked_file="${SWEEP_DIR}/ranked-selected.csv"
    fi
fi

require_tool make
require_tool yosys
require_tool nextpnr-ecp5
require_tool sha256sum
require_tool awk
require_tool grep
require_tool sed
require_tool sort
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

# Synthesize once before starting concurrent placement checks. This is a no-op
# when the compact-profile synthesized netlist is already current.
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
    printf 'speed=6\n'
    printf 'package=CABGA381\n'
    printf 'placer=heap\n'
    printf 'full_route=0\n'
    printf 'hazard3_memory_profile=%s\n' "${HAZARD3_MEMORY_PROFILE}"
    printf 'dp16kd_used=%s\n' "${ebr_used}"
    printf 'netlist_sha256=%s\n' "${netlist_sha256}"
    printf 'netlist=fpga_ulx3s_12f.json\n'
    printf 'generated_utc=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
} > "${SWEEP_DIR}/metadata.txt"

printf 'ULX3S 12F placement sweep netlist SHA256: %s\n' "${netlist_sha256}"
printf 'ULX3S 12F placement sweep directory: %s\n' "${SWEEP_DIR}"
printf 'Checking %d seed(s):' "${#seeds[@]}"
printf ' %s' "${seeds[@]}"
printf '\n'
printf 'Concurrent placement jobs: %s\n' "${SWEEP_JOBS}"

run_seed()
{
    local seed="$1"
    local pnr_log="${SWEEP_DIR}/placement-${seed}.log"
    local failed_log="${SWEEP_DIR}/placement-${seed}-failed.log"
    local result="${SWEEP_DIR}/result-seed-${seed}.csv"
    local clk_sys clk_video clk_tmds

    printf 'Checking placement seed %s\n' "${seed}"

    rm -f "${pnr_log}" "${failed_log}" "${result}"

    if ! nextpnr-ecp5 \
        --seed "${seed}" \
        --placer heap \
        --12k \
        --speed 6 \
        --package CABGA381 \
        --lpf "${LPF}" \
        --json "${NETLIST}" \
        --timing-allow-fail \
        --no-route \
        --quiet \
        --log "${pnr_log}"; then
        printf '%d,ERROR,ERROR,ERROR\n' "${seed}" > "${result}"
        printf 'Seed %s placement failed; see %s\n' "${seed}" "${pnr_log}" >&2
        if [[ -f "${pnr_log}" ]]; then
            mv "${pnr_log}" "${failed_log}"
        fi
        return 1
    fi

    clk_sys="$(extract_clock "${pnr_log}" "clk_sys")"
    clk_video="$(extract_clock "${pnr_log}" "clk_video_pix")"
    clk_tmds="$(extract_clock "${pnr_log}" "clk_tmds_x5")"

    printf '%d,%s,%s,%s\n' \
        "${seed}" "${clk_sys}" "${clk_video}" "${clk_tmds}" > "${result}"
    rm -f "${failed_log}"

    printf 'Seed %s placement: clk_sys=%s MHz, clk_video=%s MHz, clk_tmds=%s MHz\n' \
        "${seed}" "${clk_sys}" "${clk_video}" "${clk_tmds}"
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
    printf 'seed,clk_sys_mhz,clk_video_mhz,clk_tmds_mhz\n'
    for seed in "${seeds[@]}"; do
        result="${SWEEP_DIR}/result-seed-${seed}.csv"
        if [[ -f "${result}" ]]; then
            cat "${result}"
        else
            printf '%d,MISSING,MISSING,MISSING\n' "${seed}"
            run_status=1
        fi
    done
} > "${results_file}"

{
    printf 'seed,clk_sys_mhz,clk_video_mhz,clk_tmds_mhz\n'
    tail -n +2 "${results_file}" |
        awk -F, '$2 ~ /^[0-9]+([.][0-9]+)?$/' |
        sort -t, -k2,2nr -k1,1n
} > "${ranked_file}"

echo
echo "Results: ${results_file}"
echo "Ranked by placement clk_sys: ${ranked_file}"
echo "Placement estimates rank seeds only; use scripts/sweep-ulx3s-12f.sh for final routed timing."

exit "${run_status}"
