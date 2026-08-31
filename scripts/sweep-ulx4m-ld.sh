#!/bin/bash
# -----------------------------------------------------------------------------
# File:        sweep-ulx4m-ld.sh
# Path:        scripts/sweep-ulx4m-ld.sh
#
# Project:     Hazard3-Doom
# Purpose:     Run fully routed ULX4M-LD 85F nextpnr seed sweeps and record
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

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
HAZARD3_ROOT="${HAZARD3_ROOT:-${REPO_ROOT}/third_party/Hazard3}"
SYNTH_DIR="${HAZARD3_ROOT}/example_soc/synth"
LITEDRAM_DIR="${HAZARD3_ROOT}/example_soc/third_party/LiteDRAM"
COMMON_SCRIPT="${SCRIPT_DIR}/sweep-ecp5-common.sh"
SWEEP_JOBS="${SWEEP_JOBS:-2}"
SWEEP_SKIP_SYNTH="${SWEEP_SKIP_SYNTH:-0}"
SWEEP_PREPARE_ONLY="${SWEEP_PREPARE_ONLY:-0}"
HAZARD3_ULX4M_SYS_CLK_MHZ="${HAZARD3_ULX4M_SYS_CLK_MHZ:-50}"
ULX4M_LITEDRAM_CPU="${ULX4M_LITEDRAM_CPU:-serv}"
SYNTH_PROFILE_STAMP="${SYNTH_DIR}/fpga_ulx4m_ld.sys-clk-mhz"
SYNTH_DURATION_STAMP="${SYNTH_DIR}/fpga_ulx4m_ld.synth-seconds"
LITEDRAM_CPU_STAMP="${SYNTH_DIR}/fpga_ulx4m_ld.litedram-cpu"
NETLIST="${SYNTH_DIR}/fpga_ulx4m_ld.json"
LPF="${SYNTH_DIR}/fpga_ulx4m_ld.lpf"
SYNTH_LOG="${SYNTH_DIR}/synth.log"

# shellcheck source=scripts/sweep-ecp5-common.sh
# shellcheck disable=SC1091
source "${COMMON_SCRIPT}"
echo "Include source: ${COMMON_SCRIPT}"

sweep_ecp5_init_tuning
TUNING_SUFFIX="$(sweep_ecp5_tuning_suffix)"
SWEEP_DIR="${SYNTH_DIR}/routing-sweep/ulx4m-ld-${HAZARD3_ULX4M_SYS_CLK_MHZ}mhz-${ULX4M_LITEDRAM_CPU}${TUNING_SUFFIX}"
SWEEP_REL_DIR="${SWEEP_DIR#"${REPO_ROOT}"/}"

usage()
{
    cat >&2 <<EOF_USAGE
Usage: $0 SEED [SEED ...]
       $0 SEED[,SEED...]
       $0 START-END
       $0 --all

Route one or more nextpnr seeds for the ULX4M-LD 85F Hazard3-Doom build.
Seeds must be decimal values from 1 through 260.
SWEEP_JOBS=N runs up to N routes concurrently (default: 2).
HAZARD3_ULX4M_SYS_CLK_MHZ=25|40|50 selects the Hazard3 system clock.
ULX4M_LITEDRAM_CPU=serv|vexrisc selects the LiteDRAM initialization CPU.
SWEEP_SKIP_SYNTH=1 routes an already-frozen synthesized netlist.
SWEEP_ROUTE_TIMEOUT_SECONDS=N limits each nextpnr route (default: 600).
Generic nextpnr tuning is controlled by SWEEP_NEXTPNR_* variables.
The older HAZARD3_ULX4M_NEXTPNR_* names remain accepted as aliases.
EOF_USAGE
} # usage

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
case "${HAZARD3_ULX4M_SYS_CLK_MHZ}" in
25|40|50) ;;
*) echo "HAZARD3_ULX4M_SYS_CLK_MHZ must be 25, 40, or 50." >&2; exit 1 ;;
esac
case "${ULX4M_LITEDRAM_CPU}" in
serv|vexrisc) ;;
*) echo "ULX4M_LITEDRAM_CPU must be serv or vexrisc." >&2; exit 1 ;;
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
    recorded_litedram_cpu=""
    if [[ -f "${SYNTH_PROFILE_STAMP}" ]]; then
        read -r recorded_profile < "${SYNTH_PROFILE_STAMP}" || true
    fi
    if [[ -f "${LITEDRAM_CPU_STAMP}" ]]; then
        read -r recorded_litedram_cpu < "${LITEDRAM_CPU_STAMP}" || true
    fi

    if [[ "${recorded_profile}" != "${HAZARD3_ULX4M_SYS_CLK_MHZ}" ]]; then
        echo "Frozen ULX4M-LD netlist system clock does not match requested ${HAZARD3_ULX4M_SYS_CLK_MHZ} MHz." >&2
        exit 1
    fi
    if [[ "${recorded_litedram_cpu}" != "${ULX4M_LITEDRAM_CPU}" ]]; then
        echo "Frozen ULX4M-LD netlist LiteDRAM CPU does not match requested ${ULX4M_LITEDRAM_CPU}." >&2
        exit 1
    fi
    printf 'Using existing synthesized ULX4M-LD netlist; synthesis skipped.\n'
else
    sweep_ecp5_require_tool make
    sweep_ecp5_require_tool yosys

    generated_dir="${LITEDRAM_DIR}/generated-${ULX4M_LITEDRAM_CPU}"
    sweep_ecp5_require_file "${SYNTH_DIR}/ULX4M_LD_85F.mk"
    sweep_ecp5_require_file "${LITEDRAM_DIR}/litedram_ulx4m_cpu.v"
    sweep_ecp5_require_file "${generated_dir}/litedram_ulx4m_cpu.v"
    sweep_ecp5_require_file "${generated_dir}/litedram_ulx4m_cpu_rom.init"
    sweep_ecp5_require_file "${generated_dir}/litedram_ulx4m_cpu_sram.init"

    recorded_profile=""
    if [[ -f "${SYNTH_PROFILE_STAMP}" ]]; then
        read -r recorded_profile < "${SYNTH_PROFILE_STAMP}" || true
    fi
    if [[ "${recorded_profile}" != "${HAZARD3_ULX4M_SYS_CLK_MHZ}" ]]; then
        rm -f "${NETLIST}" "${SYNTH_DURATION_STAMP}"
    fi

    synth_start_seconds="$(date +%s)"
    DEFINES="${DEFINES:+${DEFINES} }HAZARD3_ULX4M_SYS_CLK_MHZ=${HAZARD3_ULX4M_SYS_CLK_MHZ}" \
        make -C "${SYNTH_DIR}" -f ULX4M_LD_85F.mk \
            ULX4M_LITEDRAM_CPU="${ULX4M_LITEDRAM_CPU}" synth
    synthesis_seconds="$(( $(date +%s) - synth_start_seconds ))"
    printf '%s\n' "${synthesis_seconds}" > "${SYNTH_DURATION_STAMP}"
    printf '%s\n' "${HAZARD3_ULX4M_SYS_CLK_MHZ}" > "${SYNTH_PROFILE_STAMP}"
fi

[[ -s "${NETLIST}" ]] || {
    echo "Missing synthesized ULX4M-LD netlist: ${NETLIST}" >&2
    exit 1
}
[[ -s "${SYNTH_LOG}" ]] || {
    echo "Missing ULX4M-LD synthesis log: ${SYNTH_LOG}" >&2
    exit 1
}

recorded_litedram_cpu=""
if [[ -f "${LITEDRAM_CPU_STAMP}" ]]; then
    read -r recorded_litedram_cpu < "${LITEDRAM_CPU_STAMP}" || true
fi
if [[ "${recorded_litedram_cpu}" != "${ULX4M_LITEDRAM_CPU}" ]]; then
    echo "ULX4M-LD synthesized netlist LiteDRAM CPU does not match requested ${ULX4M_LITEDRAM_CPU}." >&2
    exit 1
fi

if [[ "${HAZARD3_ULX4M_SYS_CLK_MHZ}" == "25" ]]; then
    if grep -Eq "Used module:[[:space:]]+\\\\pll_25_(40|50)$" "${SYNTH_LOG}"; then
        echo "ULX4M-LD 25 MHz profile unexpectedly uses a system PLL." >&2
        exit 1
    fi
elif ! grep -Eq \
    "Used module:[[:space:]]+\\\\pll_25_${HAZARD3_ULX4M_SYS_CLK_MHZ}$" \
    "${SYNTH_LOG}"; then
    echo "ULX4M-LD netlist does not use the requested ${HAZARD3_ULX4M_SYS_CLK_MHZ} MHz system PLL." >&2
    exit 1
fi
if ! grep -Fq \
    "Parameter \\CLK_MHZ = ${HAZARD3_ULX4M_SYS_CLK_MHZ}" \
    "${SYNTH_LOG}"; then
    echo "ULX4M-LD netlist CLK_MHZ does not match the requested system clock." >&2
    exit 1
fi

netlist_sha256="$(sha256sum "${NETLIST}" | awk '{print $1}')"
mkdir -p "${SWEEP_DIR}"

{
    printf 'target=ulx4m-ld-85f\n'
    printf 'device=um-85k\n'
    printf 'speed=8\n'
    printf 'package=CABGA381\n'
    printf 'full_route=1\n'
    printf 'result_columns=seed,clk_sys_mhz,litedram_user_mhz,clk_video_mhz,clk_tmds_mhz,init_clk_mhz,route_seconds,timing_status\n'
    printf 'litedram_cpu=%s\n' "${ULX4M_LITEDRAM_CPU}"
    printf 'hazard3_sys_clk_mhz=%s\n' "${HAZARD3_ULX4M_SYS_CLK_MHZ}"
    sweep_ecp5_write_tuning_metadata
    printf 'clk_sys_required_mhz=%s.00\n' "${HAZARD3_ULX4M_SYS_CLK_MHZ}"
    printf 'litedram_user_required_mhz=75.01\n'
    printf 'clk_video_required_mhz=50.00\n'
    printf 'clk_tmds_required_mhz=250.00\n'
    printf 'init_clk_required_mhz=25.00\n'
    printf 'synthesis_seconds=%s\n' "${synthesis_seconds}"
    printf 'netlist_sha256=%s\n' "${netlist_sha256}"
    printf 'netlist=fpga_ulx4m_ld.json\n'
    printf 'generated_utc=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
} > "${SWEEP_DIR}/metadata.txt"

printf 'ULX4M-LD synthesis duration: %s seconds\n' "${synthesis_seconds}"
printf 'ULX4M-LD routed sweep netlist SHA256: %s\n' "${netlist_sha256}"
printf 'ULX4M-LD routed sweep directory: %s\n' "${SWEEP_DIR}"

if [[ "${SWEEP_PREPARE_ONLY}" == "1" ]]; then
    printf 'ULX4M-LD frozen sweep netlist prepared; routing skipped.\n'
    exit 0
fi

sweep_ecp5_require_tool nextpnr-ecp5
sweep_ecp5_require_tool timeout

run_seed()
{
    local seed="$1"
    local log="${SWEEP_DIR}/seed-${seed}.log"
    local result="${SWEEP_DIR}/result-seed-${seed}.csv"
    local clk_sys litedram_user clk_video clk_tmds init_clk
    local clk_sys_clock clk_sys_status litedram_user_status
    local clk_video_status clk_tmds_status init_clk_status
    local route_start_seconds route_seconds route_status timing_status

    printf '\nTrying ULX4M-LD 85F nextpnr seed %s\n' "${seed}"
    rm -f "${log}" "${result}"

    route_start_seconds="$(date +%s)"
    if sweep_ecp5_run_nextpnr \
        --seed "${seed}" \
        "${SWEEP_NEXTPNR_ARGS[@]}" \
        --um-85k \
        --speed 8 \
        --package CABGA381 \
        --lpf "${LPF}" \
        --json "${NETLIST}" \
        --timing-allow-fail \
        --quiet \
        --log "${log}"; then
        route_status=0
    else
        route_status=$?
    fi
    route_seconds="$(( $(date +%s) - route_start_seconds ))"

    case "${route_status}" in
    0)
        ;;
    124|137)
        printf '%d,TIMEOUT,TIMEOUT,TIMEOUT,TIMEOUT,TIMEOUT,%s,TIMEOUT\n' \
            "${seed}" "${route_seconds}" > "${result}"
        printf 'Seed %s: routing timed out after %ss (kill grace %ss, status %s).\n' \
            "${seed}" "${SWEEP_ROUTE_TIMEOUT_SECONDS}" \
            "${SWEEP_ROUTE_KILL_AFTER_SECONDS}" "${route_status}" >&2
        return 0
        ;;
    *)
        printf '%d,ERROR,ERROR,ERROR,ERROR,ERROR,%s,ERROR\n' "${seed}" "${route_seconds}" > "${result}"
        printf 'Seed %s: nextpnr route failed with status %s.\n' \
            "${seed}" "${route_status}" >&2
        return 1
        ;;
    esac

    clk_sys_clock="clk_sys"
    if [[ "${HAZARD3_ULX4M_SYS_CLK_MHZ}" == "25" ]]; then
        clk_sys_clock="clk_osc"
    fi

    clk_sys="$(sweep_ecp5_extract_clock "${log}" "${clk_sys_clock}")"
    litedram_user="$(sweep_ecp5_extract_clock "${log}" "litedram_user_clk")"
    clk_video="$(sweep_ecp5_extract_clock "${log}" "clk_video_pix")"
    clk_tmds="$(sweep_ecp5_extract_clock "${log}" "clk_tmds_x5")"
    init_clk="$(sweep_ecp5_extract_clock "${log}" "init_clk")"
    clk_sys_status="$(sweep_ecp5_extract_clock_status "${log}" "${clk_sys_clock}")"
    litedram_user_status="$(sweep_ecp5_extract_clock_status "${log}" "litedram_user_clk")"
    clk_video_status="$(sweep_ecp5_extract_clock_status "${log}" "clk_video_pix")"
    clk_tmds_status="$(sweep_ecp5_extract_clock_status "${log}" "clk_tmds_x5")"
    init_clk_status="$(sweep_ecp5_extract_clock_status "${log}" "init_clk")"

    timing_status="FAIL"
    if [[ "${clk_sys_status}" == "PASS" &&
          "${litedram_user_status}" == "PASS" &&
          "${clk_video_status}" == "PASS" &&
          "${clk_tmds_status}" == "PASS" &&
          "${init_clk_status}" == "PASS" ]]; then
        timing_status="PASS"
    fi

    printf '%d,%s,%s,%s,%s,%s,%s,%s\n' \
        "${seed}" "${clk_sys}" "${litedram_user}" "${clk_video}" \
        "${clk_tmds}" "${init_clk}" "${route_seconds}" "${timing_status}" > "${result}"
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
    printf 'seed,clk_sys_mhz,litedram_user_mhz,clk_video_mhz,clk_tmds_mhz,init_clk_mhz,route_seconds,timing_status\n'
    for seed in "${SWEEP_SEEDS[@]}"; do
        result="${SWEEP_DIR}/result-seed-${seed}.csv"
        if [[ -f "${result}" ]]; then
            cat "${result}"
        else
            printf '%d,MISSING,MISSING,MISSING,MISSING,MISSING,MISSING,MISSING\n' "${seed}"
            status=1
        fi
    done
} > "${results_file}"

pass_count="$(awk -F, 'NR > 1 && $8 == "PASS" {count++} END {print count + 0}' "${results_file}")"
pass_seeds="$(awk -F, 'NR > 1 && $8 == "PASS" {if (s != "") s=s ", "; s=s $1} END {print s}' "${results_file}")"
timeout_count="$(awk -F, 'NR > 1 && $8 == "TIMEOUT" {count++} END {print count + 0}' "${results_file}")"
timeout_seeds="$(awk -F, 'NR > 1 && $8 == "TIMEOUT" {if (s != "") s=s ", "; s=s $1} END {print s}' "${results_file}")"
printf '\nTiming-passing seeds: %s\n' "${pass_count}"
printf 'PASS seed values: %s\n' "${pass_seeds:-none}"
printf 'Timed-out seeds: %s\n' "${timeout_count}"
printf 'TIMEOUT seed values: %s\n' "${timeout_seeds:-none}"
printf 'Results: %s\n' "${results_file}"

exit "${status}"
