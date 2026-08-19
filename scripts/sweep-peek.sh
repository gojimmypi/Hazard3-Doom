#!/bin/bash
set -euo pipefail

# File: scripts/sweep-peek.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNTH_DIR="${SCRIPT_DIR}/../third_party/Hazard3/example_soc/synth"

usage()
{
    echo "Usage: $0 [seed]" >&2
    echo "  no seed  Sweep seeds 1 through 260" >&2
    echo "  seed     Run placement-only check for one seed (1-260)" >&2
}

if (( $# > 1 )); then
    usage
    exit 1
fi

if (( $# == 1 )); then
    seed_arg="$1"

    if [[ ! "${seed_arg}" =~ ^[0-9]+$ ]] ||
       (( seed_arg < 1 || seed_arg > 260 )); then
        echo "Invalid seed: ${seed_arg}; expected 1-260." >&2
        usage
        exit 1
    fi

    seeds=("${seed_arg}")
    results_file="placement-sweep/results-seed-${seed_arg}.csv"
else
    mapfile -t seeds < <(seq 1 260)
    results_file="placement-sweep/results.csv"
fi

cd "${SYNTH_DIR}"

[[ -f fpga_ulx3s.json ]] || {
    echo "Missing ${SYNTH_DIR}/fpga_ulx3s.json" >&2
    echo "Build/synthesize the FPGA design before running the placement sweep." >&2
    exit 1
}

[[ -f fpga_ulx3s.lpf ]] || {
    echo "Missing ${SYNTH_DIR}/fpga_ulx3s.lpf" >&2
    exit 1
}

mkdir -p placement-sweep

printf "seed,clk_sys_mhz,clk_video_mhz,clk_tmds_mhz\n" \
    > "${results_file}"

for seed in "${seeds[@]}"; do
    log="placement-sweep/seed-${seed}.log"

    echo "=== placement seed ${seed} ==="

    nextpnr-ecp5 \
        --placer heap \
        --um5g-85k \
        --package CABGA381 \
        --lpf fpga_ulx3s.lpf \
        --json fpga_ulx3s.json \
        --seed "${seed}" \
        --timing-allow-fail \
        --no-route \
        >"${log}" 2>&1

    clk_sys="$(
        grep "Max frequency for clock.*clk_sys" "${log}" |
            tail -n 1 |
            sed -E 's/.*: ([0-9.]+) MHz.*/\1/'
    )"

    clk_video="$(
        grep "Max frequency for clock.*clk_video_pix" "${log}" |
            tail -n 1 |
            sed -E 's/.*: ([0-9.]+) MHz.*/\1/'
    )"

    clk_tmds="$(
        grep "Max frequency for clock.*clk_tmds_x5" "${log}" |
            tail -n 1 |
            sed -E 's/.*: ([0-9.]+) MHz.*/\1/'
    )"

    printf "%d,%s,%s,%s\n" \
        "${seed}" "${clk_sys}" "${clk_video}" "${clk_tmds}" |
        tee -a "${results_file}"
done

echo
echo "Results: ${SYNTH_DIR}/${results_file}"
