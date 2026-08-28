#!/bin/bash
# -----------------------------------------------------------------------------
# File:        build.sh
# Path:        tests/doom-init-verify/build.sh
#
# Project:     Hazard3-Doom
# Purpose:     Build the diagnostic Doom initialization verification image.
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

echo "This test is specific to the ULX3S 12F at this time"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
SOURCE_DIR="${ROOT_DIR}/third_party/doomgeneric/doomgeneric"
PREPARED_DIR="${ROOT_DIR}/build/doom-init-verify/doomgeneric-source"
DOOM_BUILD_DIR="${ROOT_DIR}/build/doom-init-verify/doom-image"
MONITOR_BUILD_DIR="${ROOT_DIR}/build/ulx3s-12f/monitor"
HAZARD3_SYS_CLK_HZ="${HAZARD3_SYS_CLK_HZ:-40000000}"

rm -rf "${PREPARED_DIR}"
mkdir -p "${PREPARED_DIR}" "${DOOM_BUILD_DIR}"
cp -a "${SOURCE_DIR}/." "${PREPARED_DIR}/"
cp "${SCRIPT_DIR}/r_data.c" "${PREPARED_DIR}/r_data.c"
cp "${SCRIPT_DIR}/w_file_stdc.c" "${PREPARED_DIR}/w_file_stdc.c"

printf 'Preparing diagnostic DoomGeneric tree:\n'
printf '  override r_data.c\n'
printf '    purpose: TEXTURE1 cache and texture progress markers\n'
printf '  override w_file_stdc.c\n'
printf '    purpose: direct SDRAM WAD read transport verification\n'
printf '\nDiagnostic mode:\n'
printf '  WAD stdio buffering: DISABLED\n'
printf '  TEXTURE1 integrity checks: DISABLED\n'
printf '  TEXTURE1 source/destination transport check: ENABLED\n'
printf '  texture construction/lookup progress markers: ENABLED\n'
printf '  fatal exit recovery: ENTRY-FRAME ASSEMBLY (no setjmp)\n'
printf '\nBuilding matching ULX3S-12F monitor\n'
HAZARD3_BUILD_DIR="${MONITOR_BUILD_DIR}" \
HAZARD3_MONITOR_LINKER_SCRIPT="${ROOT_DIR}/src/link-12f-sdram.ld" \
HAZARD3_MEMORY_PROFILE=32m \
HAZARD3_SYS_CLK_HZ=40000000 \
    "${ROOT_DIR}/scripts/build.sh"

printf '\nBuilding Doom initialization verifier (direct WAD transport check)\n'
printf '  source: %s\n' "${PREPARED_DIR}"
printf '  output: %s\n' "${DOOM_BUILD_DIR}"
printf '  profile: 32m\n'

HAZARD3_MEMORY_PROFILE=32m \
HAZARD3_DOOM_HDMI_RESOLUTION=320x200 \
HAZARD3_DOOM_PREPARED_SOURCE="${PREPARED_DIR}" \
HAZARD3_DOOM_BUILD_DIR="${DOOM_BUILD_DIR}" \
    "${ROOT_DIR}/doom/build-doom-image.sh"

printf '\nDiagnostic H3D: %s\n' \
    "${DOOM_BUILD_DIR}/hazard3-doom.h3d"
printf 'Matching monitor: %s\n' \
    "${MONITOR_BUILD_DIR}/hazard3-boot-monitor.elf"
