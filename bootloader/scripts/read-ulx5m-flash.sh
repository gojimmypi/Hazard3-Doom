#!/usr/bin/env bash
set -euo pipefail

# Read one bounded flash region via Tigard JTAG. No flash writes.
# Use WSL with the Windows openFPGALoader.exe bundled in this repository.

usage()
{
    printf 'Usage: read-ulx5m-flash.sh OFFSET BYTES OUTPUT\n' >&2
    printf 'OFFSET: decimal or 0x hex; BYTES: 1..65536; flash size: 4194304\n' >&2
}

fail()
{
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

if (( $# != 3 )); then
    usage
    exit 2
fi

to_number()
{
    local value="$1"
    if [[ "$value" =~ ^0[xX][0-9a-fA-F]+$ ]]; then
        printf '%d' "$((value))"
    elif [[ "$value" =~ ^[0-9]+$ ]]; then
        printf '%d' "$((10#$value))"
    else
        return 1
    fi
}

offset="$(to_number "$1")" || fail "invalid offset: $1"
length="$(to_number "$2")" || fail "invalid byte count: $2"
output="$3"

if (( offset < 0 || offset >= 4194304 )); then
    fail 'offset outside 4 MiB flash'
fi
if (( length < 1 || length > 65536 || offset + length > 4194304 )); then
    fail 'read must be 1..65536 bytes and remain within the flash'
fi
if [[ "$output" == /* ]]; then
    fail 'output must be relative to repository root (Windows executable under WSL)'
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "$script_dir/../.." && pwd -P)"
cd -- "$repo_root"
loader="${OPENFPGALOADER:-./bin/openFPGALoader.exe}"
if [[ ! -f "$loader" ]]; then
    fail "openFPGALoader not found: $loader"
fi
if [[ -e "$output" ]]; then
    fail "refusing to overwrite existing file: $output"
fi
if [[ ! -d "$(dirname -- "$output")" ]]; then
    fail "output directory does not exist: $(dirname -- "$output")"
fi

tmp="${output}.tmp.$$"
if [[ -e "$tmp" ]]; then
    fail "temporary file already exists: $tmp"
fi
trap 'rm -f -- "$tmp"' EXIT

printf 'Reading %d bytes from flash offset 0x%06X\n' "$length" "$offset"
"$loader" -c tigard --freq 100k \
    --dump-flash --offset "$offset" --file-size "$length" "$tmp"
if [[ ! -f "$tmp" ]]; then
    fail "no output from openFPGALoader: $tmp"
fi
size="$(stat -c %s -- "$tmp")"
if (( size != length )); then
    fail "incorrect output size: got $size, expected $length"
fi
mv -- "$tmp" "$output"
stat -c '%n %s bytes' -- "$output"
sha256sum -- "$output"
printf 'First up to 32 bytes:\n'
od -An -tx1 -N 32 -- "$output"
