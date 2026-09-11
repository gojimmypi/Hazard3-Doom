#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File:        start-openocd.sh
# Path:        scripts/start-openocd.sh
#
# Project:     Hazard3-Doom
# Purpose:     Start OpenOCD on Linux or WSL with the Hazard3-Doom ULX3S
#              configuration.
#
# Copyright (c) 2026 gojimmypi
#
# Licensed under the Apache License, Version 2.0.
#
# SPDX-License-Identifier: Apache-2.0
#
# This software is provided under the terms of the applicable license.
# See LICENSES/Apache-2.0.txt for the complete license terms.
# See LICENSING.md for project licensing policy and scope.
# -----------------------------------------------------------------------------

# Starts a listening OpenOCD server using ulx3s-openocd-doom.cfg.

set -euo pipefail

# Check environment. We can run Windows .exe files from WSL, not other Linux
kernel_release=""

kernel_release="$(uname -r 2>/dev/null || true)"
IS_WSL=0
if [[ -n "${WSL_DISTRO_NAME:-}" || -n "${WSL_INTEROP:-}" ]] ||
    [[ "${kernel_release,,}" == *microsoft* ]]; then
    echo "Detected WSL environment: ${kernel_release}" >&2
    IS_WSL=1
fi


# Resolve the repository root from this script's location.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

# Use the first argument as the OpenOCD path, or use the prebuilt binary.
if [[ $# -ge 1 ]]; then
    OPENOCD="$1"
else
    if (( IS_WSL == 1 )); then
        OPENOCD="${ROOT_DIR}/bin/openocd.exe"
    else
        OPENOCD="openocd"
    fi
fi

OPENOCD_CONFIG="${ROOT_DIR}/openocd/ulx3s-openocd-doom.cfg"

# Verify that OpenOCD exists. Explicit paths are checked directly; command
# names such as "openocd" are resolved through PATH.
if [[ "${OPENOCD}" == */* ]]; then
    if [[ ! -f "${OPENOCD}" ]]; then
        printf 'ERROR: OpenOCD not found:\n  %s\n' "${OPENOCD}" >&2
        exit 1
    fi
elif ! command -v "${OPENOCD}" >/dev/null 2>&1; then
    printf 'ERROR: OpenOCD not found in PATH:\n  %s\n' "${OPENOCD}" >&2
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

if (( IS_WSL == 1 )); then
    if [[ "${OPENOCD,,}" == *.exe ]]; then
        if ! command -v wslpath >/dev/null 2>&1; then
            printf 'ERROR: wslpath is required when using Windows OpenOCD:\n  %s\n' \
                "${OPENOCD}" >&2
            exit 1
        fi

        # Convert config to DOS path
        OPENOCD_CONFIG_ARG="$(wslpath -w "${OPENOCD_CONFIG}")"
    fi
else
    if [[ "${OPENOCD,,}" == *.exe ]]; then
        printf 'ERROR: Windows OpenOCD cannot be used from native Linux:\n  %s\n' \
            "${OPENOCD}" >&2
        printf 'Install and use the native Linux OpenOCD executable instead.\n' >&2
        exit 1
    fi
fi


printf 'Repository root:\n   %s\n\n' "${ROOT_DIR}"
printf 'Using config:\n      %s\n\n' "${OPENOCD_CONFIG_ARG}"
printf 'Starting OpenOCD:\n  %s\n\n' "${OPENOCD}"

exec "${OPENOCD}" -d2 -f "${OPENOCD_CONFIG_ARG}"
