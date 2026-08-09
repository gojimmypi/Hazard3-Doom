#!/usr/bin/env bash

# Starts a listening OpenOCD server using ulx3s-openocd-doom.cfg.

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

OPENOCD_CONFIG="${ROOT_DIR}/openocd/ulx3s-openocd-doom.cfg"

if [[ ! -f "${OPENOCD}" ]]; then
    printf 'ERROR: OpenOCD not found:\n  %s\n' "${OPENOCD}" >&2
    exit 1
fi

if [[ ! -f "${OPENOCD_CONFIG}" ]]; then
    printf 'ERROR: OpenOCD configuration not found:\n  %s\n' \
        "${OPENOCD_CONFIG}" >&2
    exit 1
fi

# A native Windows OpenOCD executable cannot open WSL paths such as
# /mnt/c/workspace/.... Convert the configuration filename to Windows syntax
# when invoking an .exe from WSL. Native Linux OpenOCD keeps the POSIX path.
OPENOCD_CONFIG_ARG="${OPENOCD_CONFIG}"
if [[ "${OPENOCD,,}" == *.exe ]]; then
    if ! command -v wslpath >/dev/null 2>&1; then
        printf 'ERROR: wslpath is required when using Windows OpenOCD:\n  %s\n' \
            "${OPENOCD}" >&2
        exit 1
    fi

    # Convert config to DOS path
    OPENOCD_CONFIG_ARG="$(wslpath -w "${OPENOCD_CONFIG}")"
fi

printf 'Repository root:\n   %s\n\n' "${ROOT_DIR}"
printf 'Using config:\n      %s\n\n' "${OPENOCD_CONFIG_ARG}"
printf 'Starting OpenOCD:\n  %s\n\n' "${OPENOCD}"

exec "${OPENOCD}" -d2 -f "${OPENOCD_CONFIG_ARG}"
