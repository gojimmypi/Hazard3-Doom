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
require_tool patch
require_tool cmp
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

status="$(git -C "${SOURCE_ROOT}" status --porcelain --untracked-files=all -- doomgeneric)"
if [[ -n "${status}" ]]; then
    temp_diff="$(mktemp)"
    trap 'rm -f "${temp_diff}"' EXIT
    git -C "${SOURCE_ROOT}" diff --binary "${DOOMGENERIC_COMMIT}" -- \
        doomgeneric/d_loop.c \
        doomgeneric/doomgeneric.c \
        doomgeneric/i_video.c \
        > "${temp_diff}"

    allowed_status="$(printf '%s\n' "${status}" | \
        grep -Ev '^[ MADRCU?!]{2} doomgeneric/(d_loop\.c|doomgeneric\.c|i_video\.c)$' || true)"
    if [[ -n "${allowed_status}" ]] || ! cmp -s "${temp_diff}" "${PATCH_FILE}"; then
        echo "DoomGeneric source tree has unexpected local changes:" >&2
        printf '%s\n' "${status}" >&2
        echo "Restore the submodule or regenerate the maintained patch before building." >&2
        exit 1
    fi
    echo "Using local DoomGeneric changes that exactly match the maintained patch." >&2
fi

mkdir -p "${DESTINATION_ROOT}"

# Generated build state only: recreate the prepared source every time so stale
# experimental transforms cannot survive from one build to the next.
source_real="$(cd "${SOURCE_ROOT}" && pwd)"
dest_real="$(cd "${DESTINATION_ROOT}" && pwd)"
case "${dest_real}" in
    /|"${source_real}"|"${source_real}"/*)
        echo "Refusing unsafe DoomGeneric destination: ${dest_real}" >&2
        exit 1
        ;;
esac
if [[ "$(basename "${dest_real}")" != "doomgeneric-source" ]]; then
    echo "Refusing to refresh unexpected prepared-source directory: ${dest_real}" >&2
    echo "Expected the destination basename to be doomgeneric-source." >&2
    exit 1
fi
rm -rf -- "${DESTINATION_ROOT}/doomgeneric"
cp -a "${SOURCE_ROOT}/doomgeneric" "${DESTINATION_ROOT}/"

require_file "${DESTINATION_ROOT}/doomgeneric/doomgeneric.c"
require_file "${DESTINATION_ROOT}/doomgeneric/doomgeneric.h"
require_file "${DESTINATION_ROOT}/doomgeneric/doomkeys.h"
require_file "${DESTINATION_ROOT}/doomgeneric/i_video.h"

if patch --dry-run --batch --silent --forward --fuzz=0 \
    -d "${DESTINATION_ROOT}" -p1 < "${PATCH_FILE}" >/dev/null 2>&1; then
    patch --batch --silent --forward --fuzz=0 \
        -d "${DESTINATION_ROOT}" -p1 < "${PATCH_FILE}"
    echo "Applied maintained Hazard3 DoomGeneric patch to fresh prepared source." >&2
elif patch --dry-run --batch --silent --fuzz=0 --reverse \
    -d "${DESTINATION_ROOT}" -p1 < "${PATCH_FILE}" >/dev/null 2>&1; then
    echo "Confirmed maintained Hazard3 DoomGeneric patch is already present in fresh prepared source." >&2
else
    echo "DoomGeneric patch does not apply cleanly in either direction." >&2
    echo "Prepared source: ${DESTINATION_ROOT}/doomgeneric" >&2
    exit 1
fi

printf '%s\n' "${DESTINATION_ROOT}/doomgeneric"
