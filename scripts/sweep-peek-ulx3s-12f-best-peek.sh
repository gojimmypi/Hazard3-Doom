#!/bin/bash
# -----------------------------------------------------------------------------
# File:        sweep-peek-ulx3s-12f-best-peek.sh
# Path:        scripts/sweep-peek-ulx3s-12f-best-peek.sh
#
# Project:     Hazard3-Doom
# Purpose:     Route a small set of the strongest ULX3S 12F placement-sweep
#              seed candidates.
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

# File: scripts/sweep-peek-ulx3s-12f.sh
#
# Run placement-only ULX3S 12F nextpnr seed checks against one synthesized
# compact-profile netlist. Use the ranked results to select a small set of
# seeds for the full routed scripts/sweep-ulx3s-12f.sh sweep.

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

mapfile -t seeds < <(
    awk -F, 'NR > 1 {print $1}' \
        build/ulx3s-12f-placement-sweep/32m/ranked.csv |
    head -n 16
)

echo "Testing sweep-ulx3s-12f.sh with seeds:"
echo "${seeds[@]}"

SWEEP_JOBS=8 ./scripts/sweep-ulx3s-12f.sh "${seeds[@]}"
