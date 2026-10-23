#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File:        git-exe-recurse.sh
# Path:        scripts/git-exe-recurse.sh
#
# Project:     Hazard3-Doom
# Purpose:     Recursively set the Git executable bit for tracked .py and .sh
#              files below a specified directory using git-exe.sh.
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

# Verify this script against the recorded inventory without blocking normal execution.
"$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/inventory.sh" \
    --check-file "${BASH_SOURCE[0]}" || true

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

usage()
{
    echo "Usage: $(basename -- "$0") <directory>" >&2
    echo "Example: ./scripts/git-exe-recurse.sh ./bootloader-serv" >&2
}

if [[ $# -ne 1 ]]; then
    usage
    exit 2
fi

if [[ ! -d "$1" ]]; then
    echo "Error: directory does not exist: $1" >&2
    exit 1
fi

target_dir="$(cd -- "$1" && pwd -P)"

if ! git -C "$target_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: directory is not inside a Git worktree: $target_dir" >&2
    exit 1
fi

# Collect the complete file list before changing the Git index. NUL delimiters
# preserve spaces and other special characters in filenames.
file_list="$(mktemp)"
trap 'rm -f -- "$file_list"' EXIT

if ! find "$target_dir" -type f \( -name '*.py' -o -name '*.sh' \) -print0 > "$file_list"; then
    echo "Error: unable to scan directory: $target_dir" >&2
    exit 1
fi

found=0
updated=0
skipped=0
failed=0

while IFS= read -r -d '' file_path; do
    found=$((found + 1))
    file_dir="${file_path%/*}"
    file_name="${file_path##*/}"

    # git-exe.sh only accepts tracked files. Untracked files can be handled
    # after they have been added to the index.
    if ! git -C "$file_dir" ls-files --error-unmatch -- "$file_name" >/dev/null 2>&1; then
        printf 'SKIP (untracked): %s\n' "$file_path"
        skipped=$((skipped + 1))
        continue
    fi

    printf '\nProcessing: %s\n' "$file_path"
    if "$SCRIPT_DIR/git-exe.sh" "$file_path"; then
        updated=$((updated + 1))
    else
        printf 'FAIL: %s\n' "$file_path" >&2
        failed=$((failed + 1))
    fi
done < "$file_list"

printf '\nSummary: %d found, %d updated, %d skipped (untracked), %d failed\n' \
    "$found" "$updated" "$skipped" "$failed"

if (( failed > 0 )); then
    exit 1
fi
