#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_DOOMGENERIC_ROOT="${ROOT_DIR}/third_party/doomgeneric"
DOOMGENERIC_ROOT="${DOOMGENERIC_ROOT:-${DEFAULT_DOOMGENERIC_ROOT}}"

# Run shellcheck to ensure this is a good script.
# Specify the executable shell checker you want to use:
MY_SHELLCHECK="shellcheck"

# Check if the executable is available in the PATH
if command -v "$MY_SHELLCHECK" >/dev/null 2>&1; then
    # Run your command here
    shellcheck -x -P "${SCRIPT_DIR}" "$0" || exit 1
else
    echo "$MY_SHELLCHECK is not installed. Please install it if changes to this script have been made."
fi

# shellcheck source=doomgeneric-version.sh
# shellcheck source-path=SCRIPTDIR
source "${SCRIPT_DIR}/doomgeneric-version.sh"

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

if [[ "${DOOMGENERIC_ROOT}" == "${DEFAULT_DOOMGENERIC_ROOT}" ]]; then
    git -C "${ROOT_DIR}" submodule update --init -- \
        third_party/doomgeneric
fi

git -C "${DOOMGENERIC_ROOT}" rev-parse --is-inside-work-tree \
    >/dev/null 2>&1 || {
    echo "DoomGeneric is not a Git checkout: ${DOOMGENERIC_ROOT}" >&2
    exit 1
}

current_commit="$(git -C "${DOOMGENERIC_ROOT}" rev-parse HEAD)"
if [[ "${current_commit}" != "${DOOMGENERIC_COMMIT}" ]]; then
    echo "Unexpected DoomGeneric commit: ${current_commit}" >&2
    echo "Expected pinned commit: ${DOOMGENERIC_COMMIT}" >&2
    exit 1
fi

require_file "${DOOMGENERIC_ROOT}/doomgeneric/doomgeneric.c"
require_file "${DOOMGENERIC_ROOT}/doomgeneric/doomgeneric.h"
require_file "${DOOMGENERIC_ROOT}/doomgeneric/doomkeys.h"
require_file "${DOOMGENERIC_ROOT}/doomgeneric/i_video.h"

if [[ -n "$(git -C "${DOOMGENERIC_ROOT}" status --porcelain \
    --untracked-files=all -- doomgeneric)" ]]; then
    echo "DoomGeneric source tree has local changes: ${DOOMGENERIC_ROOT}/doomgeneric" >&2
    echo "Restore the submodule to the pinned commit before building." >&2
    exit 1
fi

printf 'DoomGeneric submodule ready at %s\n' "${current_commit}"
printf 'Hazard3 DoomGeneric changes are committed in the pinned fork.\n'
