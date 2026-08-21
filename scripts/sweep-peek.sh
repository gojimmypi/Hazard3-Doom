#!/bin/bash
set -euo pipefail

# File: scripts/sweep-peek.sh
#
# Example:
#
#  SWEEP_JOBS=8 ./scripts/sweep-peek.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
HAZARD3_ROOT="${HAZARD3_ROOT:-${REPO_ROOT}/third_party/Hazard3}"
SYNTH_DIR="${HAZARD3_ROOT}/example_soc/synth"
SWEEP_JOBS="${SWEEP_JOBS:-4}"
HAZARD3_HDMI_EXTENDED_MODES="${HAZARD3_HDMI_EXTENDED_MODES:-1}"
SYNTH_PROFILE_STAMP="${SYNTH_DIR}/fpga_ulx3s.video-profile"

usage()
{
    echo "Usage: $0 [seed]" >&2
    echo "  no seed  Sweep seeds 1 through 260" >&2
    echo "  seed     Run placement-only check for one seed (1-260)" >&2
    echo "  SWEEP_JOBS=N  Run up to N placement checks concurrently (default: 4)" >&2
    echo "  HAZARD3_HDMI_EXTENDED_MODES=0|1  Select standard or extended video profile (default: 1)" >&2
}

require_tool()
{
    local tool="$1"

    command -v "${tool}" >/dev/null 2>&1 || {
        echo "Missing required tool: ${tool}" >&2
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

case "${HAZARD3_HDMI_EXTENDED_MODES}" in
0)
    VIDEO_PROFILE="standard"
    ;;
1)
    VIDEO_PROFILE="extended"
    ;;
*)
    echo "HAZARD3_HDMI_EXTENDED_MODES must be 0 or 1" >&2
    usage
    exit 1
    ;;
esac

SWEEP_DIR="placement-sweep/${VIDEO_PROFILE}"

if (( $# == 1 )); then
    seed_arg="$1"

    if [[ ! "${seed_arg}" =~ ^[0-9]+$ ]] ||
       (( seed_arg < 1 || seed_arg > 260 )); then
        echo "Invalid seed: ${seed_arg}; expected 1-260." >&2
        usage
        exit 1
    fi

    seeds=("${seed_arg}")
    results_file="${SWEEP_DIR}/results-seed-${seed_arg}.csv"
else
    mapfile -t seeds < <(seq 1 260)
    results_file="${SWEEP_DIR}/results.csv"
fi

require_tool make
require_tool yosys
require_tool nextpnr-ecp5
require_tool sha256sum

[[ -f "${SYNTH_DIR}/fpga_ulx3s.lpf" ]] || {
    echo "Missing ${SYNTH_DIR}/fpga_ulx3s.lpf" >&2
    exit 1
}

netlist_sha256_before=""
if [[ -s "${SYNTH_DIR}/fpga_ulx3s.json" ]]; then
    netlist_sha256_before="$(sha256sum "${SYNTH_DIR}/fpga_ulx3s.json" | awk '{print $1}')"
fi

current_video_profile=""
if [[ -f "${SYNTH_PROFILE_STAMP}" ]]; then
    read -r current_video_profile < "${SYNTH_PROFILE_STAMP}" || true
fi

if [[ ! -s "${SYNTH_DIR}/fpga_ulx3s.json" ||
      "${current_video_profile}" != "${VIDEO_PROFILE}" ]]; then
    if [[ -n "${current_video_profile}" &&
          "${current_video_profile}" != "${VIDEO_PROFILE}" ]]; then
        printf 'HDMI video profile changed: %s -> %s\n' \
            "${current_video_profile}" "${VIDEO_PROFILE}"
    elif [[ -s "${SYNTH_DIR}/fpga_ulx3s.json" ]]; then
        printf 'HDMI video profile is not recorded; rebuilding for %s mode.\n' \
            "${VIDEO_PROFILE}"
    else
        printf 'Synthesized ULX3S netlist is missing; building for %s mode.\n' \
            "${VIDEO_PROFILE}"
    fi

    rm -f \
        "${SYNTH_DIR}/fpga_ulx3s.json" \
        "${SYNTH_DIR}/fpga_ulx3s.config" \
        "${SYNTH_DIR}/fpga_ulx3s.bit" \
        "${SYNTH_DIR}/fpga_ulx3s.svf"
fi

printf 'HDMI video profile: %s (extended modes=%s)\n' \
    "${VIDEO_PROFILE}" "${HAZARD3_HDMI_EXTENDED_MODES}"

# Always ask make to ensure the synthesized netlist is current. This is a no-op
# when the selected profile and source dependencies are already up to date.
make -C "${SYNTH_DIR}" -f ULX3S.mk \
    HAZARD3_HDMI_EXTENDED_MODES="${HAZARD3_HDMI_EXTENDED_MODES}" synth

[[ -s "${SYNTH_DIR}/fpga_ulx3s.json" ]] || {
    echo "Synthesis completed without creating ${SYNTH_DIR}/fpga_ulx3s.json" >&2
    exit 1
}

printf '%s\n' "${VIDEO_PROFILE}" > "${SYNTH_PROFILE_STAMP}"

netlist_sha256="$(sha256sum "${SYNTH_DIR}/fpga_ulx3s.json" | awk '{print $1}')"
if [[ -n "${netlist_sha256_before}" &&
      "${netlist_sha256_before}" != "${netlist_sha256}" ]]; then
    printf 'Synthesized netlist changed; invalidating routed FPGA artifacts.\n'
    rm -f \
        "${SYNTH_DIR}/fpga_ulx3s.config" \
        "${SYNTH_DIR}/fpga_ulx3s.bit" \
        "${SYNTH_DIR}/fpga_ulx3s.svf"
fi

cd "${SYNTH_DIR}"
mkdir -p "${SWEEP_DIR}"

{
    printf 'video_profile=%s\n' "${VIDEO_PROFILE}"
    printf 'hazard3_hdmi_extended_modes=%s\n' "${HAZARD3_HDMI_EXTENDED_MODES}"
    printf 'netlist_sha256=%s\n' "${netlist_sha256}"
    printf 'netlist=fpga_ulx3s.json\n'
    printf 'generated_utc=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
} > "${SWEEP_DIR}/metadata.txt"

printf 'Placement sweep netlist SHA256: %s\n' "${netlist_sha256}"
printf 'Placement sweep directory: %s/%s\n' "${SYNTH_DIR}" "${SWEEP_DIR}"

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
    local log="${SWEEP_DIR}/seed-${seed}.log"
    local result="${SWEEP_DIR}/result-seed-${seed}.csv"
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
    rm -f "${SWEEP_DIR}/result-seed-${seed}.csv"
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
        result="${SWEEP_DIR}/result-seed-${seed}.csv"
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
