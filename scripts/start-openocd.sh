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
