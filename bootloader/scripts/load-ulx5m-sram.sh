#!/usr/bin/env bash
set -euo pipefail

# Program GateMate configuration SRAM through Tigard JTAG (volatile only).
# No -f option and no writes to configuration flash.

if (( $# != 1 )); then
    printf 'Usage: load-ulx5m-sram.sh BITSTREAM_PATH\n' >&2
    printf 'Path must be relative to repository root.\n' >&2
    exit 2
fi

bitstream="$1"
if [[ "$bitstream" == /* ]]; then
    printf 'ERROR: bitstream must be a repository-relative path\n' >&2
    exit 1
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "$script_dir/../.." && pwd -P)"
cd -- "$repo_root"

loader="${OPENFPGALOADER:-./bin/openFPGALoader.exe}"
if [[ ! -f "$loader" ]]; then
    printf 'ERROR: openFPGALoader not found: %s\n' "$loader" >&2
    exit 1
fi
if [[ ! -s "$bitstream" ]]; then
    printf 'ERROR: bitstream not found or empty: %s\n' "$bitstream" >&2
    exit 1
fi

printf 'Loading volatile FPGA SRAM via Tigard: %s\n' "$bitstream"
"$loader" -c tigard --freq 100k "$bitstream"
printf 'JTAG SRAM load completed; configuration flash was not programmed.\n'
