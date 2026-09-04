#!/bin/bash
# -----------------------------------------------------------------------------
# File:        check-executable.sh
# Path:        scripts/check-executable.sh
#
# Project:     Hazard3-Doom
# Purpose:     Check recently changed tracked shell scripts for the Git
#              executable bit.
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

#
# File: scripts/check-executable.sh
#
# Ensure shell scripts changed in recent commits are executable when checked into git.
#
# Run from the repository root:
#   ./scripts/check-executable.sh [commit-count]
#
# If commit-count is omitted, the most recent 5 commits are checked.
#
# For example to fix:
#
#   git config core.fileMode false
#   THISFILE="scripts/build-doom-noncombat.sh"
#   git update-index --chmod=+x "${THISFILE}"
#   git ls-files --stage "${THISFILE}"
#
# Run shellcheck to ensure this is a good script.
# Specify the executable shell checker you want to use:
MY_SHELLCHECK="shellcheck"

# Check if the executable is available in the PATH
if command -v "${MY_SHELLCHECK}" >/dev/null 2>&1; then
    "${MY_SHELLCHECK}" "$0" || exit 1
else
    echo "${MY_SHELLCHECK} is not installed. Please install it if changes to this script have been made."
fi

if [[ $# -gt 1 ]]; then
    echo "Usage: $0 [commit-count]" >&2
    exit 1
fi

COMMIT_COUNT="${1:-5}"
if [[ ! "${COMMIT_COUNT}" =~ ^[1-9][0-9]*$ ]]; then
    echo "commit-count must be a positive integer: ${COMMIT_COUNT}" >&2
    exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "Not inside a Git repository." >&2
    exit 1
}
cd "${REPO_ROOT}" || exit 1

if ! git rev-parse --verify --quiet "HEAD~${COMMIT_COUNT}" >/dev/null; then
    echo "Repository does not have ${COMMIT_COUNT} commits before HEAD." >&2
    exit 1
fi

status=0
while IFS= read -r -d '' script; do
    if [[ ! -f "${script}" ]]; then
        continue
    fi

    IFS= read -r first_line < "${script}" || true
    if [[ "${first_line}" != '#!'* ]]; then
        continue
    fi

    mode="$(git ls-files --stage -- "${script}" | awk '{print $1}')"

    if [[ "${mode}" != "100755" ]]; then
        printf '%s  %s\n' "${mode:-untracked}" "${script}"
        status=1
    fi
done < <(git diff --name-only --diff-filter=ACMRT -z "HEAD~${COMMIT_COUNT}..HEAD")

exit "${status}"
