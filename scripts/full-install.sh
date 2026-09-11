#!/bin/bash
# -----------------------------------------------------------------------------
# File:        full-install.sh
# Path:        scripts/full-install.sh
#
# Project:     Hazard3-Doom
# Purpose:     Install all requirements
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

# This can be a long-running script. Keep sudo alive for the duration of the script.
sudo -v

## begin sudo keepalive
# Without this section, an unattended install may fail with "sudo: timed out".
while true; do
    sudo -n true
    sleep 60
done 2>/dev/null &
# Keep track of the PID so the sudo keepalive can be stopped when the script exits.
sudo_keepalive_pid=$!

cleanup()
{
    kill "${sudo_keepalive_pid}" 2>/dev/null || true
    wait "${sudo_keepalive_pid}" 2>/dev/null || true
}

trap cleanup EXIT
## end sudo keepalive

sudo apt-get update

sudo apt-get install -y \
    git \
    shellcheck \
    python3-serial

MY_SHELLCHECK="shellcheck"
if command -v "$MY_SHELLCHECK" >/dev/null 2>&1; then
    "${MY_SHELLCHECK}" -x "${BASH_SOURCE[0]}" >&2 || exit 1
else
    echo "$MY_SHELLCHECK is not installed. Please install it if changes to this script have been made."
fi

git clone --recursive https://github.com/gojimmypi/Hazard3-Doom.git
cd Hazard3-Doom

# development branch
git checkout develop

git submodule sync --recursive

git submodule update --init --recursive

./scripts/install-riscv-toolchain.sh

./scripts/install-cmake.sh

./scripts/install-yosys.sh

./scripts/install-nextpnr-ecp5.sh

./scripts/requirements-check.sh
