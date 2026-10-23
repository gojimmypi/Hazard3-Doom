#!/usr/bin/env bash
# Preserve a post-route BTN2 FWT3 PASS outside the disposable build directory.
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: ./bootloader-serv/scripts/preserve-ulx5m-btn2-candidate.sh RUN_DIR SEED

RUN_DIR must be a btn2-dfu-quad-seed-sweep-* directory from the original,
non-registered BTN2 FWT3 experiment (not regreset or asyncreset).
The seed must have a completed, successful post-route result.

Copies the frozen netlist/constraints, implementation, route log, metadata,
and bitstream into bootloader-serv/bitstreams/local-candidates/. If the sweep
has not packed the bitstream, uses gmpack on the passing implementation.
Refuses to overwrite an existing candidate. No FPGA or flash operations.
USAGE
}

if [[ ${1:-} == -h || ${1:-} == --help ]]; then
    usage
    exit 0
fi
if (( $# != 2 )) || [[ ! ${2:-} =~ ^[0-9]+$ ]]; then
    usage >&2
    exit 2
fi
seed=$((10#$2))
if (( seed < 1 )); then
    printf 'ERROR: seed must be positive.\n' >&2
    exit 2
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(cd -- "$script_dir/.." && pwd)
case $1 in
    /*) run_dir=$1 ;;
    *)
        if [[ -d $1 ]]; then
            run_dir=$1
        elif [[ -d $root/$1 ]]; then
            run_dir=$root/$1
        elif [[ -d $root/../$1 ]]; then
            run_dir=$root/../$1
        else
            printf 'ERROR: sweep directory not found: %s\n' "$1" >&2
            exit 1
        fi
        ;;
esac
run_dir=$(realpath -- "$run_dir")
build_dir=$root/build-ulx5m-gs
case $run_dir in
    "$build_dir"/btn2-dfu-quad-seed-sweep-*) ;;
    *)
        printf 'ERROR: not an original BTN2 FWT3 sweep directory: %s\n' "$run_dir" >&2
        exit 1
        ;;
esac

report=$run_dir/results.tsv
[[ -s $report ]] || { printf 'ERROR: missing results.tsv\n' >&2; exit 1; }
record=$(awk -F '\t' -v s="$seed" 'NR > 1 && $1 == s { print $2 " " $3 " " $4; found++ } END { if (found != 1) exit 1 }' "$report") || {
    printf 'ERROR: seed %s has no unique completed result.\n' "$seed" >&2
    exit 1
}
read -r rc fmax timing <<< "$record"
if [[ $rc != 0 || $timing != PASS ]] || ! awk -v f="$fmax" 'BEGIN { exit !(f+0 >= 48) }'; then
    printf 'ERROR: seed %s did not pass post-route 48 MHz timing.\n' "$seed" >&2
    exit 1
fi

for required in design.json design.ccf design.sdc metadata.txt inputs.sha256 "seed-$seed.txt" "seed-$seed.log"; do
    [[ -s $run_dir/$required ]] || {
        printf 'ERROR: missing/empty input: %s\n' "$run_dir/$required" >&2
        exit 1
    }
done

# The sweep stores checksums for its frozen netlist and constraints. Check
# all three, independent of the build tree's subsequently modified sources.
for filename in design.json design.ccf design.sdc; do
    expected=$(awk -v f="$filename" '$2 ~ ("/" f "$") {print $1}' "$run_dir/inputs.sha256")
    actual=$(sha256sum -- "$run_dir/$filename" | awk '{print $1}')
    if [[ -z $expected || $actual != "$expected" ]]; then
        printf 'ERROR: frozen sweep input changed: %s\n' "$filename" >&2
        exit 1
    fi
done

# Avoid treating preliminary placer timing as the routed result.
if ! grep -Eq "Max frequency for clock .*: ${fmax} MHz \(PASS at 48[.]00 MHz\)" "$run_dir/seed-$seed.log"; then
    printf 'ERROR: route log does not confirm %s MHz PASS.\n' "$fmax" >&2
    exit 1
fi

json_hash=$(sha256sum -- "$run_dir/design.json" | awk '{print $1}')
name="btn2-fwt3-seed${seed}-${json_hash:0:12}"
destination=$root/bitstreams/local-candidates/$name
if [[ -e $destination ]]; then
    printf 'ERROR: candidate already exists; will not overwrite: %s\n' "$destination" >&2
    exit 1
fi
mkdir -p -- "$root/bitstreams/local-candidates"
tmp_dir=$(mktemp -d -- "$root/bitstreams/local-candidates/.tmp-${name}-XXXXXXXX")
cleanup() { [[ -d ${tmp_dir:-} ]] && rm -rf -- "$tmp_dir"; }
trap cleanup EXIT

cp -- "$run_dir/design.json" "$run_dir/design.ccf" "$run_dir/design.sdc" \
    "$run_dir/metadata.txt" "$tmp_dir/"
cp -- "$run_dir/seed-$seed.txt" "$tmp_dir/implementation.txt"
cp -- "$run_dir/seed-$seed.log" "$tmp_dir/route.log"

if [[ -s $run_dir/seed-$seed.bit ]]; then
    cp -- "$run_dir/seed-$seed.bit" "$tmp_dir/image.bit"
else
    if ! command -v gmpack >/dev/null 2>&1; then
        printf 'ERROR: no bitstream in sweep and gmpack unavailable.\n' >&2
        exit 1
    fi
    gmpack "$tmp_dir/implementation.txt" "$tmp_dir/image.bit"
fi
[[ -s $tmp_dir/image.bit ]] || { printf 'ERROR: empty bitstream\n' >&2; exit 1; }

{
    printf 'ULX5M-GS volatile BTN2 FWT3 candidate (no flash installation)\n'
    printf 'Variant: original BTN2 gate, EP0 free-running read; no registered-reset flag\n'
    printf 'Seed: %s\n' "$seed"
    printf 'Post-route Fmax: %s MHz (PASS at 48.00 MHz)\n' "$fmax"
    printf 'Frozen netlist SHA-256: %s\n' "$json_hash"
    printf 'Original sweep: %s\n' "${run_dir##*/}"
    printf 'USB and flash hardware qualification: not implied by this archive\n'
    printf 'Program FPGA SRAM only (-m), never configuration flash (-f).\n'
} > "$tmp_dir/README.txt"
(
    cd -- "$tmp_dir"
    sha256sum -- README.txt design.json design.ccf design.sdc metadata.txt implementation.txt route.log image.bit > SHA256SUMS
    sha256sum -c -- SHA256SUMS >/dev/null
)
mv -- "$tmp_dir" "$destination"
trap - EXIT
printf 'Preserved: %s\n' "$destination"
printf 'Image SHA-256: '
sha256sum -- "$destination/image.bit" | awk '{print $1}'
printf 'No build files deleted and no FPGA/flash operations performed.\n'
