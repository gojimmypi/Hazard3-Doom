#!/bin/bash
# -----------------------------------------------------------------------------
# File:        build-doom-ab.sh
# Path:        doom/build-doom-ab.sh
#
# Project:     Hazard3-Doom
# Purpose:     Build both supported Doom framebuffer variants for A/B comparison.
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
BUILD_SCRIPT="${SCRIPT_DIR}/build-doom-image.sh"
MEMORY_PROFILE="${HAZARD3_MEMORY_PROFILE:-64m}"
MODE="${1:-both}"

case "${MODE}" in
both|320x200|400x240)
    ;;
*)
    echo "Usage: $0 [both|320x200|400x240]" >&2
    exit 2
    ;;
esac

build_mode()
{
    local resolution="$1"
    local build_dir="${ROOT_DIR}/build/doom-ab/${resolution}"

    printf '\n=== Doom A/B build: %s ===\n' "${resolution}"
    printf 'Memory profile: %s\n' "${MEMORY_PROFILE}"
    printf 'Output:         %s\n\n' "${build_dir}/hazard3-doom.h3d"

    HAZARD3_DOOM_BUILD_DIR="${build_dir}" \
    HAZARD3_MEMORY_PROFILE="${MEMORY_PROFILE}" \
    HAZARD3_DOOM_HDMI_RESOLUTION="${resolution}" \
    HAZARD3_DOOM_ALLOW_DIRTY_DOOMGENERIC="${HAZARD3_DOOM_ALLOW_DIRTY_DOOMGENERIC:-0}" \
        "${BUILD_SCRIPT}"
}

if [[ "${MODE}" == "both" || "${MODE}" == "320x200" ]]; then
    build_mode 320x200
fi

if [[ "${MODE}" == "both" || "${MODE}" == "400x240" ]]; then
    build_mode 400x240
fi

printf '\nA/B images ready:\n'
for resolution in 320x200 400x240; do
    image="${ROOT_DIR}/build/doom-ab/${resolution}/hazard3-doom.h3d"
    if [[ -f "${image}" ]]; then
        if command -v sha256sum >/dev/null 2>&1; then
            sha256sum "${image}"
        else
            printf '%s\n' "${image}"
        fi
    fi
done
