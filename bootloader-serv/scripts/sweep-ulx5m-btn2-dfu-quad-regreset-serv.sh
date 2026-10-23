#!/usr/bin/env bash
# Sweep the isolated ULX5M-GS BTN2 registered-reset FWT3 netlist, without loading a board.
# One Yosys netlist per sweep; independently seeded nextpnr routes.
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: ./bootloader-serv/scripts/sweep-ulx5m-btn2-dfu-quad-regreset-serv.sh [first-seed [count]]
Defaults: first-seed=1, count=32 (maximum 100 per invocation).
Build target: top_ulx5m_gs_flash_read-serv-dfu-hw-quad-btn2-regreset.json
Outputs: bootloader-serv/build-ulx5m-gs/btn2-dfu-quad-regreset-seed-sweep-*/

Rebuilds the BTN2 JSON if required, snapshots the JSON/CCF/SDC, and routes
that same snapshot for every seed. No bitstream, JTAG, USB, or flash access.
USAGE
}

if [[ ${1:-} == -h || ${1:-} == --help ]]; then
    usage
    exit 0
fi
if (( $# > 2 )); then
    usage >&2
    exit 2
fi
first_seed=${1:-1}
seed_count=${2:-32}
if [[ ! $first_seed =~ ^[0-9]+$ || ! $seed_count =~ ^[0-9]+$ ]]; then
    echo 'ERROR: seed and count must be decimal integers.' >&2
    exit 2
fi
first_seed=$((10#$first_seed))
seed_count=$((10#$seed_count))
if (( first_seed < 1 || seed_count < 1 || seed_count > 100 )); then
    echo 'ERROR: first seed >= 1, count 1..100 required.' >&2
    exit 2
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd -- "$script_dir/.."

pnr=${NEXTPNR:-nextpnr-himbaechel}
if ! command -v "$pnr" >/dev/null 2>&1; then
    echo "ERROR: nextpnr executable unavailable: $pnr" >&2
    exit 1
fi

build_dir=build-ulx5m-gs
json=$build_dir/top_ulx5m_gs_flash_read-serv-dfu-hw-quad-btn2-regreset.json
ccf=data/top-ulx5m-gs-flash-read.ccf
sdc=data/top-ulx5m-gs-flash-read.sdc

# Build only the correct JSON target, not the timing-failing bitstream target.
make -f Makefile.ulx5m-gs "$json"
for required in "$json" "$ccf" "$sdc"; do
    if [[ ! -s $required ]]; then
        echo "ERROR: missing/empty input: $required" >&2
        exit 1
    fi
done

run_id=$(date -u +%Y%m%dT%H%M%SZ)-$$
run_dir=$build_dir/btn2-dfu-quad-regreset-seed-sweep-$run_id
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
    printf 'First seed: %d\nSeed count: %d\n' "$first_seed" "$seed_count"
    printf 'Tool: %s\n' "$pnr"
    "$pnr" --version 2>&1 || true
    if command -v yosys >/dev/null 2>&1; then yosys -V 2>&1; fi
    if command -v git >/dev/null 2>&1; then git rev-parse HEAD 2>/dev/null || true; fi
} > "$run_dir/metadata.txt"

report=$run_dir/results.tsv
printf 'seed\texit_code\tfmax_mhz\ttiming\tlog\n' > "$report"

printf 'ULX5M-GS BTN2 FWT3 registered-reset timing sweep: seeds %d..%d\n' \
    "$first_seed" "$((first_seed + seed_count - 1))"
printf 'Frozen JSON: %s\nResults: %s\n' "$frozen_json" "$run_dir"
printf 'No bitstream generation, FPGA programming, or flash writes.\n'

pass_count=0
best_seed=''
best_fmax=''
best_pass_seed=''
best_pass_fmax=''
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
        --json "$frozen_json" \
        -o "ccf=$frozen_ccf" \
        -o "out=$(realpath -m "$impl")" \
        --sdc "$frozen_sdc" \
        --router router2 --placer-heap-beta=0.6 \
        --seed "$seed" -l "$(realpath -m "$log")" \
        > "$stdout" 2>&1 || rc=$?

    # The first Fmax line is the placement estimate. Use the final routed result.
    fmax='-'
    timing='NO_REPORT'
    if [[ -f $log ]]; then
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
        timing=ERROR
    fi

    printf '%d\t%d\t%s\t%s\t%s\n' "$seed" "$rc" "$fmax" "$timing" "$log" >> "$report"
    printf 'Seed %d: %s MHz, %s (nextpnr exit %d)\n' "$seed" "$fmax" "$timing" "$rc"

    if [[ $fmax != '-' ]]; then
        if [[ -z $best_fmax ]] || awk -v a="$fmax" -v b="$best_fmax" \
            'BEGIN { exit !(a+0 > b+0) }'; then
            best_fmax=$fmax
            best_seed=$seed
        fi
    fi
    if [[ $timing == PASS ]]; then
        if [[ -z $best_pass_fmax ]] || awk -v a="$fmax" -v b="$best_pass_fmax" \
            'BEGIN { exit !(a+0 > b+0) }'; then
            best_pass_fmax=$fmax
            best_pass_seed=$seed
        fi
    fi
done

printf '\nSummary:\n'
cat "$report"
printf '\nPASS: %d/%d\n' "$pass_count" "$seed_count"
if [[ -n $best_seed ]]; then
    printf 'Best reported Fmax: seed %s, %s MHz\n' "$best_seed" "$best_fmax"
else
    printf 'No timing reports found.\n'
fi
if [[ -n $best_pass_seed ]]; then
    printf 'Best passing route: seed %s, %s MHz\n' "$best_pass_seed" "$best_pass_fmax"
    printf 'Implementation: %s/seed-%s.txt\n' "$run_dir" "$best_pass_seed"
else
    printf 'No passing route found.\n'
fi
printf 'Results directory: %s\n' "$run_dir"
