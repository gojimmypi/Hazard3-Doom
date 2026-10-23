#!/usr/bin/env bash
# Sweep GateMate ULX5M bootloader designs using one synthesis per target.
# Offline only: no JTAG, USB programming, SRAM loading, or flash writes.
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: ./scripts/sweep-ulx5m-bootloader.sh TARGET FIRST_SEED COUNT [TIMEOUT_SECONDS]

Targets:
  usb-probe         PicoRV32 USB enumeration probe (bootloader/)
  flash-read-probe  PicoRV32 read-only flash diagnostic (bootloader/)
  flash-read-serv   SERV read-only flash diagnostic (bootloader-serv/)

Defaults: FIRST_SEED=1 COUNT=20 TIMEOUT_SECONDS=180.
CI: SWEEP_SKIP_SYNTH=1 requires SWEEP_JSON, SWEEP_CCF, SWEEP_SDC.
    SWEEP_HEAP_BETA sets HeAP beta (default 0.6).
    SWEEP_ALLOW_NO_PASS=1 retains normal timing failures as valid findings.
COUNT must be 1..100. Set SWEEP_OUTPUT_DIR to override the results directory.
Requires OSS CAD Suite, RISC-V compiler, coreutils timeout, and GNU make.
Builds the firmware and synthesis JSON once, then routes each seed independently.
An FPGA timing PASS is not a USB or hardware validation.
USAGE
}

if [[ ${1:-} == '-h' || ${1:-} == '--help' ]]; then
    usage
    exit 0
fi
if (( $# < 1 || $# > 4 )); then
    usage >&2
    exit 2
fi

target=$1
first_seed=${2:-1}
seed_count=${3:-20}
route_timeout=${4:-180}

for value in "$first_seed" "$seed_count" "$route_timeout"; do
    if [[ ! $value =~ ^[0-9]+$ || ${#value} -gt 9 ]]; then
        echo 'ERROR: FIRST_SEED, COUNT, and TIMEOUT_SECONDS must be decimal integers (up to 9 digits).' >&2
        exit 2
    fi
done
first_seed=$((10#$first_seed))
seed_count=$((10#$seed_count))
route_timeout=$((10#$route_timeout))
if (( first_seed < 1 || seed_count < 1 || seed_count > 100 || route_timeout < 1 || route_timeout > 600 )); then
    echo 'ERROR: FIRST_SEED >= 1, COUNT = 1..100, TIMEOUT_SECONDS = 1..600.' >&2
    exit 2
fi
if (( seed_count * route_timeout > 19800 )); then
    echo 'ERROR: count * timeout may not exceed 19800 seconds per job.' >&2
    exit 2
fi
if (( first_seed + seed_count - 1 > 2147483647 )); then
    echo 'ERROR: seed range exceeds supported integer range.' >&2
    exit 2
fi

case "$target" in
    usb-probe)
        source_subdir=bootloader
        design=top_ulx5m_gs_usb_probe
        constraint_stem=top-ulx5m-gs-usb-probe
        synth_log=usb-probe-synth.log
        ;;
    flash-read-probe)
        source_subdir=bootloader
        design=top_ulx5m_gs_flash_read
        constraint_stem=top-ulx5m-gs-flash-read
        synth_log=flash-read-synth.log
        ;;
    flash-read-serv)
        source_subdir=bootloader-serv
        design=top_ulx5m_gs_flash_read-serv
        constraint_stem=top-ulx5m-gs-flash-read
        synth_log=flash-read-serv-synth.log
        ;;
    *)
        echo "ERROR: unsupported target: $target" >&2
        usage >&2
        exit 2
        ;;
esac

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
source_dir=$repo_root/$source_subdir
build_dir=$source_dir/build-ulx5m-gs
json=${SWEEP_JSON:-$build_dir/$design.json}
ccf=${SWEEP_CCF:-$source_dir/data/$constraint_stem.ccf}
sdc=${SWEEP_SDC:-$source_dir/data/$constraint_stem.sdc}
heap_beta=${SWEEP_HEAP_BETA:-0.6}
if [[ ! $heap_beta =~ ^0[.][0-9]+$ ]]; then
    echo "ERROR: invalid HeAP beta: $heap_beta" >&2
    exit 2
fi
# Extra args are split on whitespace; shell metacharacters are not evaluated.
read -r -a extra_args <<< "${SWEEP_NEXTPNR_EXTRA_ARGS:-}" || true

if [[ -n ${SWEEP_OUTPUT_DIR:-} ]]; then
    mkdir -p -- "$SWEEP_OUTPUT_DIR"
    result_dir=$(cd -- "$SWEEP_OUTPUT_DIR" && pwd)
else
    run_tag=$(date -u +%Y%m%dT%H%M%SZ)-$$
    result_dir=$build_dir/seed-sweeps/$target-$run_tag
    mkdir -p -- "$result_dir"
fi

pnr=${NEXTPNR:-nextpnr-himbaechel}
for tool in "$pnr" yosys make gmpack timeout awk sort sha256sum; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "ERROR: required tool unavailable: $tool" >&2
        exit 1
    fi
done

# Refuse an incompatible local toolchain before synthesizing or routing.
export OSS_CAD_SUITE_VERSION=${OSS_CAD_SUITE_VERSION:-2026-07-20}
bash "$script_dir/check-ulx5m-oss-cad-suite.sh"

printf 'Target: %s\nSeeds: %d..%d\nOSS CAD Suite: %s\n' \
    "$target" "$first_seed" "$((first_seed + seed_count - 1))" "${OSS_CAD_SUITE_VERSION:-not-set}"
printf 'Synthesis once, then place-and-route for each seed.\n'
printf 'No device programming or flash writes.\n'

# Request only the synthesis JSON target; Make automatically builds firmware
# and USB microcode prerequisites. Do not request the normal .bit target here.
if [[ ${SWEEP_SKIP_SYNTH:-0} != 1 ]]; then
    make -C "$source_dir" -f Makefile.ulx5m-gs "build-ulx5m-gs/$design.json"
else
    printf 'Using frozen synthesis inputs; no local synthesis.\n'
fi
for required in "$json" "$ccf" "$sdc"; do
    if [[ ! -s $required ]]; then
        echo "ERROR: missing or empty synthesis input: $required" >&2
        exit 1
    fi
done

if [[ ${SWEEP_SKIP_SYNTH:-0} != 1 ]]; then
    cp -- "$json" "$result_dir/synthesized.json"
fi
if [[ ${SWEEP_SKIP_SYNTH:-0} != 1 && -s $build_dir/$synth_log ]]; then
    cp -- "$build_dir/$synth_log" "$result_dir/$synth_log"
fi
sha256sum "$json" "$ccf" "$sdc" > "$result_dir/inputs.sha256"
{
    printf 'commit=%s\n' "${GITHUB_SHA:-local}"
    printf 'target=%s\n' "$target"
    printf 'source_dir=%s\n' "$source_subdir"
    printf 'first_seed=%s\n' "$first_seed"
    printf 'seed_count=%s\n' "$seed_count"
    printf 'timeout_seconds=%s\n' "$route_timeout"
    printf 'heap_beta=%s\n' "$heap_beta"
    printf 'nextpnr_extra_args=%s\n' "${SWEEP_NEXTPNR_EXTRA_ARGS:-}"
    printf 'oss_cad_suite_version=%s\n' "${OSS_CAD_SUITE_VERSION:-not-set}"
    yosys --version
    "$pnr" --version
    gmpack --version 2>&1 || true
} > "$result_dir/build-info.txt"

report=$result_dir/results.tsv
printf 'seed\tstatus\tfmax_mhz\tmargin_mhz\texit_code\telapsed_seconds\tlog\n' > "$report"

pass_count=0
fail_count=0
timeout_count=0
error_count=0
best_seed=''
best_freq=''
best_impl=$result_dir/best-routed.txt

for (( i = 0; i < seed_count; i++ )); do
    seed=$((first_seed + i))
    impl=$result_dir/seed-$seed.txt
    log=$result_dir/seed-$seed.log
    output_log=$result_dir/seed-$seed.stdout.log
    printf '\nRouting seed %d (%d/%d) ...\n' "$seed" "$((i + 1))" "$seed_count"

    start_time=$SECONDS
    rc=0
    timeout --signal=TERM --kill-after=10s "${route_timeout}s" \
        "$pnr" --device CCGM1A1 \
        --json "$json" \
        -o "ccf=$ccf" -o "out=$impl" --sdc "$sdc" \
        --router router2 --placer-heap-beta="$heap_beta" \
        "${extra_args[@]}" --seed "$seed" -l "$log" > "$output_log" 2>&1 || rc=$?
    elapsed=$((SECONDS - start_time))

    # The FIRST timing line is usually placement-only. The last timing line,
    # after 'Routing complete', is the relevant post-route result.
    timing_line=''
    if [[ -f $log ]]; then
        timing_line=$(grep -F "Max frequency for clock 'bram_i.clk':" "$log" | tail -n 1 || true)
    fi
    fmax='-'
    margin='-'
    status=ERROR
    if (( rc == 124 || rc == 137 )); then
        status=TIMEOUT
        timeout_count=$((timeout_count + 1))
    else
        if [[ -n $timing_line && -f $log ]] && grep -Fq 'Routing complete.' "$log"; then
            fmax=${timing_line##*: }
            fmax=${fmax%% MHz*}
            if [[ ! $fmax =~ ^[0-9]+([.][0-9]+)?$ ]]; then
                fmax='-'
            else
                margin=$(awk -v f="$fmax" 'BEGIN { printf "%.2f", f - 48.0 }')
            fi
            if [[ $timing_line == *'(PASS at 48.00 MHz)'* && $rc -eq 0 && -s $impl ]]; then
                status=PASS
            elif [[ $timing_line == *'(FAIL at 48.00 MHz)'* ]]; then
                status=FAIL
            fi
        fi
        case $status in
            PASS) pass_count=$((pass_count + 1)) ;;
            FAIL) fail_count=$((fail_count + 1)) ;;
            *) error_count=$((error_count + 1)) ;;
        esac
    fi

    printf '%d\t%s\t%s\t%s\t%d\t%d\tseed-%d.log\n' \
        "$seed" "$status" "$fmax" "$margin" "$rc" "$elapsed" "$seed" >> "$report"
    printf 'Seed %d: %s MHz, %s (nextpnr exit %d, %ds)\n' \
        "$seed" "$fmax" "$status" "$rc" "$elapsed"

    # Optionally retain bitstream for each successful seed.
    if [[ $status == PASS && ${SWEEP_RETAIN_BITSTREAMS:-0} == 1 ]]; then
        gmpack "$impl" "$result_dir/seed-$seed.bit"
    fi
    # Keep the best PASS implementation only; logs for all seeds are retained.
    if [[ $status == PASS ]]; then
        if [[ -z $best_seed ]] || awk -v new="$fmax" -v old="$best_freq" 'BEGIN { exit !(new > old) }'; then
            cp -- "$impl" "$best_impl"
            best_seed=$seed
            best_freq=$fmax
        fi
    fi
    rm -f -- "$impl"
done

{
    printf 'seed\tstatus\tfmax_mhz\tmargin_mhz\texit_code\telapsed_seconds\tlog\n'
    awk -F '\t' 'NR > 1 && $2 == "PASS"' "$report" | sort -t $'\t' -k4,4nr -k1,1n
} > "$result_dir/passing-ranked.tsv"

if [[ -n $best_seed ]]; then
    gmpack "$best_impl" "$result_dir/best-seed-$best_seed.bit"
    sha256sum "$result_dir/best-seed-$best_seed.bit" > "$result_dir/best-bitstream.sha256"
    printf '%s\n' "$best_seed" > "$result_dir/best-seed.txt"
fi

summary=$result_dir/summary.md
{
    printf '## ULX5M-GS bootloader timing sweep\n\n'
    printf -- "- Target: \`%s\`\n" "$target"
    printf -- "- Commit: \`%s\`\n" "${GITHUB_SHA:-local}"
    printf -- "- OSS CAD Suite: \`%s\`\n" "${OSS_CAD_SUITE_VERSION:-not-set}"
    printf -- '- Seed range: %d to %d\n' "$first_seed" "$((first_seed + seed_count - 1))"
    printf -- "- Target clock: 48.00 MHz (\`bram_i.clk\`)\n"
    printf -- '- Final results: **%d PASS**, %d FAIL, %d TIMEOUT, %d ERROR\n' \
        "$pass_count" "$fail_count" "$timeout_count" "$error_count"
    if [[ -n $best_seed ]]; then
        printf -- '- Best passing seed: **%d** at **%s MHz**\n' "$best_seed" "$best_freq"
        printf -- "- Candidate bitstream: \`best-seed-%s.bit\` (SRAM test only, not hardware validated)\n" "$best_seed"
    else
        printf -- '- Best passing seed: **none**\n'
    fi
    printf '\n### Passing seeds ranked by routed timing margin\n\n'
    printf '| Seed | Routed Fmax (MHz) | Margin (MHz) |\n'
    printf '| ---: | ---: | ---: |\n'
    awk -F '\t' 'NR > 1 && NR <= 31 { printf "| %s | %s | %s |\n", $1, $3, $4 }' \
        "$result_dir/passing-ranked.tsv"
    printf '\nAll results, individual routing logs and synthesis inputs are in the uploaded artifact.\n'
    printf '\nTiming PASS does not establish USB functionality, correct DFU behavior, or flash safety.\n'
} > "$summary"

cat "$summary"
printf '\nResults: %s\n' "$result_dir"
if (( error_count != 0 )); then
    echo 'ERROR: one or more seeds had tool errors.' >&2
    exit 1
fi
if (( pass_count == 0 && ${SWEEP_ALLOW_NO_PASS:-0} != 1 )); then
    echo 'ERROR: no seeds passed post-route 48 MHz timing.' >&2
    exit 1
fi
