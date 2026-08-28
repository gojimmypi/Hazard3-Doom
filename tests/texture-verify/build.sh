#!/bin/bash
# -----------------------------------------------------------------------------
# File:        build.sh
# Path:        tests/texture-verify/build.sh
#
# Project:     Hazard3-Doom
# Purpose:     Build the Doom texture-data verification diagnostic.
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

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
SOURCE_DIR="${ROOT_DIR}/third_party/doomgeneric/doomgeneric"
PREPARED_DIR="${ROOT_DIR}/build/texture-verify/doomgeneric-source"
DOOM_BUILD_DIR="${ROOT_DIR}/build/texture-verify/doom-image"

rm -rf "${PREPARED_DIR}"
mkdir -p "${PREPARED_DIR}" "${DOOM_BUILD_DIR}"
cp -a "${SOURCE_DIR}/." "${PREPARED_DIR}/"
cp "${SCRIPT_DIR}/r_data.c" "${PREPARED_DIR}/r_data.c"

printf 'Building texture-integrity Doom image\n'
printf '  source: %s\n' "${PREPARED_DIR}"
printf '  output: %s\n' "${DOOM_BUILD_DIR}"

HAZARD3_MEMORY_PROFILE=32m \
HAZARD3_DOOM_PREPARED_SOURCE="${PREPARED_DIR}" \
HAZARD3_DOOM_BUILD_DIR="${DOOM_BUILD_DIR}" \
    "${ROOT_DIR}/doom/build-doom-image.sh"
