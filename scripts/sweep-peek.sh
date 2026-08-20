#!/bin/bash
set -euo pipefail

# File: scripts/sweep-peek.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNTH_DIR="${SCRIPT_DIR}/../third_party/Hazard3/example_soc/synth"
SWEEP_JOBS="${SWEEP_JOBS:-4}"

usage()
{
    echo "Usage: $0 [seed]" >&2
    echo "  no seed  Sweep seeds 1 through 260" >&2
    echo "  seed     Run placement-only check for one seed (1-260)" >&2
    echo "  SWEEP_JOBS=N  Run up to N placement checks concurrently (default: 4)" >&2
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

run_seed()
{
    local seed="$1"
    local log="placement-sweep/seed-${seed}.log"
    local result="placement-sweep/result-seed-${seed}.csv"
    local clk_sys clk_video clk_tmds

    echo "=== placement seed ${seed} ==="

    if ! nextpnr-ecp5 \
        --placer heap \
        --um5g-85k \
        --package CABGA381 \
        --lpf fpga_ulx3s.lpf \
        --json fpga_ulx3s.json \
        --seed "${seed}" \
        --timing-allow-fail \
        --no-route \
        >"${log}" 2>&1; then
        printf "%d,ERROR,ERROR,ERROR\n" "${seed}" > "${result}"
        echo "Seed ${seed}: nextpnr placement failed; see ${log}" >&2
        return 1
    fi

    clk_sys="$(extract_clock "${log}" "clk_sys")"
    clk_video="$(extract_clock "${log}" "clk_video_pix")"
    clk_tmds="$(extract_clock "${log}" "clk_tmds_x5")"

    printf "%d,%s,%s,%s\n" \
        "${seed}" "${clk_sys}" "${clk_video}" "${clk_tmds}" > "${result}"
    cat "${result}"
}

for seed in "${seeds[@]}"; do
    rm -f "placement-sweep/result-seed-${seed}.csv"
done

printf "Concurrent placement jobs: %s\n" "${SWEEP_JOBS}"

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
    printf "seed,clk_sys_mhz,clk_video_mhz,clk_tmds_mhz\n"
    for seed in "${seeds[@]}"; do
        result="placement-sweep/result-seed-${seed}.csv"
        if [[ -f "${result}" ]]; then
            cat "${result}"
        else
            printf "%d,MISSING,MISSING,MISSING\n" "${seed}"
            status=1
        fi
    done
} > "${results_file}"

echo
echo "Results: ${SYNTH_DIR}/${results_file}"

exit "${status}"
