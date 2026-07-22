#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOOMGENERIC_ROOT="${DOOMGENERIC_ROOT:-${ROOT_DIR}/third_party/doomgeneric}"
PREPARE_DOOMGENERIC="${SCRIPT_DIR}/prepare-doomgeneric.sh"
TOOLCHAIN_PREFIX="${TOOLCHAIN_PREFIX:-/opt/riscv/bin/riscv32-unknown-elf-}"
CC="${TOOLCHAIN_PREFIX}gcc"
OBJCOPY="${TOOLCHAIN_PREFIX}objcopy"
NM="${TOOLCHAIN_PREFIX}nm"
SIZE="${TOOLCHAIN_PREFIX}size"
BUILD_DIR="${HAZARD3_DOOM_BUILD_DIR:-${ROOT_DIR}/build/doom-image}"
OUTPUT_ELF="${BUILD_DIR}/hazard3-doom.elf"
OUTPUT_BIN="${BUILD_DIR}/hazard3-doom.bin"
OUTPUT_IMAGE="${BUILD_DIR}/hazard3-doom.h3d"

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
require_tool "${OBJCOPY}"
require_tool "${NM}"
require_tool "${SIZE}"
require_tool python3

require_tool "${PREPARE_DOOMGENERIC}"
require_file "${SCRIPT_DIR}/doom_sources.sh"
require_file "${SCRIPT_DIR}/doom_build_flags.sh"
require_file "${SCRIPT_DIR}/doom_image_entry.S"
require_file "${SCRIPT_DIR}/doom_image_link.ld"
require_file "${SCRIPT_DIR}/package-doom-image.py"
require_file "${DOOMGENERIC_ROOT}/doomgeneric/doomgeneric.c"
require_file "${DOOMGENERIC_ROOT}/doomgeneric/doomgeneric.h"
require_file "${DOOMGENERIC_ROOT}/doomgeneric/doomkeys.h"
require_file "${DOOMGENERIC_ROOT}/doomgeneric/i_video.h"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/doom_sources.sh"

PORT_SOURCES=(
    doomgeneric_hazard3.c
    hazard3_newlib.c
    hazard3_platform_image.c
    doom_image_main.c
)
for source in "${PORT_SOURCES[@]}"; do
    require_file "${SCRIPT_DIR}/${source}"
done

# Object and output files are overwritten in place. The prepared DoomGeneric
# tree is verified and reused, so a build never recursively removes an
# environment-selected directory.
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
    "${DOOM_ARCH_FLAGS[0]}" "-O2 (Performance-R5)"

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

entry_object="${BUILD_DIR}/doom_image_entry.o"
echo "[AS] doom_image_entry.S"
"${CC}" "${DOOM_COMMON_COMPILE_FLAGS[@]}" \
    -c "${SCRIPT_DIR}/doom_image_entry.S" -o "${entry_object}"
objects+=("${entry_object}")

echo "[LD] ${OUTPUT_ELF}"
"${CC}" "${DOOM_LINK_FLAGS[@]}" \
    -Wl,-T,"${SCRIPT_DIR}/doom_image_link.ld" \
    -Wl,-Map,"${BUILD_DIR}/hazard3-doom.map" \
    -Wl,--cref \
    -o "${OUTPUT_ELF}" \
    "${objects[@]}" \
    -Wl,--start-group -lc -lm -lgcc -lnosys -Wl,--end-group

echo "[OBJCOPY] ${OUTPUT_BIN}"
"${OBJCOPY}" -O binary "${OUTPUT_ELF}" "${OUTPUT_BIN}"

echo "[PACKAGE] ${OUTPUT_IMAGE}"
python3 "${SCRIPT_DIR}/package-doom-image.py" \
    --elf "${OUTPUT_ELF}" \
    --binary "${OUTPUT_BIN}" \
    --output "${OUTPUT_IMAGE}" \
    --nm "${NM}"

echo
echo "Linked Doom image size:"
"${SIZE}" "${OUTPUT_ELF}"
echo
echo "UART package ready: ${OUTPUT_IMAGE}"
