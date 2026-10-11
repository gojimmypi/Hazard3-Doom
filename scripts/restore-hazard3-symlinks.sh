#!/bin/bash
# -----------------------------------------------------------------------------
# File:        restore-hazard3-symlinks.sh
# Path:        scripts/restore-hazard3-symlinks.sh
#
# Project:     Hazard3-Doom
# Purpose:     Restore known problematic files in Hazard3
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

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
HAZARD3_DIR="$REPO_ROOT/third_party/Hazard3"

if [ ! -d "$HAZARD3_DIR/.git" ] && [ ! -f "$HAZARD3_DIR/.git" ]; then
    echo "Error: Hazard3 repository not found at: $HAZARD3_DIR" >&2
    exit 1
fi

cd -- "$HAZARD3_DIR"

# These 3 files are known to be problematic on WSL shared filesystems, so we restore them to the HEAD version.
echo "git restore:"

COREMARK_SYMLINKS=(
    "test/sim/coremark/dist/barebones/hazard3_csr.h"
    "test/sim/coremark/dist/barebones/init.S"
    "test/sim/coremark/dist/barebones/tb_cxxrtl_io.h"
)

echo "${COREMARK_SYMLINKS[@]}"

if git restore --worktree --source=HEAD -- "${COREMARK_SYMLINKS[@]}"; then
    echo "Success: git restore completed."
else
    rc=$?
    echo "Error: git restore failed with exit code $rc." >&2
    exit "$rc"
fi

if git diff --quiet --no-ext-diff HEAD -- "${COREMARK_SYMLINKS[@]}"; then
    echo "Confirmed: Hazard3 CoreMark symlinks match HEAD."
else
    rc=$?

    if [ "$rc" -eq 1 ]; then
        echo "Error: one or more restored paths still differ from HEAD." >&2
        git diff --summary HEAD -- "${COREMARK_SYMLINKS[@]}" >&2
    else
        echo "Error: restore verification failed with exit code $rc." >&2
    fi

    exit "$rc"
fi
