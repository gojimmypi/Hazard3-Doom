#!/bin/bash
# -----------------------------------------------------------------------------
# File:        hazard3-submodule.sh
# Path:        scripts/hazard3-submodule.sh
#
# Project:     Hazard3-Doom
# Purpose:     Inspect, compare, and restore the Hazard3 submodule and its
#              pinned nested dependencies.
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

# Inspect and restore the Hazard3 submodule used by Hazard3-Doom.
#
# Usage:
#   ./scripts/hazard3-submodule.sh status
#   ./scripts/hazard3-submodule.sh diff
#   ./scripts/hazard3-submodule.sh restore
#
# "status" reports both Hazard3 and DoomGeneric submodules.
# "diff" and "restore" operate on Hazard3.
#
# "restore" checks third_party/Hazard3 out at the gitlink recorded by the
# current Hazard3-Doom HEAD and updates its nested submodules.

SUBMODULE_PATH="third_party/Hazard3"
DOOMGENERIC_PATH="third_party/doomgeneric"

# Run shellcheck to ensure this is a good script.
# Specify the executable shell checker you want to use:
MY_SHELLCHECK="shellcheck"

# Check if the executable is available in the PATH
if command -v "$MY_SHELLCHECK" >/dev/null 2>&1; then
    shellcheck "$0" || exit 1
else
    echo "$MY_SHELLCHECK is not installed. Please install it if changes to this script have been made."
fi

require_tool()
{
    command -v "$1" >/dev/null 2>&1 || {
        echo "Missing required tool: $1" >&2
        exit 1
    }
}

find_root()
{
    local script_dir

    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    if git -C "${script_dir}" rev-parse --show-toplevel >/dev/null 2>&1; then
        git -C "${script_dir}" rev-parse --show-toplevel
        return
    fi

    if git rev-parse --show-toplevel >/dev/null 2>&1; then
        git rev-parse --show-toplevel
        return
    fi

    echo "Run this script from inside a Hazard3-Doom checkout, or place it under that checkout." >&2
    exit 1
}

get_pinned_commit_for_path()
{
    local submodule_path="$1"
    local mode type commit path

    read -r mode type commit path < <(
        git -C "${ROOT_DIR}" ls-tree HEAD -- "${submodule_path}"
    )

    if [[ "${mode:-}" != "160000" || "${type:-}" != "commit" || -z "${commit:-}" ]]; then
        echo "${submodule_path} is not a submodule gitlink in Hazard3-Doom HEAD." >&2
        exit 1
    fi

    printf '%s\n' "${commit}"
}

get_pinned_commit()
{
    get_pinned_commit_for_path "${SUBMODULE_PATH}"
}

get_submodule_name()
{
    local submodule_path="$1"
    local key path name

    while read -r key path; do
        if [[ "${path}" == "${submodule_path}" ]]; then
            name="${key#submodule.}"
            name="${name%.path}"
            printf '%s\n' "${name}"
            return
        fi
    done < <(
        git -C "${ROOT_DIR}" config -f .gitmodules \
            --get-regexp '^submodule\..*\.path$'
    )

    echo "Unable to find ${submodule_path} in .gitmodules." >&2
    exit 1
}

get_submodule_url()
{
    local submodule_path="$1"
    local name

    name="$(get_submodule_name "${submodule_path}")"

    git -C "${ROOT_DIR}" config -f .gitmodules \
        --get "submodule.${name}.url"
}

get_origin_url()
{
    local repo="$1"

    git -C "${repo}" remote get-url origin 2>/dev/null ||
        printf '%s\n' "(no origin remote)"
}

ensure_submodule_initialized()
{
    local submodule_path="$1"
    local submodule_root="${ROOT_DIR}/${submodule_path}"

    if git -C "${submodule_root}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        return
    fi

    git -C "${ROOT_DIR}" submodule update --init -- "${submodule_path}"
}

ensure_hazard3_initialized()
{
    ensure_submodule_initialized "${SUBMODULE_PATH}"
}

check_hazard3_clean()
{
    local dirty

    dirty="$(
        git -C "${HAZARD3_ROOT}" status \
            --porcelain \
            --untracked-files=all \
            --ignore-submodules=none
    )"

    if [[ -n "${dirty}" ]]; then
        echo "Refusing to restore ${SUBMODULE_PATH}: its working tree or nested submodules have local changes:" >&2
        printf '%s\n' "${dirty}" >&2
        exit 1
    fi
}

show_submodule_status()
{
    local label="$1"
    local submodule_path="$2"
    local submodule_root="${ROOT_DIR}/${submodule_path}"
    local pinned current origin source

    ensure_submodule_initialized "${submodule_path}"

    pinned="$(get_pinned_commit_for_path "${submodule_path}")"
    current="$(git -C "${submodule_root}" rev-parse HEAD)"
    origin="$(get_origin_url "${submodule_root}")"
    source="$(get_submodule_url "${submodule_path}")"

    printf '%s:\n' "${label}"
    printf '  Pinned commit      : %s\n' "${pinned}"
    printf '  Current commit     : %s\n' "${current}"
    printf '  Origin             : %s\n' "${origin}"
    printf '  Submodule source   : %s\n' "${source}"

    if [[ "${current}" == "${pinned}" ]]; then
        echo "  State              : matches Hazard3-Doom gitlink"
    else
        echo "  State              : differs from Hazard3-Doom gitlink"
    fi
}

show_status()
{
    local superproject_origin

    superproject_origin="$(get_origin_url "${ROOT_DIR}")"

    printf 'Hazard3-Doom branch : %s\n' "$(git -C "${ROOT_DIR}" branch --show-current)"
    printf 'Hazard3-Doom origin : %s\n' "${superproject_origin}"

    echo
    show_submodule_status "Hazard3" "${SUBMODULE_PATH}"

    echo
    show_submodule_status "DoomGeneric" "${DOOMGENERIC_PATH}"

    echo
    echo "Hazard3-Doom submodule status:"
    git -C "${ROOT_DIR}" status --short -- \
        "${SUBMODULE_PATH}" \
        "${DOOMGENERIC_PATH}"
}

show_diff()
{
    echo "Hazard3-Doom submodule status:"
    git -C "${ROOT_DIR}" status --short -- "${SUBMODULE_PATH}"

    echo
    echo "Hazard3-Doom unstaged submodule-pointer diff:"
    git -C "${ROOT_DIR}" diff --submodule=log -- "${SUBMODULE_PATH}"

    if ! git -C "${ROOT_DIR}" diff --cached --quiet -- "${SUBMODULE_PATH}"; then
        echo
        echo "Hazard3-Doom staged submodule-pointer diff:"
        git -C "${ROOT_DIR}" diff --cached --submodule=log -- "${SUBMODULE_PATH}"
    fi

    echo
    echo "Hazard3 working-tree status:"
    git -C "${HAZARD3_ROOT}" status --short

    echo
    echo "Hazard3 unstaged diff stat:"
    git -C "${HAZARD3_ROOT}" diff --stat --submodule=log

    echo
    echo "Hazard3 unstaged diff:"
    git -C "${HAZARD3_ROOT}" diff --submodule=log

    if ! git -C "${HAZARD3_ROOT}" diff --cached --quiet --ignore-submodules=none; then
        echo
        echo "Hazard3 staged diff stat:"
        git -C "${HAZARD3_ROOT}" diff --cached --stat --submodule=log

        echo
        echo "Hazard3 staged diff:"
        git -C "${HAZARD3_ROOT}" diff --cached --submodule=log
    fi
}

restore_pinned_commit()
{
    local pinned current

    pinned="$(get_pinned_commit)"

    ensure_hazard3_initialized
    check_hazard3_clean

    git -C "${ROOT_DIR}" submodule sync --recursive -- "${SUBMODULE_PATH}"
    git -C "${ROOT_DIR}" submodule update \
        --init \
        --recursive \
        --checkout \
        -- "${SUBMODULE_PATH}"

    current="$(git -C "${HAZARD3_ROOT}" rev-parse HEAD)"

    if [[ "${current}" != "${pinned}" ]]; then
        echo "Failed to restore ${SUBMODULE_PATH} to the Hazard3-Doom gitlink." >&2
        echo "Expected: ${pinned}" >&2
        echo "Current : ${current}" >&2
        exit 1
    fi

    echo
    echo "Hazard3 restored to the commit pinned by Hazard3-Doom HEAD:"
    git -C "${HAZARD3_ROOT}" log -1 --oneline --decorate

    echo
    git -C "${ROOT_DIR}" status --short -- "${SUBMODULE_PATH}"
}

usage()
{
    cat <<USAGE
Usage: $(basename "$0") {status|diff|restore}

  status   Show Hazard3-Doom and its Hazard3/DoomGeneric submodule state
  diff     Show the Hazard3 submodule-pointer difference and local changes
  restore  Restore Hazard3 to the gitlink recorded by Hazard3-Doom HEAD
USAGE
}

require_tool git

ROOT_DIR="$(find_root)"
HAZARD3_ROOT="${ROOT_DIR}/${SUBMODULE_PATH}"

case "${1:-}" in
    status)
        show_status
        ;;
    diff)
        ensure_hazard3_initialized
        show_diff
        ;;
    restore)
        restore_pinned_commit
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac
