#!/usr/bin/env bash
# Route existing ULX5M flash-read synthesis JSON with multiple placement seeds.
# Does not synthesize, create a bitstream, program SRAM, or write SPI flash.
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: sweep-ulx5m-flash-read.sh [first-seed [number-of-seeds]]

Defaults: first-seed=1, number-of-seeds=8.
Run after make -f Makefile.ulx5m-gs has generated
build-ulx5m-gs/top_ulx5m_gs_flash_read.json.

Each seed gets separate routing output and logs. No working build output
is overwritten. A reported PASS is not a hardware validation.
USAGE
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
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
    echo 'ERROR: seed and count must be positive decimal integers.' >&2
    exit 2
fi
if (( first_seed < 1 || seed_count < 1 || seed_count > 100 )); then
    echo 'ERROR: seed >= 1 and 1 <= count <= 100 are required.' >&2
    exit 2
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
bootloader_dir=$(cd -- "$script_dir/.." && pwd)
cd -- "$bootloader_dir"

pnr=${NEXTPNR:-nextpnr-himbaechel}
if ! command -v "$pnr" >/dev/null 2>&1; then
    echo "ERROR: nextpnr executable not found: $pnr" >&2
    exit 1
fi

build_dir=build-ulx5m-gs
json=$build_dir/top_ulx5m_gs_flash_read.json
ccf=data/top-ulx5m-gs-flash-read.ccf
sdc=data/top-ulx5m-gs-flash-read.sdc
for required in "$json" "$ccf" "$sdc"; do
    if [[ ! -s $required ]]; then
        echo "ERROR: missing/empty input: $required" >&2
        echo 'Build flash-read synthesis JSON first; no RTL synthesis is done here.' >&2
        exit 1
    fi
done

run_id=$(date -u +%Y%m%dT%H%M%SZ)-$$
run_dir=$build_dir/flash-read-seed-sweep-$run_id
mkdir -- "$run_dir"
sha256sum "$json" "$ccf" "$sdc" > "$run_dir/inputs.sha256"
report=$run_dir/results.tsv
printf 'seed\texit_code\tfmax_mhz\ttiming\tlog\n' > "$report"

printf 'ULX5M flash-read timing-only seed sweep: %s seeds starting at %s\n' "$seed_count" "$first_seed"
printf 'Synthesized design: %s\nResults: %s\n' "$json" "$run_dir"
printf 'No RTL changes; no SRAM programming or flash writes.\n'

pass_count=0
for (( i = 0; i < seed_count; i++ )); do
    seed=$((first_seed + i))
    prefix=$run_dir/seed-$seed
    impl=$prefix.txt
    log=$prefix.log
    stdout=$prefix.stdout.log

    printf '\nRouting seed %d (%d/%d)...\n' "$seed" "$((i+1))" "$seed_count"
    rc=0
    "$pnr" --device CCGM1A1 \
        --json "$(realpath "$json")" \
        -o "ccf=$(realpath "$ccf")" \
        -o "out=$(realpath -m "$impl")" \
        --sdc "$(realpath "$sdc")" \
        --router router2 --placer-heap-beta=0.6 \
        --seed "$seed" -l "$(realpath -m "$log")" \
        > "$stdout" 2>&1 || rc=$?

    # Use the FINAL routed result (not the earlier placement estimate).
    timing_line=''
    if [[ -f $log ]]; then
        timing_line=$(grep -E "Max frequency for clock 'bram_i\.clk':" "$log" | tail -n 1 || true)
    fi
    parsed=$(printf '%s\n' "$timing_line" | sed -nE 's/.*: ([0-9]+([.][0-9]+)?) MHz \((PASS|FAIL) at [0-9]+([.][0-9]+)? MHz\).*/\1\t\3/p')
    fmax='-'
    timing='NO_REPORT'
    if [[ -n $parsed ]]; then
        IFS=$'\t' read -r fmax timing <<< "$parsed"
    fi

    # A log PASS is not enough if the tool failed for another reason.
    if [[ $timing == PASS && $rc -eq 0 && -s $impl ]]; then
        pass_count=$((pass_count + 1))
    elif [[ $timing == PASS ]]; then
        timing='ERROR'
    fi
    printf '%d\t%d\t%s\t%s\t%s\n' "$seed" "$rc" "$fmax" "$timing" "$log" >> "$report"
    printf 'Seed %d: %s MHz, %s (nextpnr exit %d)\n' "$seed" "$fmax" "$timing" "$rc"
done

printf '\nFinal routed results (tab-separated):\n'
cat "$report"
printf '\nBest routed Fmax: '
awk -F '\t' 'NR > 1 && $3 != "-" && (!found || $3 + 0 > best) { found = 1; best = $3 + 0; seed = $1; state = $4 } END { if (found) printf "%.2f MHz (seed %s, %s)\n", best, seed, state; else print "none" }' "$report"
printf 'PASS results: %d/%d\n' "$pass_count" "$seed_count"
printf 'Logs and routed implementations: %s\n' "$run_dir"

if (( pass_count == 0 )); then
    echo 'No passing route. Do not program a flash-read bitstream.' >&2
    exit 1
fi

echo 'Timing PASS found. Review its margin and constraints before any hardware trial.'
