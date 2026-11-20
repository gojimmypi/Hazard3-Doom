#!/bin/bash
# -----------------------------------------------------------------------------
# File:        sweep-ulx3s-12f.sh
# Path:        scripts/sweep-ulx3s-12f.sh
#
# Project:     Hazard3-Doom
# Purpose:     Backward-compatible ULX3S 12F seed-sweep entry point.
#
# Copyright (c) 2026 gojimmypi
#
# Licensed under the Apache License, Version 2.0.
# SPDX-License-Identifier: Apache-2.0
# -----------------------------------------------------------------------------

set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# Preserve the original integrity warning before dispatching to shared code.
"${SCRIPT_DIR}/inventory.sh" --check-file "${BASH_SOURCE[0]}" || true

# Keep the board identity fixed, but let the shared FPGA part selector honor
# ECP5_PNR_DEVICE for substituted speed grades and device families.
exec "${SCRIPT_DIR}/sweep-ulx3s-common.sh" "ulx3s-12f" "$@"
