#!/bin/bash
# -----------------------------------------------------------------------------
# File:        doomgeneric-version.sh
# Path:        scripts/doomgeneric-version.sh
#
# Project:     Hazard3-Doom
# Purpose:     Define the pinned DoomGeneric repository and revision used by
#              build helpers.
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

# Run shellcheck to ensure this is a good script.
# Specify the executable shell checker you want to use:
MY_SHELLCHECK="shellcheck"

# Check if the executable is available in the PATH
if command -v "$MY_SHELLCHECK" >/dev/null 2>&1; then
    # Run your command here
    shellcheck "${BASH_SOURCE[0]}" || exit 1
else
    echo "$MY_SHELLCHECK is not installed. Please install it if changes to this script have been made."
fi

# These variables are consumed by scripts that source this file.
# shellcheck disable=SC2034
DOOMGENERIC_REPOSITORY="https://github.com/ulx3s/doomgeneric.git"
# shellcheck disable=SC2034
DOOMGENERIC_COMMIT="cea50b091ccb2c6309b745750a4a120bc4126995"
