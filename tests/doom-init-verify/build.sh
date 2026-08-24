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

printf 'Building Doom initialization verifier\n'
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
