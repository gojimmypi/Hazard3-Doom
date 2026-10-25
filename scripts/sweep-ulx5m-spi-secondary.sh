#!/usr/bin/env bash
# Offline v47 SPI-active secondary primary seed sweep. Never programs hardware.
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: scripts/sweep-ulx5m-spi-secondary.sh FIRST_SEED COUNT [TIMEOUT_SECONDS]
Synthesize v47 SPI secondary once; sweep independent GateMate routing seeds.
To route a frozen CI netlist, set SWEEP_SKIP_SYNTH=1 and SWEEP_JSON/CCF/SDC.
SWEEP_OUTPUT_DIR, SWEEP_HEAP_BETA, SWEEP_NEXTPNR_EXTRA_ARGS,
SWEEP_RETAIN_BITSTREAMS, SWEEP_ALLOW_NO_PASS match the existing sweep.
PASS candidates are gmpack --bootaddr 0x201000 primary images, not plain bits.
No FPGA loading, flash writing, or hardware operation occurs.
USAGE
}
if [[ ${1:-} == --help || ${1:-} == -h ]]; then
    usage
    exit 0
fi
if (( $# < 2 || $# > 3 )); then
    usage >&2
    exit 2
fi
for value in "$@"; do
    if [[ ! $value =~ ^[0-9]{1,9}$ ]]; then
        echo 'ERROR: numeric inputs required.' >&2
        exit 2
    fi
done
first=$((10#$1))
count=$((10#$2))
route_timeout=$((10#${3:-180}))
if (( first < 1 || count < 1 || count > 100 || route_timeout < 1 || route_timeout > 600 ||
      count * route_timeout > 19800 || first + count - 1 > 2147483647 )); then
    echo 'ERROR: seed/count/timeout out of supported range.' >&2
    exit 2
fi
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(cd -- "$script_dir/.." && pwd)
source_dir="$root/bootloader-serv"
profile_dir="$source_dir/build-ulx5m-gs/normal-boot-dfu-hw-native"
json=${SWEEP_JSON:-$profile_dir/spi-secondary.json}
ccf=${SWEEP_CCF:-$source_dir/data/top-ulx5m-gs-flash-read.ccf}
sdc=${SWEEP_SDC:-$source_dir/data/top-ulx5m-gs-flash-read.sdc}
heap_beta=${SWEEP_HEAP_BETA:-0.6}
if [[ ! $heap_beta =~ ^0\.[0-9]+$ ]]; then
    echo 'ERROR: invalid HeAP beta.' >&2
    exit 2
fi
read -r -a extra_args <<< "${SWEEP_NEXTPNR_EXTRA_ARGS:-}" || true
if [[ -n ${SWEEP_OUTPUT_DIR:-} ]]; then
    mkdir -p -- "$SWEEP_OUTPUT_DIR"
    result_dir=$(cd -- "$SWEEP_OUTPUT_DIR" && pwd)
else
    result_dir="$profile_dir/seed-sweeps/$(date -u +%Y%m%dT%H%M%SZ)-$$"
    mkdir -p -- "$result_dir"
fi
pnr=${NEXTPNR:-nextpnr-himbaechel}
for tool in "$pnr" gmpack timeout awk sort sha256sum python3; do
    command -v "$tool" >/dev/null 2>&1 || { echo "ERROR: missing tool: $tool" >&2; exit 1; }
done
if [[ ${SWEEP_SKIP_SYNTH:-0} != 1 ]]; then
    make -C "$source_dir" -f Makefile.ulx5m-spi-secondary \
        build-ulx5m-gs/normal-boot-dfu-hw-native/spi-secondary.json
fi
for path in "$json" "$ccf" "$sdc"; do
    [[ -s $path ]] || { echo "ERROR: missing input: $path" >&2; exit 1; }
done
# The group summary script compares these hashes with the frozen manifest.
sha256sum "$json" "$ccf" "$sdc" > "$result_dir/inputs.sha256"
{
    printf 'target=spi-secondary\n'
    printf 'commit=%s\n' "${GITHUB_SHA:-local}"
    printf 'bootaddr=0x201000\n'
    printf 'netlist_sha256=%s\n' "$(sha256sum "$json" | awk '{print $1}')"
    "$pnr" --version 2>&1
    gmpack --version 2>&1 || true
} > "$result_dir/build-info.txt"
results="$result_dir/results.tsv"
printf 'seed\tstatus\tfmax_mhz\tmargin_mhz\texit_code\telapsed_seconds\tlog\n' > "$results"
passes=0
fails=0
timeouts=0
errors=0
best_seed=''
best_fmax=''
for (( i=0; i<count; i++ )); do
    seed=$((first + i))
    impl="$result_dir/seed-$seed.txt"
    log="$result_dir/seed-$seed.log"
    stdout="$result_dir/seed-$seed.stdout.log"
    start=$SECONDS
    rc=0
    timeout --signal=TERM --kill-after=10s "${route_timeout}s" \
        "$pnr" --device CCGM1A1 --json "$json" \
        -o "ccf=$ccf" -o "out=$impl" --sdc "$sdc" \
        --router router2 --placer-heap-beta="$heap_beta" \
        "${extra_args[@]}" --seed "$seed" -l "$log" > "$stdout" 2>&1 || rc=$?
    elapsed=$((SECONDS - start))
    status=ERROR
    fmax=-
    margin=-
    timing_line=''
    if [[ -s $log ]]; then
        timing_line=$(grep -F "Max frequency for clock 'bram_i.clk':" "$log" | tail -n 1 || true)
    fi
    if (( rc == 124 || rc == 137 )); then
        status=TIMEOUT
    elif [[ -n $timing_line && -s $log ]] && grep -Fq 'Routing complete.' "$log"; then
        fmax=${timing_line##*: }
        fmax=${fmax%% MHz*}
        if [[ $fmax =~ ^[0-9]+([.][0-9]+)?$ ]]; then
            margin=$(awk -v f="$fmax" 'BEGIN {printf "%.2f", f - 48.00}')
            if [[ $timing_line == *'(PASS at 48.00 MHz)'* && $rc -eq 0 && -s $impl ]]; then
                # Packing is part of PASS qualification; use the SAME secondary
                # boot address as Makefile.ulx5m-spi-secondary.
                bit="$result_dir/seed-$seed.bit"
                if gmpack --bootaddr 2101248 "$impl" "$bit" >> "$stdout" 2>&1 && \
                    python3 "$source_dir/tests/inspect-ulx5m-v47-primary.py" "$bit" >> "$stdout" 2>&1; then
                    status=PASS
                else
                    echo "ERROR: gmpack/bootaddr validation failed for seed $seed" >&2
                    rm -f -- "$bit"
                fi
            elif [[ $timing_line == *'(FAIL at 48.00 MHz)'* ]]; then
                status=FAIL
            fi
        else
            fmax=-
        fi
    fi
    if [[ $status == PASS ]]; then
        passes=$((passes + 1))
        if [[ -z $best_seed ]] || awk -v a="$fmax" -v b="$best_fmax" 'BEGIN {exit !(a > b)}'; then
            cp -- "$result_dir/seed-$seed.bit" "$result_dir/best-seed-$seed.bit"
            if [[ -n $best_seed ]]; then
                rm -f -- "$result_dir/best-seed-$best_seed.bit"
            fi
            best_seed=$seed
            best_fmax=$fmax
        fi
        if [[ ${SWEEP_RETAIN_BITSTREAMS:-0} != 1 ]]; then
            rm -f -- "$result_dir/seed-$seed.bit"
        fi
    elif [[ $status == FAIL ]]; then
        fails=$((fails + 1))
    elif [[ $status == TIMEOUT ]]; then
        timeouts=$((timeouts + 1))
    else
        errors=$((errors + 1))
    fi
    printf '%d\t%s\t%s\t%s\t%d\t%d\tseed-%d.log\n' \
        "$seed" "$status" "$fmax" "$margin" "$rc" "$elapsed" "$seed" >> "$results"
    printf 'Seed %d: %s MHz, %s (nextpnr %d)\n' "$seed" "$fmax" "$status" "$rc"
    rm -f -- "$impl"
done
{
    head -n 1 "$results"
    awk -F '\t' 'NR>1 && $2=="PASS"' "$results" | sort -t $'\t' -k4,4nr -k1,1n
} > "$result_dir/passing-ranked.tsv"
if [[ -n $best_seed ]]; then
    sha256sum "$result_dir/best-seed-$best_seed.bit" > "$result_dir/best-bitstream.sha256"
fi
{
    printf '## ULX5M-GS v47 SPI-active secondary timing sweep\n\n'
    printf -- "- Target: \`spi-secondary\`\n"
    printf -- "- Clock: \`bram_i.clk\` 48.00 MHz\n"
    printf -- "- gmpack secondary address: \`0x201000\`\n"
    printf -- '- Seeds: %d..%d\n' "$first" "$((first+count-1))"
    printf -- '- Final: **%d PASS**, %d FAIL, %d TIMEOUT, %d ERROR\n' "$passes" "$fails" "$timeouts" "$errors"
    if [[ -n $best_seed ]]; then
        printf -- '- Best seed: **%d** (%.2f MHz)\n' "$best_seed" "$best_fmax"
    else
        printf -- '- Best seed: **none**\n'
    fi
    printf '\nTiming PASS is not hardware takeover or authorization to write flash zero.\n'
} > "$result_dir/summary.md"
cat "$result_dir/summary.md"
if (( errors > 0 )); then
    exit 1
fi
if (( passes == 0 && ${SWEEP_ALLOW_NO_PASS:-0} != 1 )); then
    exit 1
fi
