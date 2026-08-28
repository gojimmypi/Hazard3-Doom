#!/bin/bash
# -----------------------------------------------------------------------------
# File:        build-doom-noncombat.sh
# Path:        scripts/build-doom-noncombat.sh
#
# Project:     Hazard3-Doom
# Purpose:     Build and verify the dedicated Hazard3-Doom noncombat Doom
#              image.
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
PREPARE="${ROOT_DIR}/doom/prepare-doomgeneric.sh"
BUILD="${ROOT_DIR}/doom/build-doom-image.sh"
TRANSFORM="${SCRIPT_DIR}/apply-doom-noncombat.py"
TOOLCHAIN_PREFIX="${TOOLCHAIN_PREFIX:-/opt/riscv/bin/riscv32-unknown-elf-}"
NM="${TOOLCHAIN_PREFIX}nm"
BUILD_DIR="${HAZARD3_DOOM_NONCOMBAT_BUILD_DIR:-${ROOT_DIR}/build/doom-image-noncombat}"
PREPARED_ROOT="${BUILD_DIR}/doomgeneric-source"

require_file()
{
    [[ -f "$1" ]] || {
        printf 'Missing required file: %s\n' "$1" >&2
        exit 1
    }
}

require_executable()
{
    [[ -x "$1" ]] || {
        printf 'Missing required executable: %s\n' "$1" >&2
        exit 1
    }
}

require_file "${PREPARE}"
require_file "${BUILD}"
require_file "${TRANSFORM}"
require_executable "${PREPARE}"
require_executable "${BUILD}"
require_executable "${TRANSFORM}"
require_executable "${NM}"
command -v python3 >/dev/null 2>&1 || {
    echo 'Missing required tool: python3' >&2
    exit 1
}

export HAZARD3_MEMORY_PROFILE="${HAZARD3_MEMORY_PROFILE:-64m}"
export HAZARD3_DOOM_BUILD_DIR="${BUILD_DIR}"
unset HAZARD3_DOOM_NONCOMBAT || true

printf 'Building dedicated Hazard3 Doom noncombat image...\n'
printf '  build directory: %s\n' "${BUILD_DIR}"
printf '  memory profile:  %s\n' "${HAZARD3_MEMORY_PROFILE}"

DOOMGENERIC_DIR="$("${PREPARE}" "${PREPARED_ROOT}")"
python3 "${TRANSFORM}" "${DOOMGENERIC_DIR}"

grep -Fq 'p->armorpoints = 200;' "${DOOMGENERIC_DIR}/g_game.c"
grep -Fq 'p->ammo[i] = 0;' "${DOOMGENERIC_DIR}/g_game.c"
grep -Fq 'p->weaponowned[wp_pistol] = false;' "${DOOMGENERIC_DIR}/g_game.c"
grep -Fq 'Hazard3 Supercon noncombat: Fire is intentionally ignored.' \
    "${DOOMGENERIC_DIR}/g_game.c"
grep -Fq 'Hazard3 Supercon noncombat: omit first-person weapon/fist overlay.' \
    "${DOOMGENERIC_DIR}/r_things.c"
printf 'Source preflight: PASS\n'

export HAZARD3_DOOM_PREPARED_SOURCE="${DOOMGENERIC_DIR}"
"${BUILD}"
unset HAZARD3_DOOM_PREPARED_SOURCE

G_OBJECT="${BUILD_DIR}/g_game.o"
R_OBJECT="${BUILD_DIR}/r_things.o"
OUTPUT="${BUILD_DIR}/hazard3-doom.h3d"
require_file "${G_OBJECT}"
require_file "${R_OBJECT}"
require_file "${OUTPUT}"

"${NM}" "${G_OBJECT}" | grep -Fq 'hazard3_noncombat_g_game_enabled' || {
    echo 'ERROR: compiled g_game.o lacks the noncombat verification symbol.' >&2
    exit 1
}
"${NM}" "${R_OBJECT}" | grep -Fq 'hazard3_noncombat_r_things_enabled' || {
    echo 'ERROR: compiled r_things.o lacks the noncombat verification symbol.' >&2
    exit 1
}

printf '\nNONCOMBAT BUILD VERIFIED\n'
printf '  armor:          200%% (type 2)\n'
printf '  ammo:           0 for all ammo types\n'
printf '  pistol owned:   no\n'
printf '  weapon overlay: hidden\n'
printf '  Fire input:     ignored\n'
printf '  image:          %s\n' "${OUTPUT}"
if command -v sha256sum >/dev/null 2>&1; then
    printf '  SHA-256:        '
    sha256sum "${OUTPUT}" | awk '{print $1}'
fi
