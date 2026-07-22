#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE_ROOT="${DOOMGENERIC_ROOT:-${ROOT_DIR}/third_party/doomgeneric}"
DESTINATION_ROOT="${1:?usage: prepare-doomgeneric.sh DESTINATION_ROOT}"
PATCH_FILE="${SCRIPT_DIR}/patches/doomgeneric-hazard3-shared-screenbuffer.patch"

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
require_tool cmp
require_tool patch
require_file "${SOURCE_ROOT}/doomgeneric/doomgeneric.c"
require_file "${SOURCE_ROOT}/doomgeneric/doomgeneric.h"
require_file "${SOURCE_ROOT}/doomgeneric/doomkeys.h"
require_file "${SOURCE_ROOT}/doomgeneric/i_video.h"
require_file "${PATCH_FILE}"

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

if [[ -n "$(git -C "${SOURCE_ROOT}" status --porcelain --untracked-files=all -- doomgeneric)" ]]; then
    if [[ -n "$(git -C "${SOURCE_ROOT}" ls-files --others \
        --exclude-standard -- doomgeneric)" ]]; then
        echo "DoomGeneric has untracked files under: ${SOURCE_ROOT}/doomgeneric" >&2
        echo "Only the exact tracked changes in ${PATCH_FILE} are allowed." >&2
        exit 1
    fi

    if ! cmp -s \
        <(git -C "${SOURCE_ROOT}" diff "${DOOMGENERIC_COMMIT}" --binary -- doomgeneric) \
        "${PATCH_FILE}"; then
        echo "DoomGeneric local changes do not exactly match the maintained patch." >&2
        echo "Expected patch: ${PATCH_FILE}" >&2
        exit 1
    fi

    echo "Using local DoomGeneric changes that exactly match the maintained patch." >&2
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

if  patch --dry-run --batch --silent --forward --fuzz=0 -d "${DESTINATION_ROOT}" -p1 < "${PATCH_FILE}" >/dev/null; then
    patch           --batch --silent --forward --fuzz=0 -d "${DESTINATION_ROOT}" -p1 < "${PATCH_FILE}" >/dev/null
elif patch --dry-run --batch --silent --fuzz=0 --reverse -d "${DESTINATION_ROOT}" -p1 < "${PATCH_FILE}" >/dev/null; then
    : # The verified temporary build copy is already patched.
    echo "Confirmed DoomGeneric patch is already applied in the prepared source: ${DESTINATION_ROOT}/doomgeneric" >&2
else
    echo "DoomGeneric patch does not apply cleanly in either direction." >&2
    echo "Prepared source: ${DESTINATION_ROOT}/doomgeneric" >&2
    exit 1
fi

printf '%s\n' "${DESTINATION_ROOT}/doomgeneric"
