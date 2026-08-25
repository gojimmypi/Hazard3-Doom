#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
SOURCE_DIR="${ROOT_DIR}/third_party/doomgeneric/doomgeneric"
PREPARED_DIR="${ROOT_DIR}/build/doom-init-verify/doomgeneric-source"
DOOM_BUILD_DIR="${ROOT_DIR}/build/doom-init-verify/doom-image"

rm -rf "${PREPARED_DIR}"
mkdir -p "${PREPARED_DIR}" "${DOOM_BUILD_DIR}"
cp -a "${SOURCE_DIR}/." "${PREPARED_DIR}/"
cp "${SCRIPT_DIR}/r_data.c" "${PREPARED_DIR}/r_data.c"
cp "${SCRIPT_DIR}/w_file_stdc.c" "${PREPARED_DIR}/w_file_stdc.c"

printf 'Preparing diagnostic DoomGeneric tree:\n'
printf '  override r_data.c\n'
printf '    purpose: Doom WAD/cache/texture integrity instrumentation\n'
printf '  override w_file_stdc.c\n'
printf '    purpose: force memory-backed WAD FILE stream unbuffered\n'
printf '\nDiagnostic mode:\n'
printf '  WAD stdio buffering: DISABLED\n'
printf '  TEXTURE1 integrity checks: ENABLED\n'
printf '  fatal exit recovery: ENTRY-FRAME ASSEMBLY (no setjmp)\n'
printf '\nBuilding Doom initialization verifier (unbuffered WAD stdio A/B)\n'
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
