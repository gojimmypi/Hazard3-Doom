#!/bin/bash

# Run shellcheck to ensure this is a good script.
# Specify the executable shell checker you want to use:
MY_SHELLCHECK="shellcheck"

# Check if the executable is available in the PATH
if command -v "$MY_SHELLCHECK" >/dev/null 2>&1; then
    # Run your command here
    shellcheck "$0" || exit 1
else
    echo "$MY_SHELLCHECK is not installed. Please install it if changes to this script have been made."
fi

# These variables are consumed by scripts that source this file.
# shellcheck disable=SC2034
DOOMGENERIC_REPOSITORY="https://github.com/ozkl/doomgeneric.git"
# shellcheck disable=SC2034
DOOMGENERIC_COMMIT="dcb7a8dbc7a16ce3dda29382ac9aae9d77d21284"
