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
#
#   HAZARD3_ULX4M_SYS_CLK_MHZ=40 SWEEP_JOBS=32 ./scripts/sweep-ulx4m-ld.sh
#
#   HAZARD3_ULX4M_SYS_CLK_MHZ=40 ULX4M_LITEDRAM_CPU=vexrisc \
#       SWEEP_JOBS=32 ./scripts/sweep-ulx4m-ld.sh
#
#   HAZARD3_ULX4M_SYS_CLK_MHZ=40 \
#   HAZARD3_ULX4M_NEXTPNR_HEAP_TIMINGWEIGHT=30 \
#   HAZARD3_ULX4M_NEXTPNR_HEAP_CRITEXP=3 \
#       ./scripts/sweep-ulx4m-ld.sh 48
#
#   HAZARD3_ULX4M_SYS_CLK_MHZ=40 \
#   HAZARD3_ULX4M_NEXTPNR_ROUTER=router2 \
#   HAZARD3_ULX4M_NEXTPNR_TMG_RIPUP=1 \
#   HAZARD3_ULX4M_NEXTPNR_ROUTER2_ALT_WEIGHTS=1 \
#       ./scripts/sweep-ulx4m-ld.sh 48
#
# Manual clean:
#
#  rm -f \
#      third_party/Hazard3/example_soc/synth/fpga_ulx4m_ld.json \
#      third_party/Hazard3/example_soc/synth/fpga_ulx4m_ld.config \
#      third_party/Hazard3/example_soc/synth/fpga_ulx4m_ld.bit \
#      third_party/Hazard3/example_soc/synth/fpga_ulx4m_ld.svf

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
HAZARD3_ROOT="${HAZARD3_ROOT:-${REPO_ROOT}/third_party/Hazard3}"
SYNTH_DIR="${HAZARD3_ROOT}/example_soc/synth"
LITEDRAM_DIR="${HAZARD3_ROOT}/example_soc/third_party/LiteDRAM"
SWEEP_JOBS="${SWEEP_JOBS:-2}"
SWEEP_SKIP_SYNTH="${SWEEP_SKIP_SYNTH:-0}"
HAZARD3_ULX4M_SYS_CLK_MHZ="${HAZARD3_ULX4M_SYS_CLK_MHZ:-50}"
ULX4M_LITEDRAM_CPU="${ULX4M_LITEDRAM_CPU:-serv}"
HAZARD3_ULX4M_NEXTPNR_PLACER="${HAZARD3_ULX4M_NEXTPNR_PLACER:-heap}"
HAZARD3_ULX4M_NEXTPNR_ROUTER="${HAZARD3_ULX4M_NEXTPNR_ROUTER:-router1}"
HAZARD3_ULX4M_NEXTPNR_HEAP_TIMINGWEIGHT="${HAZARD3_ULX4M_NEXTPNR_HEAP_TIMINGWEIGHT:-10}"
HAZARD3_ULX4M_NEXTPNR_HEAP_CRITEXP="${HAZARD3_ULX4M_NEXTPNR_HEAP_CRITEXP:-2}"
HAZARD3_ULX4M_NEXTPNR_TMG_RIPUP="${HAZARD3_ULX4M_NEXTPNR_TMG_RIPUP:-0}"
HAZARD3_ULX4M_NEXTPNR_ROUTER2_ALT_WEIGHTS="${HAZARD3_ULX4M_NEXTPNR_ROUTER2_ALT_WEIGHTS:-0}"
HAZARD3_ULX4M_NEXTPNR_EXTRA_ARGS="${HAZARD3_ULX4M_NEXTPNR_EXTRA_ARGS:-}"
SYNTH_PROFILE_STAMP="${SYNTH_DIR}/fpga_ulx4m_ld.sys-clk-mhz"
LITEDRAM_CPU_STAMP="${SYNTH_DIR}/fpga_ulx4m_ld.litedram-cpu"

usage()
{
    echo "Usage: $0 [seed|start-end]" >&2
    echo "  no argument  Route seeds 1 through 260" >&2
    echo "  seed         Route one seed (1-260)" >&2
    echo "  start-end    Route an inclusive seed range (1-260)" >&2
    echo "  SWEEP_JOBS=N Run up to N routed seeds concurrently (default: 2)" >&2
    echo "  ULX4M_LITEDRAM_CPU=serv|vexrisc Select LiteDRAM initialization CPU (default: serv)" >&2
    echo "  HAZARD3_ULX4M_NEXTPNR_PLACER=heap|sa Select nextpnr placer (default: heap)" >&2
    echo "  HAZARD3_ULX4M_NEXTPNR_ROUTER=router1|router2 Select nextpnr router (default: router1)" >&2
    echo "  HAZARD3_ULX4M_NEXTPNR_HEAP_TIMINGWEIGHT=N HeAP timing weight (default: 10)" >&2
    echo "  HAZARD3_ULX4M_NEXTPNR_HEAP_CRITEXP=N HeAP criticality exponent (default: 2)" >&2
    echo "  HAZARD3_ULX4M_NEXTPNR_TMG_RIPUP=0|1 Enable timing-driven router rip-up" >&2
    echo "  HAZARD3_ULX4M_NEXTPNR_ROUTER2_ALT_WEIGHTS=0|1 Enable Router2 alternate weights" >&2
    echo "  HAZARD3_ULX4M_NEXTPNR_EXTRA_ARGS='...' Append whitespace-separated nextpnr arguments" >&2
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

normalize_bool()
{
    case "$1" in
    1|true|yes|on)
        printf '1\n'
        ;;
    0|false|no|off|"")
        printf '0\n'
        ;;
    *)
        return 1
        ;;
    esac
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

case "${HAZARD3_ULX4M_SYS_CLK_MHZ}" in
25|40|50)
    ;;
*)
    echo "HAZARD3_ULX4M_SYS_CLK_MHZ must be 25, 40, or 50" >&2
    exit 1
    ;;
esac

case "${ULX4M_LITEDRAM_CPU}" in
serv|vexrisc)
    ;;
*)
    echo "ULX4M_LITEDRAM_CPU must be serv or vexrisc" >&2
    exit 1
    ;;
esac

case "${HAZARD3_ULX4M_NEXTPNR_PLACER}" in
heap|sa)
    ;;
*)
    echo "HAZARD3_ULX4M_NEXTPNR_PLACER must be heap or sa" >&2
    exit 1
    ;;
esac

case "${HAZARD3_ULX4M_NEXTPNR_ROUTER}" in
router1|router2)
    ;;
*)
    echo "HAZARD3_ULX4M_NEXTPNR_ROUTER must be router1 or router2" >&2
    exit 1
    ;;
esac

if [[ ! "${HAZARD3_ULX4M_NEXTPNR_HEAP_TIMINGWEIGHT}" =~ ^[0-9]+$ ]]; then
    echo "HAZARD3_ULX4M_NEXTPNR_HEAP_TIMINGWEIGHT must be a non-negative integer" >&2
    exit 1
fi
if [[ ! "${HAZARD3_ULX4M_NEXTPNR_HEAP_CRITEXP}" =~ ^[0-9]+$ ]]; then
    echo "HAZARD3_ULX4M_NEXTPNR_HEAP_CRITEXP must be a non-negative integer" >&2
    exit 1
fi

if ! HAZARD3_ULX4M_NEXTPNR_TMG_RIPUP="$(
    normalize_bool "${HAZARD3_ULX4M_NEXTPNR_TMG_RIPUP}"
)"; then
    echo "HAZARD3_ULX4M_NEXTPNR_TMG_RIPUP must be 0/1 or false/true" >&2
    exit 1
fi
if ! HAZARD3_ULX4M_NEXTPNR_ROUTER2_ALT_WEIGHTS="$(
    normalize_bool "${HAZARD3_ULX4M_NEXTPNR_ROUTER2_ALT_WEIGHTS}"
)"; then
    echo "HAZARD3_ULX4M_NEXTPNR_ROUTER2_ALT_WEIGHTS must be 0/1 or false/true" >&2
    exit 1
fi

if [[ "${HAZARD3_ULX4M_NEXTPNR_PLACER}" != "heap" &&
      ( "${HAZARD3_ULX4M_NEXTPNR_HEAP_TIMINGWEIGHT}" != "10" ||
        "${HAZARD3_ULX4M_NEXTPNR_HEAP_CRITEXP}" != "2" ) ]]; then
    echo "HeAP timing weight/criticality options require HAZARD3_ULX4M_NEXTPNR_PLACER=heap" >&2
    exit 1
fi

if [[ "${HAZARD3_ULX4M_NEXTPNR_ROUTER2_ALT_WEIGHTS}" == "1" &&
      "${HAZARD3_ULX4M_NEXTPNR_ROUTER}" != "router2" ]]; then
    echo "Router2 alternate weights require HAZARD3_ULX4M_NEXTPNR_ROUTER=router2" >&2
    exit 1
fi

require_tool make
require_tool yosys
require_tool nextpnr-ecp5
require_tool sha256sum
require_tool awk
require_file "${SYNTH_DIR}/ULX4M_LD_85F.mk"
require_file "${SYNTH_DIR}/fpga_ulx4m_ld.lpf"
require_file "${LITEDRAM_DIR}/litedram_ulx4m_cpu.v"
require_file "${LITEDRAM_DIR}/generated-${ULX4M_LITEDRAM_CPU}/litedram_ulx4m_cpu.v"
require_file "${LITEDRAM_DIR}/generated-${ULX4M_LITEDRAM_CPU}/litedram_ulx4m_cpu_rom.init"
require_file "${LITEDRAM_DIR}/generated-${ULX4M_LITEDRAM_CPU}/litedram_ulx4m_cpu_sram.init"

nextpnr_tuning_args=(
    --router "${HAZARD3_ULX4M_NEXTPNR_ROUTER}"
)
if [[ "${HAZARD3_ULX4M_NEXTPNR_PLACER}" == "heap" ]]; then
    nextpnr_tuning_args+=(
        --placer-heap-timingweight "${HAZARD3_ULX4M_NEXTPNR_HEAP_TIMINGWEIGHT}"
        --placer-heap-critexp "${HAZARD3_ULX4M_NEXTPNR_HEAP_CRITEXP}"
    )
fi
if [[ "${HAZARD3_ULX4M_NEXTPNR_TMG_RIPUP}" == "1" ]]; then
    nextpnr_tuning_args+=(--tmg-ripup)
fi
if [[ "${HAZARD3_ULX4M_NEXTPNR_ROUTER2_ALT_WEIGHTS}" == "1" ]]; then
    nextpnr_tuning_args+=(--router2-alt-weights)
fi
if [[ -n "${HAZARD3_ULX4M_NEXTPNR_EXTRA_ARGS}" ]]; then
    read -r -a nextpnr_extra_args <<< "${HAZARD3_ULX4M_NEXTPNR_EXTRA_ARGS}"
    nextpnr_tuning_args+=("${nextpnr_extra_args[@]}")
fi

SWEEP_DIR="routing-sweep/ulx4m-ld-${HAZARD3_ULX4M_SYS_CLK_MHZ}mhz-${ULX4M_LITEDRAM_CPU}"
if [[ "${HAZARD3_ULX4M_NEXTPNR_PLACER}" != "heap" ]]; then
    SWEEP_DIR="${SWEEP_DIR}-${HAZARD3_ULX4M_NEXTPNR_PLACER}"
fi
if [[ "${HAZARD3_ULX4M_NEXTPNR_ROUTER}" != "router1" ]]; then
    SWEEP_DIR="${SWEEP_DIR}-${HAZARD3_ULX4M_NEXTPNR_ROUTER}"
fi
if [[ "${HAZARD3_ULX4M_NEXTPNR_PLACER}" == "heap" &&
      "${HAZARD3_ULX4M_NEXTPNR_HEAP_TIMINGWEIGHT}" != "10" ]]; then
    SWEEP_DIR="${SWEEP_DIR}-tw${HAZARD3_ULX4M_NEXTPNR_HEAP_TIMINGWEIGHT}"
fi
if [[ "${HAZARD3_ULX4M_NEXTPNR_PLACER}" == "heap" &&
      "${HAZARD3_ULX4M_NEXTPNR_HEAP_CRITEXP}" != "2" ]]; then
    SWEEP_DIR="${SWEEP_DIR}-ce${HAZARD3_ULX4M_NEXTPNR_HEAP_CRITEXP}"
fi
if [[ "${HAZARD3_ULX4M_NEXTPNR_TMG_RIPUP}" == "1" ]]; then
    SWEEP_DIR="${SWEEP_DIR}-ripup"
fi
if [[ "${HAZARD3_ULX4M_NEXTPNR_ROUTER2_ALT_WEIGHTS}" == "1" ]]; then
    SWEEP_DIR="${SWEEP_DIR}-altw"
fi
if [[ -n "${HAZARD3_ULX4M_NEXTPNR_EXTRA_ARGS}" ]]; then
    extra_hash="$(printf '%s' "${HAZARD3_ULX4M_NEXTPNR_EXTRA_ARGS}" | sha256sum)"
    extra_hash="${extra_hash%% *}"
    SWEEP_DIR="${SWEEP_DIR}-extra-${extra_hash:0:8}"
fi

if (( $# == 1 )) && [[ "$1" == "--print-sweep-dir" ]]; then
    printf '%s\n' "${SWEEP_DIR}"
    exit 0
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

netlist_sha256_before=""
if [[ -s "${SYNTH_DIR}/fpga_ulx4m_ld.json" ]]; then
    netlist_sha256_before="$(sha256sum "${SYNTH_DIR}/fpga_ulx4m_ld.json" | awk '{print $1}')"
fi

# Always ask make to ensure the synthesized netlist is current. This is a no-op
# when the source dependencies are already up to date.
if [[ "${SWEEP_SKIP_SYNTH}" != "1" ]]; then
    recorded_profile=""
    if [[ -f "${SYNTH_PROFILE_STAMP}" ]]; then
        read -r recorded_profile < "${SYNTH_PROFILE_STAMP}" || true
    fi
    if [[ "${recorded_profile}" != "${HAZARD3_ULX4M_SYS_CLK_MHZ}" ]]; then
        rm -f "${SYNTH_DIR}/fpga_ulx4m_ld.json"
    fi

    # Always ask make to ensure the synthesized netlist is current. This is a no-op
    # when the source dependencies are already up to date.
    DEFINES="${DEFINES:+${DEFINES} }HAZARD3_ULX4M_SYS_CLK_MHZ=${HAZARD3_ULX4M_SYS_CLK_MHZ}" \
        make -C "${SYNTH_DIR}" -f ULX4M_LD_85F.mk \
            ULX4M_LITEDRAM_CPU="${ULX4M_LITEDRAM_CPU}" synth
    printf '%s\n' "${HAZARD3_ULX4M_SYS_CLK_MHZ}" > "${SYNTH_PROFILE_STAMP}"
else
    printf 'Using existing synthesized netlist; synthesis skipped.\n'
fi

recorded_litedram_cpu=""
if [[ -f "${LITEDRAM_CPU_STAMP}" ]]; then
    read -r recorded_litedram_cpu < "${LITEDRAM_CPU_STAMP}" || true
fi
if [[ "${recorded_litedram_cpu}" != "${ULX4M_LITEDRAM_CPU}" ]]; then
    echo "ULX4M-LD synthesized netlist LiteDRAM CPU does not match requested ${ULX4M_LITEDRAM_CPU}." >&2
    exit 1
fi

[[ -s "${SYNTH_DIR}/fpga_ulx4m_ld.json" ]] || {
    echo "Synthesis completed without creating ${SYNTH_DIR}/fpga_ulx4m_ld.json" >&2
    exit 1
}
require_file "${SYNTH_DIR}/synth.log"
if [[ "${HAZARD3_ULX4M_SYS_CLK_MHZ}" == 25 ]]; then
    if grep -Eq \
        "Used module:[[:space:]]+\\\\pll_25_(40|50)$" \
        "${SYNTH_DIR}/synth.log"; then
        echo "ULX4M-LD 25 MHz profile unexpectedly uses a system PLL." >&2
        exit 1
    fi
elif ! grep -Eq \
    "Used module:[[:space:]]+\\\\pll_25_${HAZARD3_ULX4M_SYS_CLK_MHZ}$" \
    "${SYNTH_DIR}/synth.log"; then
    echo "ULX4M-LD netlist does not use the requested ${HAZARD3_ULX4M_SYS_CLK_MHZ} MHz system PLL." >&2
    exit 1
fi
if ! grep -Fq \
    "Parameter \\CLK_MHZ = ${HAZARD3_ULX4M_SYS_CLK_MHZ}" \
    "${SYNTH_DIR}/synth.log"; then
    echo "ULX4M-LD netlist CLK_MHZ does not match the requested system clock." >&2
    exit 1
fi

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
    printf 'litedram_cpu=%s\n' "${ULX4M_LITEDRAM_CPU}"
    printf 'placer=%s\n' "${HAZARD3_ULX4M_NEXTPNR_PLACER}"
    printf 'router=%s\n' "${HAZARD3_ULX4M_NEXTPNR_ROUTER}"
    printf 'heap_timingweight=%s\n' "${HAZARD3_ULX4M_NEXTPNR_HEAP_TIMINGWEIGHT}"
    printf 'heap_critexp=%s\n' "${HAZARD3_ULX4M_NEXTPNR_HEAP_CRITEXP}"
    printf 'tmg_ripup=%s\n' "${HAZARD3_ULX4M_NEXTPNR_TMG_RIPUP}"
    printf 'router2_alt_weights=%s\n' "${HAZARD3_ULX4M_NEXTPNR_ROUTER2_ALT_WEIGHTS}"
    printf 'extra_args=%s\n' "${HAZARD3_ULX4M_NEXTPNR_EXTRA_ARGS}"
    printf 'nextpnr_version=%s\n' "$(nextpnr-ecp5 --version 2>&1 | head -n 1)"
    printf 'full_route=1\n'
    printf 'clk_sys_required_mhz=%s.00\n' "${HAZARD3_ULX4M_SYS_CLK_MHZ}"
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
        --placer "${HAZARD3_ULX4M_NEXTPNR_PLACER}" \
        "${nextpnr_tuning_args[@]}" \
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

    if [[ "${HAZARD3_ULX4M_SYS_CLK_MHZ}" == "25" ]]; then
        clk_sys="$(extract_clock "${log}" "clk_osc")"
    else
        clk_sys="$(extract_clock "${log}" "clk_sys")"
    fi
    litedram_user="$(extract_clock "${log}" "litedram_user_clk")"
    clk_video="$(extract_clock "${log}" "clk_video_pix")"
    clk_tmds="$(extract_clock "${log}" "clk_tmds_x5")"
    init_clk="$(extract_clock "${log}" "init_clk")"

    timing_status="FAIL"
    if clock_at_least "${clk_sys}" "${HAZARD3_ULX4M_SYS_CLK_MHZ}.00" &&
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

pass_count="$(awk -F, 'NR > 1 && $7 == "PASS" { count++ } END { print count + 0 }' "${results_file}")"
pass_seeds="$(
    awk -F, '
        NR > 1 && $7 == "PASS" {
            if (seeds != "") {
                seeds = seeds ", "
            }
            seeds = seeds $1
        }
        END { print seeds }
    ' "${results_file}"
)"

echo
printf 'Timing-passing seeds: %s\n' "${pass_count}"
if [[ -n "${pass_seeds}" ]]; then
    printf 'PASS seed values: %s\n' "${pass_seeds}"
else
    printf 'PASS seed values: none\n'
fi
echo "Results: ${SYNTH_DIR}/${results_file}"

exit "${status}"
