#!/bin/bash
# -----------------------------------------------------------------------------
# File:        build-size-probe.sh
# Path:        doom/build-size-probe.sh
#
# Project:     Hazard3-Doom
# Purpose:     Build a reduced probe used to measure Doom image size and memory
#              requirements.
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
DOOMGENERIC_ROOT="${DOOMGENERIC_ROOT:-${ROOT_DIR}/third_party/doomgeneric}"
PREPARE_DOOMGENERIC="${SCRIPT_DIR}/prepare-doomgeneric.sh"
TOOLCHAIN_PREFIX="${TOOLCHAIN_PREFIX:-/opt/riscv/bin/riscv32-unknown-elf-}"
CC="${TOOLCHAIN_PREFIX}gcc"
SIZE="${TOOLCHAIN_PREFIX}size"
BUILD_DIR="${HAZARD3_SIZE_BUILD_DIR:-${ROOT_DIR}/build/doom-size-probe}"

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

require_tool()
{
    local tool="$1"

    if [[ "${tool}" == */* ]]; then
        [[ -x "${tool}" ]] || {
            echo "Missing required executable: ${tool}" >&2
            exit 1
        }
    else
        command -v "${tool}" >/dev/null 2>&1 || {
            echo "Missing required tool: ${tool}" >&2
            exit 1
        }
    fi
}

require_file()
{
    local path="$1"

    [[ -f "${path}" ]] || {
        echo "Missing required file: ${path}" >&2
        exit 1
    }
}

require_tool "${CC}"
require_tool "${SIZE}"
require_tool "${PREPARE_DOOMGENERIC}"
require_file "${SCRIPT_DIR}/doom_sources.sh"
require_file "${SCRIPT_DIR}/doom_build_flags.sh"
require_file "${DOOMGENERIC_ROOT}/doomgeneric/doomgeneric.c"
require_file "${DOOMGENERIC_ROOT}/doomgeneric/doomgeneric.h"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/doom_sources.sh"

PORT_SOURCES=(
    doomgeneric_hazard3.c
    hazard3_sao.c
    hazard3_newlib.c
    hazard3_platform_image.c
    doom_image_main.c
)

for source in "${PORT_SOURCES[@]}"; do
    require_file "${SCRIPT_DIR}/${source}"
done

# Reuse the verified prepared source tree and overwrite the current object set.
# This avoids recursively deleting an environment-selected build directory.
mkdir -p "${BUILD_DIR}"

DOOMGENERIC_DIR="$(
    DOOMGENERIC_ROOT="${DOOMGENERIC_ROOT}" \
        "${PREPARE_DOOMGENERIC}" "${BUILD_DIR}/doomgeneric-source"
)"

require_file "${DOOMGENERIC_DIR}/doomgeneric.c"
require_file "${DOOMGENERIC_DIR}/doomgeneric.h"
require_file "${DOOMGENERIC_DIR}/doomkeys.h"
require_file "${DOOMGENERIC_DIR}/i_video.h"

for source in "${DOOMGENERIC_SOURCES[@]}"; do
    require_file "${DOOMGENERIC_DIR}/${source}"
done

# DOOMGENERIC_DIR must identify the prepared source tree before flags are built.
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/doom_build_flags.sh"

GCC_VERSION="$("${CC}" -dumpfullversion -dumpversion)"
printf 'RISC-V GCC: %s\n' "${GCC_VERSION}"
printf 'Code generation: %s, %s\n' \
    "${DOOM_ARCH_FLAGS[0]}" "-O2 (same flags as loadable image)"

objects=()

for source in "${DOOMGENERIC_SOURCES[@]}"; do
    object="${BUILD_DIR}/${source%.c}.o"
    echo "[CC upstream] ${source}"
    "${CC}" "${DOOM_COMMON_COMPILE_FLAGS[@]}" \
        "${DOOM_UPSTREAM_WARNING_FLAGS[@]}" \
        -c "${DOOMGENERIC_DIR}/${source}" -o "${object}"
    objects+=("${object}")
done

for source in "${PORT_SOURCES[@]}"; do
    object="${BUILD_DIR}/${source%.c}.o"
    echo "[CC port] ${source}"
    "${CC}" "${DOOM_COMMON_COMPILE_FLAGS[@]}" \
        "${DOOM_PORT_WARNING_FLAGS[@]}" \
        -c "${SCRIPT_DIR}/${source}" -o "${object}"
    objects+=("${object}")
done

echo
echo "RV32 Doom object-size total before final link:"
"${SIZE}" -t "${objects[@]}" | tail -n 1

echo
echo "Largest objects:"
"${SIZE}" "${objects[@]}" | awk 'NR > 1 { print }' | sort -k1,1nr | sed -n '1,20p'

echo
echo "This is a compile/size probe, not the loadable Doom image."
echo "Use ./doom/build-doom-image.sh to link and package the SDRAM image."
