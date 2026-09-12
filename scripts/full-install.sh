#!/bin/bash
# -----------------------------------------------------------------------------
# File:        full-install.sh
# Path:        scripts/full-install.sh
#
# Project:     Hazard3-Doom
# Purpose:     Install all requirements
#
# WARNING:     Existing installs of yoysys and nextpnr may be overwritten by this script.
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

confirm_full_install()
{
    local reply=""

    cat <<'EOF_CONFIRM'
Hazard3-Doom full development environment installer

This script will:
  - install/update required Ubuntu packages using sudo;
  - clone the Hazard3-Doom repository and initialize its submodules;
  - install the RISC-V toolchain and CMake;
  - build and install Yosys and nextpnr-ecp5/Project Trellis;
  - run the final requirements check.

WARNING: The Yosys and nextpnr installation steps may overwrite or replace
existing installations in their target install locations.

This can take a long time and use substantial CPU, RAM, disk, and swap.
EOF_CONFIRM

    printf '\nContinue with the full install? [y/N] '
    read -r reply

    case "${reply,,}" in
    y|yes)
        ;;
    *)
        printf 'Install cancelled.\n'
        exit 0
        ;;
    esac
}

confirm_full_install


# Check environment. We can run Windows .exe files from WSL, not other Linux
kernel_release=""

kernel_release="$(uname -r 2>/dev/null || true)"
IS_WSL=0
if [[ -n "${WSL_DISTRO_NAME:-}" || -n "${WSL_INTEROP:-}" ]] ||
    [[ "${kernel_release,,}" == *microsoft* ]]; then
    IS_WSL=1
fi

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
    python3-serial \
    usbutils

MY_SHELLCHECK="shellcheck"
if command -v "$MY_SHELLCHECK" >/dev/null 2>&1; then
    "${MY_SHELLCHECK}" -x "${BASH_SOURCE[0]}" >&2 || exit 1
else
    echo "$MY_SHELLCHECK is not installed. Please install it if changes to this script have been made."
fi

git clone --recursive https://github.com/ulx3s/Hazard3-Doom.git
cd Hazard3-Doom

# Change branch here as desired
# git checkout develop

SYSTEM_REQUIREMENTS_SCRIPT="${PWD}/scripts/check-system-requirements.sh"
if [[ ! -r "${SYSTEM_REQUIREMENTS_SCRIPT}" ]]; then
    printf 'Missing required helper: %s\n' "${SYSTEM_REQUIREMENTS_SCRIPT}" >&2
    exit 1
fi

# The path is resolved from the newly cloned repository.
# shellcheck disable=SC1090
. "${SYSTEM_REQUIREMENTS_SCRIPT}"

if ! check_system_requirements "${PWD}"; then
    printf '\nSystem does not meet the minimum Hazard3-Doom development requirements.\n' >&2
    printf 'Increase system resources before continuing the full install.\n' >&2
    exit 1
fi

git submodule sync --recursive

git submodule update --init --recursive

./scripts/install-riscv-toolchain.sh

./scripts/install-cmake.sh

./scripts/install-yosys.sh

hash -r
yosys -V

./scripts/install-nextpnr-ecp5.sh

hash -r
ecppack --version
nextpnr-ecp5 --version

if (( IS_WSL == 1 )); then
    echo "openocd.exe available in ./bin/"
else
    sudo apt-get install -y openocd
    if command -v udevadm >/dev/null 2>&1; then
        if sudo udevadm control --reload-rules; then
            printf '%s\n' \
                'Reloaded udev rules for native Linux OpenOCD access.' \
                'If the ULX3S is already connected, unplug and reconnect it.'
        else
            printf '%s\n' \
                'WARNING: Could not reload udev rules automatically.' \
                'Reconnect the ULX3S after udev is available.' >&2
        fi
    fi
fi

./scripts/requirements-check.sh
