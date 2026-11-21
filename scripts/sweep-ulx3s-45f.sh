#!/bin/bash
# -----------------------------------------------------------------------------
# File:        sweep-ulx3s-45f.sh
# Path:        scripts/sweep-ulx3s-45f.sh
#
# Project:     Hazard3-Doom
# Purpose:     Dedicated ULX3S 45F compact seed-sweep entry point.
#
# Copyright (c) 2026 gojimmypi
#
# Licensed under the Apache License, Version 2.0.
# SPDX-License-Identifier: Apache-2.0
# -----------------------------------------------------------------------------

set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# Preserve the integrity warning before dispatching to shared code.
"${SCRIPT_DIR}/inventory.sh" --check-file "${BASH_SOURCE[0]}" || true

# 45F uses the compact 12F-style SoC RTL with its own netlist and result paths.
# Select only a matching physical 45F FPGA and speed grade.
exec "${SCRIPT_DIR}/sweep-ulx3s-common.sh" "ulx3s-45f" "$@"
