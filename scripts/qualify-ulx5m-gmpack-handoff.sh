#!/usr/bin/env bash
# File:        qualify-ulx5m-gmpack-handoff.sh
# Path:        scripts/qualify-ulx5m-gmpack-handoff.sh
# Purpose:     Offline GateMate gmpack option comparison (NO hardware access).
# WARNING:     Outputs are for forensic analysis. NEVER PROGRAM THEM.

set -euo pipefail
umask 077
export LC_ALL=C

usage() {
    cat <<'EOF'
Usage: ./scripts/qualify-ulx5m-gmpack-handoff.sh

Offline only. Verify the exact seed-147 .bit and nextpnr .txt SHA-256,
reproduce the original .bit, then compare --reconfig and --bootaddr
variants. All generated files go to a fresh /tmp directory.
No RTL build, USB/JTAG command, or flash read/write is performed.
EOF
}

if (( $# > 0 )); then
    if (( $# == 1 )) && [[ $1 == --help ]]; then
        usage
        exit 0
    fi
    usage >&2
    exit 2
fi

for executable in sha256sum cmp mktemp python3 gmpack; do
    if ! command -v "$executable" >/dev/null 2>&1; then
        printf '[ERROR] Required executable unavailable: %s\n' "$executable" >&2
        exit 1
    fi
done

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
base="$repo_root/bootloader-serv/build-ulx5m-gs/top_ulx5m_gs_flash_read-serv-dfu-hw-quad-btn2"
impl="$base.txt"
golden="$base.bit"
inspector="$repo_root/bootloader-serv/tests/inspect-ulx5m-cfg-variants.py"
expected_bit=8232dd932ff2ea40b2945de6ed1202be5e7dc75960464419cc0ffa95a75901f8
expected_impl=3b1cca322420f5086a6f0695cc299660047a68740908a3f50f060ff6877c65b9

require_hash() {
    local file=$1 expected=$2 actual _rest
    if [[ ! -f $file || ! -r $file ]]; then
        printf '[REJECT] Missing/unreadable input: %s\n' "$file" >&2
        exit 1
    fi
    read -r actual _rest < <(sha256sum -- "$file")
    if [[ $actual != "$expected" ]]; then
        printf '[REJECT] SHA-256 mismatch: %s\n' "$file" >&2
        printf '         expected %s\n         observed %s\n' "$expected" "$actual" >&2
        exit 1
    fi
}

# Do not even run gmpack until both frozen inputs are verified.
require_hash "$golden" "$expected_bit"
require_hash "$impl" "$expected_impl"
if [[ ! -f $inspector ]]; then
    printf '[REJECT] Phase 4 inspector missing: %s\n' "$inspector" >&2
    exit 1
fi
printf '[PASS] Both seed-147 reference SHA-256 values match\n'

out=$(mktemp -d /tmp/ulx5m-gmpack-offline.XXXXXXXX)
printf '[INFO] Offline output directory: %s\n' "$out"
printf 'GMPACK=%s\n' "$(command -v gmpack)" > "$out/tool.txt"
printf 'GOLDEN=%s\nIMPLEMENTATION=%s\n' "$expected_bit" "$expected_impl" >> "$out/tool.txt"
if ! gmpack --help > "$out/gmpack-help.txt" 2>&1; then
    printf '[REJECT] gmpack --help failed; inspect %s\n' "$out/gmpack-help.txt" >&2
    exit 1
fi

pack() {
    local label=$1
    shift
    # No shell evaluation of options or implicit hardware programmer.
    printf '[INFO] gmpack offline variant: %s\n' "$label"
    if ! gmpack "$@" "$impl" "$out/$label.bit" > "$out/$label.log" 2>&1; then
        printf '[REJECT] gmpack %s failed: %s\n' "$label" "$out/$label.log" >&2
        exit 1
    fi
    if [[ ! -f $out/$label.bit ]]; then
        printf '[REJECT] gmpack did not create %s.bit\n' "$label" >&2
        exit 1
    fi
}

pack default
if ! cmp -s -- "$golden" "$out/default.bit"; then
    printf '[REJECT] Default pack is not byte-identical to seed-147 .bit\n' >&2
    printf '         STOP. Compare tool versions before interpreting any variants.\n' >&2
    exit 1
fi
printf '[PASS] Default gmpack output equals the seed-147 .bit byte-for-byte\n'

# 0x200000 is a synthetic flag probe, NEVER an approved flash allocation.
pack reconfig --reconfig
pack bootaddr_probe --bootaddr 2097152
pack reconfig_bootaddr_probe --reconfig --bootaddr 2097152

# Inspector enforces original SHA-256 and rejects no-effect variants.
python3 "$inspector" \
    --golden-bit "$golden" \
    --implementation "$impl" \
    --variant "reconfig=$out/reconfig.bit" \
    --variant "bootaddr_probe=$out/bootaddr_probe.bit" \
    --variant "reconfig_bootaddr_probe=$out/reconfig_bootaddr_probe.bit" \
    --json-out "$out/variants.json" > "$out/variants.stdout.json"

sha256sum -- "$out"/*.bit > "$out/SHA256SUMS"
printf '[PASS] Variant outputs differ from baseline and are documented in %s\n' "$out/variants.json"
python3 - "$out/variants.json" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as stream:
    report = json.load(stream)
for name, entry in report["variants"].items():
    compare = entry["comparison"]
    print("[INFO] %s: %d bytes, %d changed, first=0x%x, last=0x%x" % (
        name, entry["size"], compare["different_bytes_including_size_delta"],
        compare["first_different_offset"], compare["last_different_offset"]))
PY
printf '[NOTE] No command/CRC semantics, live handoff, or recovery has been proven.\n'
printf '[NOTE] NEVER load/program these variant files onto the FPGA or flash.\n'
