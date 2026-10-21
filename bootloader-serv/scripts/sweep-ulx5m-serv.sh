#!/usr/bin/env bash
# Re-route the existing ULX5M-GS SERV netlist with independent seeds.
# Does not modify the baseline implementation, generate a bitstream,
# access JTAG, or write flash.
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: ./scripts/sweep-ulx5m-serv.sh [first-seed [number-of-seeds]]
Defaults: first-seed=1, number-of-seeds=8 (maximum 100).
Run after: make -f Makefile.ulx5m-gs flash-read-serv
Inputs: build-ulx5m-gs/top_ulx5m_gs_flash_read-serv.json, flash-read CCF/SDC.
Outputs: timestamped build-ulx5m-gs/serv-seed-sweep-* directory.
This is timing-only place-and-route. No FPGA programming or flash writes.
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
    echo 'ERROR: seeds and count must be decimal integers.' >&2
    exit 2
fi
if (( 10#$first_seed < 1 || 10#$seed_count < 1 || 10#$seed_count > 100 )); then
    echo 'ERROR: first seed >= 1, count 1..100 required.' >&2
    exit 2
fi
first_seed=$((10#$first_seed))
seed_count=$((10#$seed_count))

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd -- "$script_dir/.."

pnr=${NEXTPNR:-nextpnr-himbaechel}
if ! command -v "$pnr" >/dev/null 2>&1; then
    echo "ERROR: nextpnr executable unavailable: $pnr" >&2
    exit 1
fi

build_dir=build-ulx5m-gs
json=$build_dir/top_ulx5m_gs_flash_read-serv.json
ccf=data/top-ulx5m-gs-flash-read.ccf
sdc=data/top-ulx5m-gs-flash-read.sdc
for required in "$json" "$ccf" "$sdc"; do
    if [[ ! -s $required ]]; then
        echo "ERROR: missing/empty input: $required" >&2
        exit 1
    fi
done

run_id=$(date -u +%Y%m%dT%H%M%SZ)-$$
run_dir=$build_dir/serv-seed-sweep-$run_id
mkdir -- "$run_dir"
sha256sum "$json" "$ccf" "$sdc" > "$run_dir/inputs.sha256"
report=$run_dir/results.tsv
printf 'seed\texit_code\tfmax_mhz\ttiming\tlog\n' > "$report"

printf 'ULX5M-GS SERV timing sweep, seed=%s, count=%s\n' "$first_seed" "$seed_count"
printf 'JSON: %s\nResults: %s\n' "$json" "$run_dir"
printf 'No RTL changes, bitstream generation, JTAG programming, or flash writes.\n'

pass_count=0
best_seed=''
best_fmax=''
regex='Max frequency for clock .*: ([0-9]+([.][0-9]+)?) MHz \((PASS|FAIL) at'
for (( i = 0; i < seed_count; i++ )); do
    seed=$((first_seed + i))
    prefix=$run_dir/seed-$seed
    impl=$prefix.txt
    log=$prefix.log
    stdout=$prefix.stdout.log

    printf '\nRouting seed %d (%d/%d)...\n' "$seed" "$((i + 1))" "$seed_count"
    rc=0
    "$pnr" --device CCGM1A1 \
        --json "$(realpath "$json")" \
        -o "ccf=$(realpath "$ccf")" \
        -o "out=$(realpath -m "$impl")" \
        --sdc "$(realpath "$sdc")" \
        --router router2 --placer-heap-beta=0.6 \
        --seed "$seed" -l "$(realpath -m "$log")" \
        > "$stdout" 2>&1 || rc=$?

    fmax='-'
    timing='NO_REPORT'
    if [[ -f $log ]]; then
        # Use the last Fmax result (post-route), not the placement estimate.
        while IFS= read -r line; do
            if [[ $line =~ $regex ]]; then
                fmax=${BASH_REMATCH[1]}
                timing=${BASH_REMATCH[3]}
            fi
        done < "$log"
    fi

    if [[ $timing == PASS && $rc -eq 0 && -s $impl ]]; then
        pass_count=$((pass_count + 1))
    elif [[ $timing == PASS ]]; then
        timing='ERROR'
    fi

    printf '%d\t%d\t%s\t%s\t%s\n' "$seed" "$rc" "$fmax" "$timing" "$log" >> "$report"
    printf 'Seed %d: %s MHz, %s (nextpnr exit %d)\n' "$seed" "$fmax" "$timing" "$rc"

    if [[ $fmax != '-' && $timing == PASS ]]; then
        if [[ -z $best_fmax ]] || awk -v candidate="$fmax" -v previous="$best_fmax" \
            'BEGIN { exit !(candidate+0 > previous+0) }'; then
            best_fmax=$fmax
            best_seed=$seed
        fi
    fi
done

printf '\nSummary:\n'
cat "$report"
printf '\nPASS: %d/%d\n' "$pass_count" "$seed_count"
if [[ -n $best_seed ]]; then
    printf 'Best passing route: seed %s, %s MHz\n' "$best_seed" "$best_fmax"
    printf 'Implementation: %s/seed-%s.txt\n' "$run_dir" "$best_seed"
else
    printf 'No passing route found.\n'
fi
printf 'Results directory: %s\n' "$run_dir"
