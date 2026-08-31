#!/bin/bash
# -----------------------------------------------------------------------------
# File:        build-ulx3s-85f-bitstream.sh
# Path:        scripts/build-ulx3s-85f-bitstream.sh
#
# Project:     Hazard3-Doom
# Purpose:     Build the ULX3S 85F FPGA bitstream through the shared ECP5
#              flow.
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

# file: scripts/build-ulx3s-85f-bitstream.sh
#
# ULX3S 85F entry point for the shared Hazard3-Doom ECP5 build flow.
#
# See build-ecp5-bitstream-common.sh for NEXTPNR_SEED default seeds
#

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMMON_SCRIPT="${SCRIPT_DIR}/build-ecp5-bitstream-common.sh"

MY_SHELLCHECK="shellcheck"
if command -v "${MY_SHELLCHECK}" >/dev/null 2>&1; then
    shellcheck "$0" "${COMMON_SCRIPT}" || exit 1
else
    echo "${MY_SHELLCHECK} is not installed. Please install it if changes to this script have been made."
fi

exec "${COMMON_SCRIPT}" ulx3s-85f "$@"
