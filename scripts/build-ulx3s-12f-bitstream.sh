#!/bin/bash
#
# Copyright (c) 2026 gojimmypi
# SPDX-License-Identifier: Apache-2.0
#
# ULX3S 12F entry point for the shared Hazard3-Doom ECP5 build flow.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMMON_SCRIPT="${SCRIPT_DIR}/build-ecp5-bitstream-common.sh"

export HAZARD3_MEMORY_PROFILE="${HAZARD3_MEMORY_PROFILE:-32m}"
# The current nextpnr ECP5 timing model also reports the known-working ULX3S
# 85F 50 MHz design below 50 MHz when the correct LFE5U speed-6 model is used.
# Keep the 12F design itself at 50 MHz, but package the routed image by default
# so it can be validated on hardware. Set ALLOW_TIMING_FAILURE=0 for strict STA.
export ALLOW_TIMING_FAILURE="${ALLOW_TIMING_FAILURE:-1}"

MY_SHELLCHECK="shellcheck"
if command -v "${MY_SHELLCHECK}" >/dev/null 2>&1; then
    shellcheck "$0" "${COMMON_SCRIPT}" || exit 1
else
    echo "${MY_SHELLCHECK} is not installed. Please install it if changes to this script have been made."
fi

exec "${COMMON_SCRIPT}" ulx3s-12f "$@"
