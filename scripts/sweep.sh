#!/bin/bash
# -----------------------------------------------------------------------------
# File:        sweep.sh
# Path:        scripts/sweep.sh
#
# Project:     Hazard3-Doom
# Purpose:     Backward-compatible ULX3S 85F seed-sweep entry point.
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
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/sweep-ulx3s-85f.sh" "$@"
