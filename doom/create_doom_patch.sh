#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOOMGENERIC_ROOT="${DOOMGENERIC_ROOT:-${ROOT_DIR}/third_party/doomgeneric}"
PATCH_FILE="${SCRIPT_DIR}/patches/doomgeneric-hazard3-shared-screenbuffer.patch"
TEMP_PATCH="${PATCH_FILE}.tmp.$$"

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

cleanup()
{
    rm -f "${TEMP_PATCH}"
}
trap cleanup EXIT

require_tool cmp
require_tool git

git -C "${DOOMGENERIC_ROOT}" rev-parse --is-inside-work-tree \
    >/dev/null 2>&1 || {
    echo "Missing DoomGeneric checkout: ${DOOMGENERIC_ROOT}" >&2
    echo "Run ${ROOT_DIR}/scripts/setup-doomgeneric.sh first." >&2
    exit 1
}

current_commit="$(git -C "${DOOMGENERIC_ROOT}" rev-parse HEAD)"
if [[ "${current_commit}" != "${DOOMGENERIC_COMMIT}" ]]; then
    echo "Unexpected DoomGeneric commit: ${current_commit}" >&2
    echo "Expected pinned commit: ${DOOMGENERIC_COMMIT}" >&2
    exit 1
fi

if [[ -n "$(git -C "${DOOMGENERIC_ROOT}" ls-files --others \
    --exclude-standard -- doomgeneric)" ]]; then
    echo "DoomGeneric has untracked files under: ${DOOMGENERIC_ROOT}/doomgeneric" >&2
    echo "Remove or preserve them before updating the maintained patch." >&2
    exit 1
fi

mkdir -p "$(dirname "${PATCH_FILE}")"

git -C "${DOOMGENERIC_ROOT}" diff "${DOOMGENERIC_COMMIT}" --binary -- \
    doomgeneric/d_loop.c \
    doomgeneric/doomgeneric.c \
    doomgeneric/i_video.c \
    > "${TEMP_PATCH}"

if [[ ! -s "${TEMP_PATCH}" ]]; then
    echo "No maintained DoomGeneric changes found; patch was not replaced." >&2
    exit 1
fi

if ! cmp -s \
    <(git -C "${DOOMGENERIC_ROOT}" diff "${DOOMGENERIC_COMMIT}" --binary -- doomgeneric) \
    "${TEMP_PATCH}"; then
    echo "DoomGeneric has tracked changes outside the maintained patch files." >&2
    echo "The patch was not replaced." >&2
    exit 1
fi

mv "${TEMP_PATCH}" "${PATCH_FILE}"
grep '^diff --git' "${PATCH_FILE}"
