#!/usr/bin/env bash
# Report ULX5M BTN2 sweep results and generated storage; never delete files.
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(cd -- "$script_dir/.." && pwd)
cd -- "$root"
build_dir=build-ulx5m-gs

if [[ ! -d $build_dir ]]; then
    printf 'No ULX5M build directory: %s\n' "$root/$build_dir"
    exit 0
fi

printf 'Generated ULX5M build storage: '
du -sh -- "$build_dir" | awk '{print $1}'
printf '\nCurrent cached BTN2 netlist fingerprints (not proof of a fresh synthesis):\n'
for kind in btn2 btn2-regreset btn2-asyncreset; do
    json="$build_dir/top_ulx5m_gs_flash_read-serv-dfu-hw-quad-$kind.json"
    if [[ -s $json ]]; then
        sha256sum -- "$json"
    fi
done

printf '\nBTN2 sweep snapshots:\n'
shopt -s nullglob
dirs=("$build_dir"/btn2-dfu-quad*seed-sweep-*)
if (( ${#dirs[@]} == 0 )); then
    printf '  No BTN2 sweep snapshots found.\n'
fi
for dir in "${dirs[@]}"; do
    [[ -d $dir && -f $dir/results.tsv ]] || continue
    total=$(awk 'END { print (NR > 0 ? NR-1 : 0) }' "$dir/results.tsv")
    passes=$(awk -F '\t' 'NR > 1 && $2 == 0 && $4 == "PASS" { c++ } END { print c+0 }' "$dir/results.tsv")
    best=$(awk -F '\t' 'NR > 1 && $2 == 0 && $4 == "PASS" && $3+0 > f { f=$3+0; s=$1 } END { if (s != "") printf "seed %s, %.2f MHz", s, f; else printf "none" }' "$dir/results.tsv")
    printf '  %s: %s routes, %s PASS, best %s\n' "${dir##*/}" "$total" "$passes" "$best"
    if [[ -s $dir/design.json ]]; then
        printf '    JSON SHA-256: '
        sha256sum -- "$dir/design.json" | awk '{print $1}'
    fi
done

printf '\nLocally preserved candidates:\n'
candidates=(bitstreams/local-candidates/btn2-fwt3-seed*)
if (( ${#candidates[@]} == 0 )); then
    printf '  None. Preserve passing candidates before deleting build results.\n'
else
    for candidate in "${candidates[@]}"; do
        [[ -d $candidate ]] && printf '  %s\n' "$candidate"
    done
fi

printf '\nLarge generated subdirectories (top 12 by apparent disk usage):\n'
find "$build_dir" -mindepth 1 -maxdepth 1 -type d -exec du -sk -- {} + | sort -nr | awk 'NR <= 12 {printf "  %.1f MiB\t%s\n", $1/1024, $2}'

printf '\nSafety: no files changed or deleted.\n'
printf 'Keep the active sweep and flash-backup/JTAG reports until separately archived.\n'
