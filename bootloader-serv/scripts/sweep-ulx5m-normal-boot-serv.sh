#!/usr/bin/env bash
# Route the frozen normal-boot SERV JSON with independent seeds.
# Timing-only: no synthesis, bitstream packaging, JTAG, USB, or flash writes.
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: ./scripts/sweep-ulx5m-normal-boot-serv.sh [first-seed [count]]
Defaults: first-seed=1, count=8 (maximum 100 per invocation).
Prerequisite: make -f Makefile.ulx5m-gs normal-boot-firmware
              and an existing build-ulx5m-gs/top_ulx5m_gs_flash_read-normal-boot.json
The latest normal-boot JSON/CCF/SDC are copied into a unique sweep directory.
Routes use the SAME synthesized design and constrained 48 MHz clock.
Each seed is capped at 300 seconds by default to avoid indefinite routing.
Use ULX5M_ROUTE_TIMEOUT_SECONDS=180 to set a shorter cap (30..3600).
No synthesis, bitstream generation, JTAG/USB access, or flash writes.
USAGE
}

if [[ ${1:-} == --help || ${1:-} == -h ]]; then
    usage
    exit 0
fi
if (( $# > 2 )); then
    usage >&2
    exit 2
fi
first_seed=${1:-1}
seed_count=${2:-8}
if [[ ! $first_seed =~ ^[0-9]+$ || ! $seed_count =~ ^[0-9]+$ ]]; then
    printf 'ERROR: seed and count must be decimal integers.\n' >&2
    exit 2
fi
if (( ${#first_seed} > 8 || ${#seed_count} > 3 )); then
    printf 'ERROR: seed or count is too large.\n' >&2
    exit 2
fi
first_seed=$((10#$first_seed))
seed_count=$((10#$seed_count))
if (( first_seed < 1 || seed_count < 1 || seed_count > 100 )); then
    printf 'ERROR: first seed >= 1, count 1..100 required.\n' >&2
    exit 2
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd -- "$script_dir/.."
pnr=${NEXTPNR:-nextpnr-himbaechel}
route_timeout=${ULX5M_ROUTE_TIMEOUT_SECONDS:-300}
if [[ ! $route_timeout =~ ^[0-9]+$ ]] || (( ${#route_timeout} > 4 )); then
    printf 'ERROR: ULX5M_ROUTE_TIMEOUT_SECONDS must be 30..3600.\n' >&2
    exit 2
fi
route_timeout=$((10#$route_timeout))
if (( route_timeout < 30 || route_timeout > 3600 )); then
    printf 'ERROR: ULX5M_ROUTE_TIMEOUT_SECONDS must be 30..3600.\n' >&2
    exit 2
fi
if ! command -v timeout >/dev/null 2>&1; then
    printf 'ERROR: GNU timeout is required for bounded routing.\n' >&2
    exit 1
fi
if ! command -v "$pnr" >/dev/null 2>&1; then
    printf 'ERROR: nextpnr executable unavailable: %s\n' "$pnr" >&2
    exit 1
fi

build_dir=build-ulx5m-gs
json=$build_dir/top_ulx5m_gs_flash_read-normal-boot.json
ccf=data/top-ulx5m-gs-flash-read.ccf
sdc=data/top-ulx5m-gs-flash-read.sdc
for required in "$json" "$ccf" "$sdc"; do
    if [[ ! -s $required ]]; then
        printf 'ERROR: missing/empty input: %s\n' "$required" >&2
        exit 1
    fi
done

run_id=$(date -u +%Y%m%dT%H%M%SZ)-$$
run_dir=$build_dir/normal-boot-seed-sweep-$run_id
mkdir -- "$run_dir"
cp -- "$json" "$run_dir/design.json"
cp -- "$ccf" "$run_dir/design.ccf"
cp -- "$sdc" "$run_dir/design.sdc"
frozen_json=$(realpath "$run_dir/design.json")
frozen_ccf=$(realpath "$run_dir/design.ccf")
frozen_sdc=$(realpath "$run_dir/design.sdc")
sha256sum "$run_dir/design.json" "$run_dir/design.ccf" "$run_dir/design.sdc" > "$run_dir/inputs.sha256"
{
    printf 'Original JSON: %s\n' "$json"
    printf 'First seed: %d\nSeed count: %d\nRoute timeout seconds: %d\n' "$first_seed" "$seed_count" "$route_timeout"
    printf 'Tool: %s\n' "$pnr"
    "$pnr" --version 2>&1 || true
    if command -v yosys >/dev/null 2>&1; then yosys -V 2>&1; fi
    if command -v git >/dev/null 2>&1; then git rev-parse HEAD 2>/dev/null || true; fi
} > "$run_dir/metadata.txt"

report=$run_dir/results.tsv
printf 'seed\texit_code\tfmax_mhz\ttiming\tlog\n' > "$report"
printf 'ULX5M-GS SERV normal-boot sweep: seeds %d..%d\n' \
    "$first_seed" "$((first_seed + seed_count - 1))"
printf 'Frozen JSON: %s\nResults: %s\n' "$frozen_json" "$run_dir"
printf 'Timing-only; NO bitstreams or hardware programming.\n'

pass_count=0
best_seed=''
best_fmax=''
regex="Max frequency for clock 'bram_i[.]clk': ([0-9]+([.][0-9]+)?) MHz [(](PASS|FAIL) at 48[.]00 MHz[)]"
for (( i = 0; i < seed_count; i++ )); do
    seed=$((first_seed + i))
    prefix=$run_dir/seed-$seed
    impl=$prefix.txt
    log=$prefix.log
    stdout=$prefix.stdout.log

    printf '\nRouting seed %d (%d/%d)...\n' "$seed" "$((i + 1))" "$seed_count"
    rc=0
    timeout --signal=TERM --kill-after=15s "${route_timeout}s" "$pnr" --device CCGM1A1 \
        --json "$frozen_json" \
        -o "ccf=$frozen_ccf" \
        -o "out=$(realpath -m "$impl")" \
        --sdc "$frozen_sdc" \
        --router router2 --placer-heap-beta=0.6 \
        --seed "$seed" -l "$(realpath -m "$log")" \
        > "$stdout" 2>&1 || rc=$?

    fmax='-'
    timing='NO_REPORT'
    if [[ -f $log ]]; then
        # Ignore the pre-route estimate: the LAST match is post-route.
        while IFS= read -r line; do
            if [[ $line =~ $regex ]]; then
                fmax=${BASH_REMATCH[1]}
                timing=${BASH_REMATCH[3]}
            fi
        done < "$log"
    fi

    if [[ $rc -eq 124 || $rc -eq 137 ]]; then
        timing=TIMEOUT
        fmax='-'
    fi

    if [[ $timing == PASS && $rc -eq 0 && -s $impl ]]; then
        pass_count=$((pass_count + 1))
        if [[ -z $best_fmax ]] || awk -v a="$fmax" -v b="$best_fmax" \
            'BEGIN { exit !(a+0 > b+0) }'; then
            best_fmax=$fmax
            best_seed=$seed
        fi
    elif [[ $timing == PASS ]]; then
        timing=ERROR
    fi
    printf '%d\t%d\t%s\t%s\t%s\n' "$seed" "$rc" "$fmax" "$timing" "$log" >> "$report"
    if [[ $timing == TIMEOUT ]]; then
        printf 'Seed %d: TIMEOUT after %d seconds (nextpnr exit %d)\n' "$seed" "$route_timeout" "$rc"
    else
        printf 'Seed %d: %s MHz, %s (nextpnr exit %d)\n' "$seed" "$fmax" "$timing" "$rc"
    fi
done

printf '\nSummary:\n'
cat -- "$report"
printf '\nPASS: %d/%d\n' "$pass_count" "$seed_count"
if [[ -n $best_seed ]]; then
    printf 'Best passing seed: %s, %s MHz\n' "$best_seed" "$best_fmax"
    printf 'Implementation: %s/seed-%s.txt\n' "$run_dir" "$best_seed"
    printf 'To package OFFLINE after review: gmpack %s/seed-%s.txt %s/seed-%s.bit\n' \
        "$run_dir" "$best_seed" "$run_dir" "$best_seed"
else
    printf 'No passing route. Do not package or load the timing-failing design.\n'
fi
printf 'Results directory: %s\n' "$run_dir"
