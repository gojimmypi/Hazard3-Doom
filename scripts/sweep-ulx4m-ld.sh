#!/bin/bash
# -----------------------------------------------------------------------------
# File:        sweep-ulx4m-ld.sh
# Path:        scripts/sweep-ulx4m-ld.sh
#
# Project:     Hazard3-Doom
# Purpose:     Run fully routed ULX4M-LD nextpnr seed sweeps and record final
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

# File: scripts/sweep-ulx4m-ld.sh
#
# Route ULX4M-LD 85F placement seeds and record final routed clock timing.
# Unlike the ULX3S placement-only sweep, ULX4M-LD must be fully routed because
# its placement-only timing estimates differ substantially from routed timing.
#
# Examples:
#
#   ./scripts/sweep-ulx4m-ld.sh 55
#
#   SWEEP_JOBS=2 ./scripts/sweep-ulx4m-ld.sh 1-32
#
#   SWEEP_JOBS=2 ./scripts/sweep-ulx4m-ld.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
HAZARD3_ROOT="${HAZARD3_ROOT:-${REPO_ROOT}/third_party/Hazard3}"
SYNTH_DIR="${HAZARD3_ROOT}/example_soc/synth"
LITEDRAM_DIR="${HAZARD3_ROOT}/example_soc/third_party/LiteDRAM/generated"
SWEEP_JOBS="${SWEEP_JOBS:-2}"
SWEEP_DIR="routing-sweep/ulx4m-ld"

usage()
{
    echo "Usage: $0 [seed|start-end]" >&2
    echo "  no argument  Route seeds 1 through 260" >&2
    echo "  seed         Route one seed (1-260)" >&2
    echo "  start-end    Route an inclusive seed range (1-260)" >&2
    echo "  SWEEP_JOBS=N Run up to N routed seeds concurrently (default: 2)" >&2
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

if (( $# > 1 )); then
    usage
    exit 1
fi

if [[ ! "${SWEEP_JOBS}" =~ ^[1-9][0-9]*$ ]]; then
    echo "Invalid SWEEP_JOBS: ${SWEEP_JOBS}; expected a positive integer." >&2
    usage
    exit 1
fi

if (( $# == 0 )); then
    mapfile -t seeds < <(seq 1 260)
    results_file="${SWEEP_DIR}/results.csv"
else
    seed_arg="$1"

    if [[ "${seed_arg}" =~ ^[0-9]+$ ]]; then
        if (( seed_arg < 1 || seed_arg > 260 )); then
            echo "Invalid seed: ${seed_arg}; expected 1-260." >&2
            usage
            exit 1
        fi

        seeds=("${seed_arg}")
        results_file="${SWEEP_DIR}/results-seed-${seed_arg}.csv"
    elif [[ "${seed_arg}" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        seed_first="${BASH_REMATCH[1]}"
        seed_last="${BASH_REMATCH[2]}"

        if (( seed_first < 1 || seed_first > 260 ||
              seed_last < 1 || seed_last > 260 ||
              seed_first > seed_last )); then
            echo "Invalid seed range: ${seed_arg}; expected start-end within 1-260." >&2
            usage
            exit 1
        fi

        mapfile -t seeds < <(seq "${seed_first}" "${seed_last}")
        results_file="${SWEEP_DIR}/results-seeds-${seed_first}-${seed_last}.csv"
    else
        echo "Invalid seed selection: ${seed_arg}." >&2
        usage
        exit 1
    fi
fi

require_tool make
require_tool yosys
require_tool nextpnr-ecp5
require_tool sha256sum
require_tool awk
require_file "${SYNTH_DIR}/ULX4M_LD_85F.mk"
require_file "${SYNTH_DIR}/fpga_ulx4m_ld.lpf"
require_file "${LITEDRAM_DIR}/litedram_ulx4m_cpu.v"
require_file "${LITEDRAM_DIR}/litedram_ulx4m_cpu_rom.init"
require_file "${LITEDRAM_DIR}/litedram_ulx4m_cpu_sram.init"

netlist_sha256_before=""
if [[ -s "${SYNTH_DIR}/fpga_ulx4m_ld.json" ]]; then
    netlist_sha256_before="$(sha256sum "${SYNTH_DIR}/fpga_ulx4m_ld.json" | awk '{print $1}')"
fi

# Always ask make to ensure the synthesized netlist is current. This is a no-op
# when the source dependencies are already up to date.
make -C "${SYNTH_DIR}" -f ULX4M_LD_85F.mk synth

[[ -s "${SYNTH_DIR}/fpga_ulx4m_ld.json" ]] || {
    echo "Synthesis completed without creating ${SYNTH_DIR}/fpga_ulx4m_ld.json" >&2
    exit 1
}

netlist_sha256="$(sha256sum "${SYNTH_DIR}/fpga_ulx4m_ld.json" | awk '{print $1}')"
if [[ -n "${netlist_sha256_before}" &&
      "${netlist_sha256_before}" != "${netlist_sha256}" ]]; then
    printf 'Synthesized ULX4M-LD netlist changed; invalidating routed FPGA artifacts.\n'
    rm -f \
        "${SYNTH_DIR}/fpga_ulx4m_ld.config" \
        "${SYNTH_DIR}/fpga_ulx4m_ld.bit" \
        "${SYNTH_DIR}/fpga_ulx4m_ld.svf"
fi

cd "${SYNTH_DIR}"
mkdir -p "${SWEEP_DIR}"

{
    printf 'target=ulx4m-ld-85f\n'
    printf 'device=um-85k\n'
    printf 'speed=8\n'
    printf 'package=CABGA381\n'
    printf 'placer=heap\n'
    printf 'full_route=1\n'
    printf 'clk_sys_required_mhz=50.00\n'
    printf 'litedram_user_required_mhz=75.01\n'
    printf 'clk_video_required_mhz=50.00\n'
    printf 'clk_tmds_required_mhz=250.00\n'
    printf 'netlist_sha256=%s\n' "${netlist_sha256}"
    printf 'netlist=fpga_ulx4m_ld.json\n'
    printf 'generated_utc=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
} > "${SWEEP_DIR}/metadata.txt"

printf 'ULX4M-LD routed sweep netlist SHA256: %s\n' "${netlist_sha256}"
printf 'ULX4M-LD routed sweep directory: %s/%s\n' "${SYNTH_DIR}" "${SWEEP_DIR}"

extract_clock()
{
    local log="$1"
    local clock="$2"
    local value

    # nextpnr reports timing once after placement and again after routing. Keep
    # the final match so the CSV contains routed, not placement-only, timing.
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

run_seed()
{
    local seed="$1"
    local log="${SWEEP_DIR}/seed-${seed}.log"
    local result="${SWEEP_DIR}/result-seed-${seed}.csv"
    local clk_sys litedram_user clk_video clk_tmds init_clk timing_status

    echo "=== routed ULX4M-LD seed ${seed} ==="

    if ! nextpnr-ecp5 \
        --placer heap \
        --um-85k \
        --speed 8 \
        --package CABGA381 \
        --lpf fpga_ulx4m_ld.lpf \
        --json fpga_ulx4m_ld.json \
        --seed "${seed}" \
        --timing-allow-fail \
        --quiet \
        --log "${log}"; then
        printf '%d,ERROR,ERROR,ERROR,ERROR,ERROR,ERROR\n' "${seed}" > "${result}"
        echo "Seed ${seed}: nextpnr failed; see ${log}" >&2
        return 1
    fi

    clk_sys="$(extract_clock "${log}" "clk_sys")"
    litedram_user="$(extract_clock "${log}" "litedram_user_clk")"
    clk_video="$(extract_clock "${log}" "clk_video_pix")"
    clk_tmds="$(extract_clock "${log}" "clk_tmds_x5")"
    init_clk="$(extract_clock "${log}" "init_clk")"

    timing_status="FAIL"
    if clock_at_least "${clk_sys}" 50.00 &&
       clock_at_least "${litedram_user}" 75.01 &&
       clock_at_least "${clk_video}" 50.00 &&
       clock_at_least "${clk_tmds}" 250.00 &&
       clock_at_least "${init_clk}" 25.00; then
        timing_status="PASS"
    fi

    printf '%d,%s,%s,%s,%s,%s,%s\n' \
        "${seed}" \
        "${clk_sys}" \
        "${litedram_user}" \
        "${clk_video}" \
        "${clk_tmds}" \
        "${init_clk}" \
        "${timing_status}" > "${result}"
    cat "${result}"
}

for seed in "${seeds[@]}"; do
    rm -f "${SWEEP_DIR}/result-seed-${seed}.csv"
done

printf 'Concurrent routed jobs: %s\n' "${SWEEP_JOBS}"

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
    printf 'seed,clk_sys_mhz,litedram_user_mhz,clk_video_mhz,clk_tmds_mhz,init_clk_mhz,timing_status\n'
    for seed in "${seeds[@]}"; do
        result="${SWEEP_DIR}/result-seed-${seed}.csv"
        if [[ -f "${result}" ]]; then
            cat "${result}"
        else
            printf '%d,MISSING,MISSING,MISSING,MISSING,MISSING,MISSING\n' "${seed}"
            status=1
        fi
    done
} > "${results_file}"

echo
echo "Results: ${SYNTH_DIR}/${results_file}"

exit "${status}"
