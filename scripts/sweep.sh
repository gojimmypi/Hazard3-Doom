#!/bin/bash

set -u -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
HAZARD3_ROOT="${HAZARD3_ROOT:-${REPO_ROOT}/third_party/Hazard3}"
HAZARD3_SYNTH="${HAZARD3_ROOT}/example_soc/synth"
ULX3S_SEED_SWEEP_DIR="${REPO_ROOT}/build/ulx3s-seed-sweep"
SWEEP_JOBS="${SWEEP_JOBS:-4}"
HAZARD3_HDMI_EXTENDED_MODES="${HAZARD3_HDMI_EXTENDED_MODES:-1}"
ALLOW_TIMING_FAILURE="${ALLOW_TIMING_FAILURE:-0}"
SYNTH_PROFILE_STAMP="${HAZARD3_SYNTH}/fpga_ulx3s.video-profile"

usage()
{
    cat >&2 <<EOF_USAGE
Usage: $0 SEED [SEED ...]
       $0 SEED[,SEED...]
       $0 --all

Route one or more nextpnr seeds for the ULX3S 85F Hazard3-Doom build.
Seeds must be decimal values from 1 through 260.
SWEEP_JOBS=N runs up to N routes concurrently (default: 4).

Examples:
    $0 222
    $0 222 60 121
    $0 222,60,121
    $0 --all
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

if (( $# == 0 )); then
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
    VIDEO_PROFILE="standard"
    ;;
1)
    VIDEO_PROFILE="extended"
    ;;
*)
    echo "HAZARD3_HDMI_EXTENDED_MODES must be 0 or 1" >&2
    exit 1
    ;;
esac

case "${ALLOW_TIMING_FAILURE}" in
0)
    timing_options=()
    ;;
1)
    timing_options=(--timing-allow-fail)
    ;;
*)
    echo "ALLOW_TIMING_FAILURE must be 0 or 1" >&2
    exit 1
    ;;
esac

seeds=()
declare -A seen_seeds=()

if (( $# == 1 )) && [[ "$1" == "--all" ]]; then
    mapfile -t seeds < <(seq 1 260)
else
    for arg in "$@"; do
        if [[ "${arg}" == "--all" ]]; then
            echo "--all cannot be combined with explicit seeds." >&2
            usage
            exit 1
        fi

        IFS=',' read -r -a arg_seeds <<< "${arg}"
        for seed_arg in "${arg_seeds[@]}"; do
            if [[ ! "${seed_arg}" =~ ^[0-9]+$ ]]; then
                echo "Invalid seed: ${seed_arg}; expected a decimal value from 1 through 260." >&2
                usage
                exit 1
            fi

            seed_value=$((10#${seed_arg}))
            if (( seed_value < 1 || seed_value > 260 )); then
                echo "Invalid seed: ${seed_arg}; expected a decimal value from 1 through 260." >&2
                usage
                exit 1
            fi

            if [[ -z "${seen_seeds[${seed_value}]+x}" ]]; then
                seeds+=("${seed_value}")
                seen_seeds["${seed_value}"]=1
            fi
        done
    done
fi

require_tool make
require_tool yosys
require_tool nextpnr-ecp5
require_tool ecppack

mkdir -p "${ULX3S_SEED_SWEEP_DIR}"

current_video_profile=""
if [[ -f "${SYNTH_PROFILE_STAMP}" ]]; then
    read -r current_video_profile < "${SYNTH_PROFILE_STAMP}" || true
fi

if [[ "${current_video_profile}" != "${VIDEO_PROFILE}" ]]; then
    if [[ -n "${current_video_profile}" ]]; then
        printf 'HDMI video profile changed: %s -> %s\n' \
            "${current_video_profile}" "${VIDEO_PROFILE}"
    else
        printf 'HDMI video profile is not recorded; rebuilding for %s mode.\n' \
            "${VIDEO_PROFILE}"
    fi

    rm -f \
        "${HAZARD3_SYNTH}/fpga_ulx3s.json" \
        "${HAZARD3_SYNTH}/fpga_ulx3s.config" \
        "${HAZARD3_SYNTH}/fpga_ulx3s.bit" \
        "${HAZARD3_SYNTH}/fpga_ulx3s.svf"
fi

printf 'HDMI video profile: %s (extended modes=%s)\n' \
    "${VIDEO_PROFILE}" "${HAZARD3_HDMI_EXTENDED_MODES}"

# Synthesize once before starting concurrent routes. The synthesized JSON and
# LPF are read-only inputs for every seed; all route outputs are seed-specific.
make -C "${HAZARD3_SYNTH}" -f ULX3S.mk \
    HAZARD3_HDMI_EXTENDED_MODES="${HAZARD3_HDMI_EXTENDED_MODES}" synth

if [[ ! -s "${HAZARD3_SYNTH}/fpga_ulx3s.json" ]]; then
    echo "Synthesis completed without creating ${HAZARD3_SYNTH}/fpga_ulx3s.json" >&2
    exit 1
fi

printf '%s\n' "${VIDEO_PROFILE}" > "${SYNTH_PROFILE_STAMP}"

# 2026-08-18 hi-res (400x240 source framebuffer) placement prescreen:
#   seed 222: clk_sys 46.90 MHz, video 69.11 MHz, TMDS 249.19 MHz
#   seed  60: clk_sys 45.76 MHz, video 74.87 MHz, TMDS 270.64 MHz
#   seed 121: clk_sys 45.38 MHz, video 73.42 MHz, TMDS 255.89 MHz
# Placement timing is a ranking aid only. Select the final default seed from
# completed routed timing.

printf 'Routing %d seed(s):' "${#seeds[@]}"
printf ' %s' "${seeds[@]}"
printf '\n'
printf 'Concurrent route jobs: %s\n' "${SWEEP_JOBS}"

run_seed()
{
    local NEXTPNR_SEED="$1"
    local pnr_log="${ULX3S_SEED_SWEEP_DIR}/pnr-${NEXTPNR_SEED}.log"
    local failed_log="${ULX3S_SEED_SWEEP_DIR}/pnr-${NEXTPNR_SEED}-failed.log"
    local config="${ULX3S_SEED_SWEEP_DIR}/fpga_ulx3s-${NEXTPNR_SEED}.config"
    local svf="${ULX3S_SEED_SWEEP_DIR}/fpga_ulx3s-${NEXTPNR_SEED}.svf"
    local bit="${ULX3S_SEED_SWEEP_DIR}/fpga_ulx3s-${NEXTPNR_SEED}.bit"
    local timing_line

    printf '\nTrying nextpnr seed %s\n' "${NEXTPNR_SEED}"

    # Prevent a failed build from being mistaken for artifacts from an earlier
    # run of the same seed.
    rm -f "${pnr_log}" "${failed_log}" "${config}" "${svf}" "${bit}"

    if ! nextpnr-ecp5 \
        --seed "${NEXTPNR_SEED}" \
        --placer heap \
        --um5g-85k \
        --package CABGA381 \
        --lpf "${HAZARD3_SYNTH}/fpga_ulx3s.lpf" \
        --json "${HAZARD3_SYNTH}/fpga_ulx3s.json" \
        --textcfg "${config}" \
        "${timing_options[@]}" \
        --quiet \
        --log "${pnr_log}"
    then
        printf 'Seed %s failed\n' "${NEXTPNR_SEED}" >&2
        if [[ -f "${pnr_log}" ]]; then
            mv "${pnr_log}" "${failed_log}"
        fi
        rm -f "${config}" "${svf}" "${bit}"
        return 1
    fi

    if ! ecppack \
        --compress \
        --svf "${svf}" \
        --idcode 0x41113043 \
        "${config}" \
        "${bit}"
    then
        printf 'Seed %s ecppack failed\n' "${NEXTPNR_SEED}" >&2
        mv "${pnr_log}" "${failed_log}"
        rm -f "${config}" "${svf}" "${bit}"
        return 1
    fi

    if [[ ! -f "${pnr_log}" || ! -f "${bit}" ]]; then
        printf 'Seed %s build returned success but expected artifacts are missing.\n' \
            "${NEXTPNR_SEED}" >&2
        if [[ -f "${pnr_log}" ]]; then
            mv "${pnr_log}" "${failed_log}"
        fi
        rm -f "${config}" "${svf}" "${bit}"
        return 1
    fi

    rm -f "${failed_log}" "${config}" "${svf}"

    while IFS= read -r timing_line; do
        printf 'Seed %s: %s\n' "${NEXTPNR_SEED}" "${timing_line}"
    done < <(grep 'Max frequency for clock' "${pnr_log}" || true)
}

run_sweep()
{
    local status=0
    local running=0
    local seed

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

    return "${status}"
}

run_sweep |& tee "${ULX3S_SEED_SWEEP_DIR}/summary.log"
status=${PIPESTATUS[0]}

exit "${status}"
