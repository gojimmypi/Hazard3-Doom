#!/bin/bash
#
# Copyright (c) 2026 gojimmypi
# SPDX-License-Identifier: Apache-2.0
#
# file: scripts/build-ulx4m-ld-bitstream.sh
#
# ULX4M-LD 85F entry point for the shared Hazard3-Doom ECP5 build flow.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMMON_SCRIPT="${SCRIPT_DIR}/build-ecp5-bitstream-common.sh"

MY_SHELLCHECK="shellcheck"
if command -v "${MY_SHELLCHECK}" >/dev/null 2>&1; then
    shellcheck "$0" "${COMMON_SCRIPT}" || exit 1
else
    echo "${MY_SHELLCHECK} is not installed. Please install it if changes to this script have been made."
fi

exec "${COMMON_SCRIPT}" ulx4m-ld-85f "$@"
