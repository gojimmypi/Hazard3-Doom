#!/usr/bin/env bash

# Starts a listening OpenOCD server using ulx3s-openocd.cfg.

set -euo pipefail

# Resolve the repository root from this script's location.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

# Use the first argument as the OpenOCD path, or use the prebuilt binary.
if [[ $# -ge 1 ]]; then
    OPENOCD="$1"
else
    OPENOCD="${ROOT_DIR}/bin/openocd.exe"
fi

OPENOCD_CONFIG="${ROOT_DIR}/third_party/Hazard3/example_soc/ulx3s-openocd.cfg"

if [[ ! -f "${OPENOCD}" ]]; then
    printf 'ERROR: OpenOCD not found:\n  %s\n' "${OPENOCD}" >&2
    exit 1
fi

if [[ ! -f "${OPENOCD_CONFIG}" ]]; then
    printf 'ERROR: OpenOCD configuration not found:\n  %s\n' \
        "${OPENOCD_CONFIG}" >&2
    exit 1
fi

printf 'Repository root:\n  %s\n\n' "${ROOT_DIR}"
printf 'Starting OpenOCD:\n  %s\n\n' "${OPENOCD}"

exec "${OPENOCD}" -d2 -f "${OPENOCD_CONFIG}"
