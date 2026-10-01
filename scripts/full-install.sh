#!/bin/bash
# -----------------------------------------------------------------------------
# File:        full-install.sh
# Path:        scripts/full-install.sh
#
# Project:     Hazard3-Doom
# Purpose:     Install all requirements
#
# WARNING:     Source-build mode may replace /usr/local Yosys/nextpnr installs.
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

# Verify this script against the recorded inventory without blocking normal execution.
"$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/inventory.sh" \
    --check-file "${BASH_SOURCE[0]}" || true

REPO_URL="https://github.com/ulx3s/Hazard3-Doom.git"
REPO_DIR="${PWD}/Hazard3-Doom"
EXISTING_REPO_DIR=""
REUSE_EXISTING_REPO=0
DEFAULT_OSS_CAD_SUITE_VERSION="2026-07-20"
OSS_CAD_SUITE_VERSION="${OSS_CAD_SUITE_VERSION:-${DEFAULT_OSS_CAD_SUITE_VERSION}}"
FPGA_TOOLS_FROM_SOURCE=0
FORCE_OSS_CAD_SUITE=0

usage()
{
    cat <<'USAGE'
Usage:
    full-install.sh [options]

Options:
    --oss-cad-suite-version VERSION
                       OSS CAD Suite release used when the managed suite is
                       needed. Default: 2026-07-20.
    --install-oss-cad-suite
                       Force installation/selection of the managed OSS CAD
                       Suite even when qualified FPGA tools are already on PATH.
    --fpga-tools-from-source
                       Force rebuilding the pinned Yosys/nextpnr revisions
                       instead of reusing qualified tools already on PATH.
    -h, --help         Show this help.
USAGE
}

die()
{
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

while (($# > 0)); do
    case "$1" in
        --oss-cad-suite-version)
            (($# >= 2)) || die "--oss-cad-suite-version requires a release tag"
            OSS_CAD_SUITE_VERSION="$2"
            shift 2
            ;;
        --install-oss-cad-suite)
            FORCE_OSS_CAD_SUITE=1
            shift
            ;;
        --fpga-tools-from-source)
            FPGA_TOOLS_FROM_SOURCE=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "unknown argument: $1"
            ;;
    esac
done

if (( FPGA_TOOLS_FROM_SOURCE == 1 && FORCE_OSS_CAD_SUITE == 1 )); then
    die "--fpga-tools-from-source and --install-oss-cad-suite cannot be used together"
fi

version_ge()
{
    printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

cmake_is_compatible()
{
    local output=""
    local version=""

    if ! command -v cmake >/dev/null 2>&1; then
        return 1
    fi

    if output="$(cmake --version 2>&1)"; then
        output="${output%%$'\n'*}"
    else
        return 1
    fi

    if [[ "${output}" =~ ^cmake[[:space:]]version[[:space:]]([0-9]+(\.[0-9]+)+) ]]; then
        version="${BASH_REMATCH[1]}"
    fi

    if [[ -z "${version}" ]]; then
        return 1
    fi

    if version_ge "${version}" "3.28"; then
        return 0
    fi

    return 1
}

fpga_tools_are_qualified()
{
    local yosys_output=""
    local nextpnr_output=""
    local ecppack_output=""

    if ! command -v yosys >/dev/null 2>&1; then
        return 1
    fi
    if ! command -v nextpnr-ecp5 >/dev/null 2>&1; then
        return 1
    fi
    if ! command -v ecppack >/dev/null 2>&1; then
        return 1
    fi

    if ! yosys_output="$(yosys -V 2>&1)"; then
        return 1
    fi
    if ! nextpnr_output="$(nextpnr-ecp5 --version 2>&1)"; then
        return 1
    fi
    if ! ecppack_output="$(ecppack --version 2>&1)"; then
        return 1
    fi

    if [[ "${yosys_output}" != *"Yosys 0.67+47"* ]]; then
        return 1
    fi
    if [[ "${nextpnr_output}" != *"nextpnr-0.10-95-gddc6c8c8"* ]]; then
        return 1
    fi
    if [[ "${ecppack_output}" != *"Project Trellis ecppack Version 1.4-76-g73bd411"* ]] &&
       [[ "${ecppack_output}" != *"Project Trellis ecppack Version 1.4-79-g56bb170"* ]]; then
        return 1
    fi

    return 0
}

confirm_full_install()
{
    local reply=""

    printf '\nHazard3-Doom full development environment installer\n\n'
    printf 'This script will:\n'
    printf '  - reuse compatible installed tools and install only missing requirements;\n'
    if (( REUSE_EXISTING_REPO == 1 )); then
        printf '  - use the existing Hazard3-Doom repository at %s;\n' "${REPO_DIR}"
        printf '  - initialize/update its pinned submodules;\n'
    else
        printf '  - clone the Hazard3-Doom repository and initialize its submodules;\n'
    fi
    printf '%s\n' \
        '  - reuse a compatible RISC-V toolchain or install the pinned xPack fallback;' \
        '  - reuse CMake 3.28+ and an available OpenOCD installation;'
    if (( FPGA_TOOLS_FROM_SOURCE == 1 )); then
        printf '  - force-build the pinned Yosys and nextpnr/Project Trellis source revisions;\n'
    elif (( FORCE_OSS_CAD_SUITE == 1 )); then
        printf '  - force-install OSS CAD Suite %s;\n' "${OSS_CAD_SUITE_VERSION}"
    else
        printf '  - reuse qualified FPGA tools already on PATH, otherwise install OSS CAD Suite %s;\n' \
            "${OSS_CAD_SUITE_VERSION}"
    fi
    printf '%s\n' '  - run the final requirements check.'

    if ((FPGA_TOOLS_FROM_SOURCE == 1)); then
        cat <<'EOF_CONFIRM'

WARNING: Source-build mode installs FPGA tools under /usr/local and may replace
existing Yosys, nextpnr, or Project Trellis files there.

This can take a long time and use substantial CPU, RAM, disk, and swap.
EOF_CONFIRM
    fi

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

# Keep sudo authentication alive only after a step actually needs sudo.
sudo_keepalive_pid=""

cleanup()
{
    if [[ -n "${sudo_keepalive_pid}" ]]; then
        kill "${sudo_keepalive_pid}" 2>/dev/null || true
        wait "${sudo_keepalive_pid}" 2>/dev/null || true
    fi
}

trap cleanup EXIT

ensure_sudo_keepalive()
{
    if [[ -n "${sudo_keepalive_pid}" ]]; then
        return 0
    fi

    sudo -v
    while true; do
        sudo -n true
        sleep 60
    done 2>/dev/null &
    sudo_keepalive_pid=$!
}

apt_get()
{
    # Disable dpkg's PTY progress output. It can leave copied WSL terminal
    # output looking like a staircase because carriage-return progress updates
    # are preserved by some Windows terminal paths.
    sudo apt-get -o Dpkg::Use-Pty=0 "$@"
}

install_missing_base_packages()
{
    local packages=()

    if ! command -v git >/dev/null 2>&1; then
        packages+=(git)
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        packages+=(python3 python3-serial)
    elif ! python3 -c 'import serial' >/dev/null 2>&1; then
        packages+=(python3-serial)
    fi
    if (( IS_WSL == 0 )) && ! command -v lsusb >/dev/null 2>&1; then
        packages+=(usbutils)
    fi

    if (( ${#packages[@]} == 0 )); then
        printf '\nRequired base packages are already available; no apt installation needed.\n'
        return 0
    fi

    printf '\nInstalling missing base packages: %s\n' "${packages[*]}"
    ensure_sudo_keepalive
    apt_get update
    apt_get install -y "${packages[@]}"
}

install_missing_base_packages

if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -x "${BASH_SOURCE[0]}" >&2 || exit 1
else
    printf '%s\n' \
        'WARNING: ShellCheck is not installed; continuing without optional shell linting.' >&2
fi

if (( REUSE_EXISTING_REPO == 1 )); then
    printf '\nUsing existing Hazard3-Doom repository:\n  %s\n' "${REPO_DIR}"
else
    git clone --recursive "${REPO_URL}" "${REPO_DIR}"
fi

cd "${REPO_DIR}"

if [[ -r ./VERSION ]]; then
    project_version="$(tr -d '\r\n' < ./VERSION)"
    printf '\nHazard3-Doom project version: v%s\n' "${project_version}"
else
    printf '\nWARNING: Repository VERSION file was not found.\n' >&2
fi

# Change branch here as desired
# git checkout develop

git submodule sync --recursive

git submodule update --init --recursive

RISCV_DOOM_RUNTIME_SCRIPT="./scripts/riscv-doom-runtime.sh"
if [[ ! -r "${RISCV_DOOM_RUNTIME_SCRIPT}" ]]; then
    printf 'ERROR: Missing required helper: %s\n' "${RISCV_DOOM_RUNTIME_SCRIPT}" >&2
    exit 1
fi

# shellcheck disable=SC1090
. "${RISCV_DOOM_RUNTIME_SCRIPT}"

RISCV_XPACK_BIN="${HOME}/.local/xPacks/riscv-none-elf-gcc/current/bin"
RISCV_XPACK_WAS_NEEDED=0

compatible_riscv_toolchain_exists()
{
    hazard3_find_compatible_riscv_prefix >/dev/null 2>&1
}

DISTRO_RISCV_GCC="$(command -v riscv64-unknown-elf-gcc 2>/dev/null || true)"
if [[ "${DISTRO_RISCV_GCC}" == "/usr/bin/riscv64-unknown-elf-gcc" ]]; then
    if hazard3_riscv_prefix_is_complete riscv64-unknown-elf- && \
        hazard3_riscv_compiler_accepts_hazard3 riscv64-unknown-elf- && \
        ! hazard3_configure_doom_runtime riscv64-unknown-elf-; then
        printf '%s\n' \
            'Ubuntu/Debian RISC-V GCC detected without a usable Doom target C runtime.' \
            'Installing picolibc-riscv64-unknown-elf and using its picolibc.specs file.'
        ensure_sudo_keepalive
        apt_get update
        apt_get install -y picolibc-riscv64-unknown-elf
        hash -r
    fi
fi

if compatible_riscv_toolchain_exists; then
    RISCV_XPACK_WAS_NEEDED=0
else
    RISCV_XPACK_WAS_NEEDED=1
fi

./scripts/install-riscv-toolchain.sh

if ! compatible_riscv_toolchain_exists; then
    if [[ -x "${RISCV_XPACK_BIN}/riscv-none-elf-gcc" ]]; then
        export PATH="${RISCV_XPACK_BIN}:${PATH}"
        hash -r
    fi
fi

if ! compatible_riscv_toolchain_exists; then
    printf 'ERROR: No complete compatible RISC-V toolchain is available after installation.\n' >&2
    exit 1
fi

if cmake_is_compatible; then
    printf '\nCompatible CMake already available; reusing it:\n'
    cmake --version | head -n 1
else
    printf '\nCMake 3.28+ is unavailable; installing/updating CMake.\n'
    ensure_sudo_keepalive
    ./scripts/install-cmake.sh
fi

if (( FPGA_TOOLS_FROM_SOURCE == 1 )); then
    printf '\nSource FPGA tool build explicitly requested.\n'
    ensure_sudo_keepalive
    ./scripts/install-yosys.sh --from-source
    ./scripts/install-nextpnr-ecp5.sh --from-source
elif (( FORCE_OSS_CAD_SUITE == 1 )); then
    printf '\nManaged OSS CAD Suite explicitly requested.\n'
    ./scripts/install-oss-cad-suite.sh --version "${OSS_CAD_SUITE_VERSION}"
    export PATH="${HOME}/.local/oss-cad-suite/current/oss-cad-suite/bin:${PATH}"
elif fpga_tools_are_qualified; then
    printf '\nQualified FPGA tools already available on PATH; reusing them.\n'
else
    printf '\nQualified FPGA tools are missing or incompatible; installing OSS CAD Suite %s.\n' \
        "${OSS_CAD_SUITE_VERSION}"
    ./scripts/install-oss-cad-suite.sh --version "${OSS_CAD_SUITE_VERSION}"
    export PATH="${HOME}/.local/oss-cad-suite/current/oss-cad-suite/bin:${PATH}"
fi

hash -r
yosys -V
ecppack --version
nextpnr-ecp5 --version

OPENOCD_INSTALLED_NOW=0
if command -v openocd >/dev/null 2>&1; then
    printf '\nExisting native OpenOCD found; reusing it:\n'
    openocd --version
elif (( IS_WSL == 1 )) && [[ -f ./bin/openocd.exe ]]; then
    printf '\nBundled Windows OpenOCD is available for WSL; native OpenOCD installation skipped.\n'
else
    printf '\nOpenOCD is unavailable; installing the Ubuntu package.\n'
    ensure_sudo_keepalive
    apt_get update
    apt_get install -y openocd
    OPENOCD_INSTALLED_NOW=1
    hash -r
    openocd --version
fi

printf '\nUse ./scripts/start-openocd.sh to select the supported OpenOCD/config path.\n'

if (( IS_WSL == 1 )); then
    if [[ -f ./bin/openocd.exe ]]; then
        printf '%s\n' \
            'Bundled Windows xPack OpenOCD is also available in ./bin/openocd.exe.'
    fi
elif (( OPENOCD_INSTALLED_NOW == 1 )); then
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

printf '\nFull install complete.\n\n'
if (( RISCV_XPACK_WAS_NEEDED == 1 )); then
    printf '%s\n' \
        'The xPack fallback installer updated ~/.bashrc, but this script cannot change the' \
        'environment of the shell that launched it.' \
        'Before building from that existing shell, run:' \
        '' \
        '    source ~/.bashrc' \
        '    hash -r'
else
    printf '%s\n' 'Existing compatible RISC-V toolchain was reused; no xPack PATH change is needed.'
fi
