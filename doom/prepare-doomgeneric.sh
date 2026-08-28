#!/bin/bash
# -----------------------------------------------------------------------------
# File:        prepare-doomgeneric.sh
# Path:        doom/prepare-doomgeneric.sh
#
# Project:     Hazard3-Doom
# Purpose:     Prepare the pinned DoomGeneric source tree for Hazard3-Doom
#              builds.
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
SOURCE_ROOT="${DOOMGENERIC_ROOT:-${ROOT_DIR}/third_party/doomgeneric}"
DESTINATION_ROOT="${1:?usage: prepare-doomgeneric.sh DESTINATION_ROOT}"

# Run ShellCheck to ensure this is a good script.
# Specify the executable shell checker you want to use:
MY_SHELLCHECK="shellcheck"

# Check if the executable is available in the PATH.
if command -v "${MY_SHELLCHECK}" >/dev/null 2>&1; then
    "${MY_SHELLCHECK}" -x "${BASH_SOURCE[0]}" >&2 || exit 1
else
    printf '%s\n' \
        "${MY_SHELLCHECK} is not installed. Please install it if changes to this script have been made." \
        >&2
fi

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/doomgeneric-version.sh" >&2

require_tool()
{
    command -v "$1" >/dev/null 2>&1 || {
        echo "Missing required tool: $1" >&2
        exit 1
    }
}

require_file()
{
    local path="$1"

    [[ -f "${path}" ]] || {
        echo "Missing required file: ${path}" >&2
        exit 1
    }
}

require_tool git
require_file "${SOURCE_ROOT}/doomgeneric/doomgeneric.c"
require_file "${SOURCE_ROOT}/doomgeneric/doomgeneric.h"
require_file "${SOURCE_ROOT}/doomgeneric/doomkeys.h"
require_file "${SOURCE_ROOT}/doomgeneric/i_video.h"
require_file "${SOURCE_ROOT}/doomgeneric/w_file_stdc.c"

git -C "${SOURCE_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "DoomGeneric is not a Git checkout: ${SOURCE_ROOT}" >&2
    echo "Run ${ROOT_DIR}/scripts/setup-submodules.sh first." >&2
    exit 1
}

current_commit="$(git -C "${SOURCE_ROOT}" rev-parse HEAD)"
if [[ "${current_commit}" != "${DOOMGENERIC_COMMIT}" ]]; then
    echo "Unexpected DoomGeneric commit: ${current_commit}" >&2
    echo "Expected pinned commit: ${DOOMGENERIC_COMMIT}" >&2
    echo "Run ${ROOT_DIR}/scripts/setup-submodules.sh first." >&2
    exit 1
fi

if [[ -n "$(git -C "${SOURCE_ROOT}" status --porcelain \
    --untracked-files=all -- doomgeneric)" ]]; then
    echo "DoomGeneric source tree has local changes: ${SOURCE_ROOT}/doomgeneric" >&2
    echo "Restore the submodule to the pinned commit before building." >&2
    exit 1
fi

if [[ ! -e "${DESTINATION_ROOT}" ]]; then
    mkdir -p "${DESTINATION_ROOT}"
    cp -a "${SOURCE_ROOT}/doomgeneric" "${DESTINATION_ROOT}/"
elif [[ ! -d "${DESTINATION_ROOT}" ]]; then
    echo "Prepared DoomGeneric destination is not a directory: ${DESTINATION_ROOT}" >&2
    exit 1
fi

require_file "${DESTINATION_ROOT}/doomgeneric/doomgeneric.c"
require_file "${DESTINATION_ROOT}/doomgeneric/doomgeneric.h"
require_file "${DESTINATION_ROOT}/doomgeneric/doomkeys.h"
require_file "${DESTINATION_ROOT}/doomgeneric/i_video.h"

# Always restore the stock backend in an existing prepared tree. This removes
# any stale diagnostic/experimental override left by an earlier build.
cp "${SOURCE_ROOT}/doomgeneric/w_file_stdc.c" \
    "${DESTINATION_ROOT}/doomgeneric/w_file_stdc.c"

printf '%s\n' "${DESTINATION_ROOT}/doomgeneric"
