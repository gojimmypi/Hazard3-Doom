#!/bin/bash
# -----------------------------------------------------------------------------
# File:        publish-check.sh
# Path:        scripts/publish-check.sh
#
# Project:     Hazard3-Doom
# Purpose:     Final release checks
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

printf '\n=== Project version ===\n'
./scripts/refresh-version.sh --check

# Checks whether the Git tag on the current commit agrees with the root VERSION file.
project_version="$(tr -d '\r\n' < VERSION)"
release_tag="$(git describe --tags --exact-match --match 'v[0-9]*' HEAD 2>/dev/null || true)"
if [[ -n "${release_tag}" ]]; then
    expected_tag="v${project_version}"
    if [[ "${release_tag}" != "${expected_tag}" ]]; then
        printf 'ERROR: Exact HEAD tag %s does not match VERSION %s; expected %s.\n' \
            "${release_tag}" "${project_version}" "${expected_tag}" >&2
        exit 1
    fi
    printf 'Release tag: %s (matches VERSION)\n' "${release_tag}"
else
    printf 'Release tag: none at HEAD (allowed before tagging)\n'
fi

printf '\n=== Git working tree ===\n'
working_tree_status="$(
    git status \
        --porcelain=v1 \
        --untracked-files=all \
        --ignore-submodules=none
)"
if [[ -n "${working_tree_status}" ]]; then
    printf '%s\n' "${working_tree_status}"
    printf 'ERROR: Release check requires a clean Git working tree.\n' >&2
    exit 1
fi
printf 'PASS: Git working tree is clean.\n'

printf '\n=== Submodules ===\n'
submodule_status="$(git submodule status --recursive)"
printf '%s\n' "${submodule_status}"
if grep -Eq '^[+-U]' <<< "${submodule_status}"; then
    printf 'ERROR: A submodule is uninitialized, modified from its pinned revision, or conflicted.\n' >&2
    exit 1
fi
printf 'PASS: Submodules match their pinned revisions.\n'

printf '\n=== Executable bits ===\n'
./scripts/check-executable.sh 1

printf '\n=== SBOM ===\n'
./scripts/generate-sbom.py --check

printf '\n=== Inventories ===\n'
./scripts/inventory.sh --check ./scripts/
./scripts/inventory.sh --check ./bin/

printf '\n=== Script validation ===\n'
./scripts/test-scripts.sh

printf '\n=== Verify no unexpected changes ===\n'
if [[ -n "$(git status --porcelain=v1 --untracked-files=all --ignore-submodules=none)" ]]; then
    git status --short --ignore-submodules=none
    printf 'ERROR: Release checks changed the working tree.\n' >&2
    exit 1
fi
printf 'PASS: Release checks left the working tree unchanged.\n'

printf '\nPASS: final publish checks completed successfully.\n'
