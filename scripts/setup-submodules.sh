#!/bin/bash
# -----------------------------------------------------------------------------
# File:        setup-submodules.sh
# Path:        scripts/setup-submodules.sh
#
# Project:     Hazard3-Doom
# Purpose:     Initialize the top-level and selected nested submodules
#              required for normal builds.
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

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
HAZARD3_ROOT="${ROOT_DIR}/third_party/Hazard3"
HAZARD3_INIT_ALL_SUBMODULES="${HAZARD3_INIT_ALL_SUBMODULES:-0}"

# Run shellcheck to ensure this is a good script.
# Specify the executable shell checker you want to use:
MY_SHELLCHECK="shellcheck"

# Check if the executable is available in the PATH
if command -v "$MY_SHELLCHECK" >/dev/null 2>&1; then
    # Run your command here
    shellcheck "$0" || exit 1
else
    echo "$MY_SHELLCHECK is not installed. Please install it if changes to this script have been made."
fi

require_tool()
{
    command -v "$1" >/dev/null 2>&1 || {
        echo "Missing required tool: $1" >&2
        exit 1
    }
}

require_tool git

case "${HAZARD3_INIT_ALL_SUBMODULES}" in
0)
    git -C "${ROOT_DIR}" submodule sync -- \
        third_party/doomgeneric third_party/Hazard3
    git -C "${ROOT_DIR}" submodule update --init -- \
        third_party/doomgeneric third_party/Hazard3

    git -C "${HAZARD3_ROOT}" submodule sync -- \
        scripts example_soc/libfpga
    git -C "${HAZARD3_ROOT}" submodule update --init -- \
        scripts example_soc/libfpga

    printf 'Initialized build-required submodules:\n'
    git -C "${ROOT_DIR}" submodule status -- \
        third_party/doomgeneric third_party/Hazard3
    git -C "${HAZARD3_ROOT}" submodule status -- \
        scripts example_soc/libfpga
    ;;
1)
    git -C "${ROOT_DIR}" submodule sync --recursive
    git -C "${ROOT_DIR}" submodule update --init --recursive

    printf 'Initialized all repository submodules:\n'
    git -C "${ROOT_DIR}" submodule status --recursive
    ;;
*)
    echo "HAZARD3_INIT_ALL_SUBMODULES must be 0 or 1" >&2
    exit 1
    ;;
esac
