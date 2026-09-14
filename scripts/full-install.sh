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

REPO_URL="https://github.com/ulx3s/Hazard3-Doom.git"
REPO_DIR="${PWD}/Hazard3-Doom"
EXISTING_REPO_DIR=""
REUSE_EXISTING_REPO=0

confirm_full_install()
{
    local reply=""

    printf '\nHazard3-Doom full development environment installer\n\n'
    printf 'This script will:\n'
    printf '  - install/update required Ubuntu packages using sudo;\n'
    if (( REUSE_EXISTING_REPO == 1 )); then
        printf '  - use the existing Hazard3-Doom repository at %s;\n' "${REPO_DIR}"
        printf '  - initialize/update its pinned submodules;\n'
    else
        printf '  - clone the Hazard3-Doom repository and initialize its submodules;\n'
    fi
    printf '%s\n' \
        '  - install the RISC-V toolchain, CMake, and native OpenOCD;' \
        '  - build and install Yosys and nextpnr-ecp5/Project Trellis;' \
        '  - run the final requirements check.'

    cat <<'EOF_CONFIRM'

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

# Check minimum system requirements before doing any installation work. When
# downloaded together, check-system-requirements.sh should be beside this file.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_REQUIREMENTS_SCRIPT="${SCRIPT_DIR}/check-system-requirements.sh"

if [[ -r "${SYSTEM_REQUIREMENTS_SCRIPT}" ]]; then
    # shellcheck disable=SC1090
    . "${SYSTEM_REQUIREMENTS_SCRIPT}"

    if ! check_system_requirements "${PWD}"; then
        printf '\nSystem does not meet the minimum Hazard3-Doom development requirements.\n' >&2
        printf 'Increase system resources before continuing the full install.\n' >&2
        exit 1
    fi
else
    printf '%s\n' \
        'WARNING: check-system-requirements.sh was not found beside full-install.sh.' \
        'Minimum system requirements were not checked.' >&2
fi

is_hazard3_doom_repo()
{
    local repo_path="$1"

    [[ -e "${repo_path}/.git" &&
        -r "${repo_path}/scripts/requirements-check.sh" &&
        -r "${repo_path}/scripts/install-riscv-toolchain.sh" ]]
}

# Find an existing Hazard3-Doom checkout before cloning so it can be reused.
# First handle the normal in-repository scripts/full-install.sh location, then
# check the current directory and the usual ./Hazard3-Doom clone destination.
SCRIPT_REPO_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
if [[ "$(basename -- "${SCRIPT_DIR}")" == "scripts" ]] &&
    is_hazard3_doom_repo "${SCRIPT_REPO_DIR}"; then
    EXISTING_REPO_DIR="${SCRIPT_REPO_DIR}"
elif is_hazard3_doom_repo "${PWD}"; then
    EXISTING_REPO_DIR="${PWD}"
elif is_hazard3_doom_repo "${REPO_DIR}"; then
    EXISTING_REPO_DIR="${REPO_DIR}"
fi

if [[ -n "${EXISTING_REPO_DIR}" ]]; then
    printf '\nExisting Hazard3-Doom repository found:\n  %s\n' "${EXISTING_REPO_DIR}"
    printf 'Use this existing repository instead of cloning a new copy? [Y/n] '
    read -r reply

    case "${reply,,}" in
    ""|y|yes)
        REPO_DIR="${EXISTING_REPO_DIR}"
        REUSE_EXISTING_REPO=1
        ;;
    *)
        printf 'Install cancelled. Move or rename the existing repository to perform a fresh clone.\n'
        exit 0
        ;;
    esac
fi

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

if (( REUSE_EXISTING_REPO == 1 )); then
    printf '\nUsing existing Hazard3-Doom repository:\n  %s\n' "${REPO_DIR}"
else
    git clone --recursive "${REPO_URL}" "${REPO_DIR}"
fi

cd "${REPO_DIR}"

# Change branch here as desired
# git checkout develop

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

sudo apt-get install -y openocd
hash -r

printf '\nNative OpenOCD installed:\n'
openocd --version
printf '\nUse ./scripts/start-openocd.sh to select the supported OpenOCD/config path.\n'

if (( IS_WSL == 1 )); then
    if [[ -f ./bin/openocd.exe ]]; then
        printf '%s\n' \
            'Bundled Windows xPack OpenOCD is also available in ./bin/openocd.exe.'
    fi
else
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
