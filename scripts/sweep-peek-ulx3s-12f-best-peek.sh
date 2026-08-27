#!/bin/bash
#
# Copyright (c) 2026 gojimmypi
# SPDX-License-Identifier: Apache-2.0
#
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
