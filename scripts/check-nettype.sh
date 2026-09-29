#!/bin/bash
# -----------------------------------------------------------------------------
# File:        check-nettype.sh
# Path:        scripts/check-nettype.sh
#
# Project:     Hazard3-Doom
# Purpose:     Validate consistent default_nettype handling in tracked
#              Verilog source files.
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

# file: scripts/check-nettype.sh
#
set -euo pipefail

# Verify this script against the recorded inventory without blocking normal execution.
"$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/inventory.sh" \
    --check-file "${BASH_SOURCE[0]}" || true

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

fail=0
expected_first='`default_nettype none'
expected_last='`default_nettype wire'

echo "Checking Hazard3-Doom-owned Verilog files..."

while IFS= read -r -d '' file; do
    echo ""
    echo "Checking: $file"
    file_path="${REPO_ROOT}/${file}"

    first_line=$(awk '
        BEGIN {
            in_block = 0
        }

        {
            line = $0
            gsub(/\r/, "", line)

            while (1) {
                if (in_block) {
                    if (match(line, /\*\//)) {
                        line = substr(line, RSTART + RLENGTH)
                        in_block = 0
                    } else {
                        line = ""
                        break
                    }
                } else if (match(line, /\/\*/)) {
                    before = substr(line, 1, RSTART - 1)
                    after = substr(line, RSTART + RLENGTH)

                    if (match(after, /\*\//)) {
                        after = substr(after, RSTART + RLENGTH)
                        line = before after
                    } else {
                        line = before
                        in_block = 1
                    }
                } else {
                    break
                }
            }

            sub(/^[ \t]+/, "", line)
            sub(/[ \t]+$/, "", line)

            if (line == "") {
                next
            }

            if (line ~ /^\/\//) {
                next
            }

            print line
            exit
        }
    ' "${file_path}")

    last_line=$(awk '
        BEGIN {
            in_block = 0
        }

        {
            line = $0
            gsub(/\r/, "", line)

            while (1) {
                if (in_block) {
                    if (match(line, /\*\//)) {
                        line = substr(line, RSTART + RLENGTH)
                        in_block = 0
                    } else {
                        line = ""
                        break
                    }
                } else if (match(line, /\/\*/)) {
                    before = substr(line, 1, RSTART - 1)
                    after = substr(line, RSTART + RLENGTH)

                    if (match(after, /\*\//)) {
                        after = substr(after, RSTART + RLENGTH)
                        line = before after
                    } else {
                        line = before
                        in_block = 1
                    }
                } else {
                    break
                }
            }

            sub(/^[ \t]+/, "", line)
            sub(/[ \t]+$/, "", line)

            if (line == "") {
                next
            }

            if (line ~ /^\/\//) {
                next
            }

            last = line
        }

        END {
            print last
        }
    ' "${file_path}")

    if [ "$first_line" != "$expected_first" ]; then
        echo "ERROR: First meaningful line is not $expected_first"
        echo "  Found: $first_line"
        fail=1
    fi

    if [ "$last_line" != "$expected_last" ]; then
        echo "ERROR: Last meaningful line is not $expected_last"
        echo "  Found: $last_line"
        fail=1
    fi
done < <(
    git -C "${REPO_ROOT}" ls-files -z -- \
        ':(glob)src/**/*.v' \
        ':(glob)tests/**/*.v'
)

echo ""

if [ "$fail" -ne 0 ]; then
    echo "FAILED: default_nettype checks did not pass"
    exit 1
fi

echo "SUCCESS: All Verilog files passed default_nettype checks"
