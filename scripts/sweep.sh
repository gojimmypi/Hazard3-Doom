#!/bin/bash

set -u -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
HAZARD3_ROOT="${HAZARD3_ROOT:-${REPO_ROOT}/third_party/Hazard3}"
HAZARD3_SYNTH="${HAZARD3_ROOT}/example_soc/synth"
ULX3S_SEED_SWEEP_DIR="${REPO_ROOT}/build/ulx3s-seed-sweep"

usage()
{
    cat >&2 <<EOF_USAGE
Usage: $0 SEED [SEED ...]
       $0 SEED[,SEED...]
       $0 --all

Route one or more nextpnr seeds for the ULX3S 85F Hazard3-Doom build.
Seeds must be decimal values from 1 through 260.

Examples:
    $0 222
    $0 222 60 121
    $0 222,60,121
    $0 --all
EOF_USAGE
}

if (( $# == 0 )); then
    usage
    exit 1
fi

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

mkdir -p "${ULX3S_SEED_SWEEP_DIR}"

# 2026-08-18 hi-res (400x240 source framebuffer) placement prescreen:
#   seed 222: clk_sys 46.90 MHz, video 69.11 MHz, TMDS 249.19 MHz
#   seed  60: clk_sys 45.76 MHz, video 74.87 MHz, TMDS 270.64 MHz
#   seed 121: clk_sys 45.38 MHz, video 73.42 MHz, TMDS 255.89 MHz
# Placement timing is a ranking aid only. Select the final default seed from
# completed routed timing.

printf 'Routing %d seed(s):' "${#seeds[@]}"
printf ' %s' "${seeds[@]}"
printf '\n'

for NEXTPNR_SEED in "${seeds[@]}"
do
    printf '\nTrying nextpnr seed %s\n' "${NEXTPNR_SEED}"

    # Prevent a failed build from being mistaken for artifacts left by the
    # preceding seed.
    rm -f "${HAZARD3_SYNTH}/pnr.log" \
        "${HAZARD3_SYNTH}/fpga_ulx3s.bit"

    if HAZARD3_ROOT="${HAZARD3_ROOT}" \
        NEXTPNR_SEED="${NEXTPNR_SEED}" \
        "${SCRIPT_DIR}/build-ulx3s-85f-bitstream.sh"
    then
        if [[ ! -f "${HAZARD3_SYNTH}/pnr.log" || \
              ! -f "${HAZARD3_SYNTH}/fpga_ulx3s.bit" ]]; then
            printf 'Seed %s build returned success but expected artifacts are missing.\n' \
                "${NEXTPNR_SEED}" >&2
            continue
        fi

        rm -f "${ULX3S_SEED_SWEEP_DIR}/pnr-${NEXTPNR_SEED}-failed.log"

        cp "${HAZARD3_SYNTH}/pnr.log" \
            "${ULX3S_SEED_SWEEP_DIR}/pnr-${NEXTPNR_SEED}.log"

        cp "${HAZARD3_SYNTH}/fpga_ulx3s.bit" \
            "${ULX3S_SEED_SWEEP_DIR}/fpga_ulx3s-${NEXTPNR_SEED}.bit"

        grep 'Max frequency for clock' \
            "${ULX3S_SEED_SWEEP_DIR}/pnr-${NEXTPNR_SEED}.log" || true
    else
        printf 'Seed %s failed\n' "${NEXTPNR_SEED}" >&2

        if [[ -f "${HAZARD3_SYNTH}/pnr.log" ]]; then
            cp "${HAZARD3_SYNTH}/pnr.log" \
                "${ULX3S_SEED_SWEEP_DIR}/pnr-${NEXTPNR_SEED}-failed.log"
        fi
    fi
done |& tee "${ULX3S_SEED_SWEEP_DIR}/summary.log"
