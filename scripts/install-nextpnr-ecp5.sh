#!/usr/bin/env bash
#
# Install Hazard3-Doom nextpnr-ecp5/Project Trellis tools. OSS CAD Suite is
# the default; the existing pinned source build remains available with
# --from-source.
#
# Intended location:
#   <workspace>/hazard3-doom/scripts/install-nextpnr-ecp5.sh
#
# The script clones sources into the parent workspace:
#   <workspace>/prjtrellis
#   <workspace>/nextpnr
#
# Reference revisions:
#   Project Trellis 1.4-76-g73bd411
#   nextpnr-0.10-95-gddc6c8c8
#
# Usage:
#   ./scripts/install-nextpnr-ecp5.sh
#   ./scripts/install-nextpnr-ecp5.sh --oss-cad-suite-version 2026-09-14
#   ./scripts/install-nextpnr-ecp5.sh --from-source
#   ./scripts/install-nextpnr-ecp5.sh --from-source --jobs 2
#   ./scripts/install-nextpnr-ecp5.sh --from-source --workspace /path/to/workspace
#   ./scripts/install-nextpnr-ecp5.sh --from-source --skip-packages
#

set -euo pipefail

# Verify this script against the recorded inventory without blocking normal execution.
"$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/inventory.sh" \
    --check-file "${BASH_SOURCE[0]}" || true

NEXTPNR_REPOSITORY="https://github.com/YosysHQ/nextpnr.git"
NEXTPNR_COMMIT="ddc6c8c8"
EXPECTED_NEXTPNR_VERSION="nextpnr-0.10-95-gddc6c8c8"

PRJTRELLIS_REPOSITORY="https://github.com/YosysHQ/prjtrellis.git"
PRJTRELLIS_COMMIT="73bd411"
EXPECTED_TRELLIS_VERSION="1.4-76-g73bd411"

INSTALL_PREFIX="/usr/local"
NEXTPNR_BUILD_DIR_NAME="build-hazard3-ecp5"

DEFAULT_OSS_CAD_SUITE_VERSION="2026-07-20"
OSS_CAD_SUITE_VERSION="${OSS_CAD_SUITE_VERSION:-${DEFAULT_OSS_CAD_SUITE_VERSION}}"
INSTALL_METHOD="release"

WORKSPACE_DIR=""
JOBS=2
SKIP_PACKAGES=0

usage() {
    cat <<'USAGE'
Usage:
    install-nextpnr-ecp5.sh [options]

Options:
    --oss-cad-suite-version VERSION
                       OSS CAD Suite release. Default: 2026-07-20.
    --from-source      Build the existing pinned nextpnr/Trellis revisions.
    --workspace DIR    Source mode only. Parent workspace.
    --jobs N           Source mode only. Parallel build jobs. Default: 2.
    --skip-packages    Do not install required Ubuntu/Debian packages.
    -h, --help         Show this help.

Source-mode versions:
    Project Trellis 1.4-76-g73bd411
    nextpnr-0.10-95-gddc6c8c8
USAGE
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

version_ge() {
    printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

while (($# > 0)); do
    case "$1" in
        --oss-cad-suite-version)
            (($# >= 2)) || die "--oss-cad-suite-version requires a release tag"
            OSS_CAD_SUITE_VERSION="$2"
            shift 2
            ;;
        --from-source)
            INSTALL_METHOD="source"
            shift
            ;;
        --workspace)
            (($# >= 2)) || die "--workspace requires a directory"
            WORKSPACE_DIR="$2"
            shift 2
            ;;
        --jobs)
            (($# >= 2)) || die "--jobs requires a number"
            [[ "$2" =~ ^[1-9][0-9]*$ ]] || die "--jobs must be a positive integer"
            JOBS="$2"
            shift 2
            ;;
        --skip-packages)
            SKIP_PACKAGES=1
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

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

if [[ "${INSTALL_METHOD}" == "release" ]]; then
    args=(--version "${OSS_CAD_SUITE_VERSION}")
    if ((SKIP_PACKAGES == 1)); then
        args+=(--skip-packages)
    fi
    exec "${SCRIPT_DIR}/install-oss-cad-suite.sh" "${args[@]}"
fi

printf 'Source build selected for Project Trellis and nextpnr-ecp5.\n\n'

if [[ -z "${WORKSPACE_DIR}" ]]; then
    PROJECT_ROOT="$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel 2>/dev/null)" ||
        die "cannot determine Hazard3-Doom repository; use --workspace DIR"
    WORKSPACE_DIR="$(dirname -- "${PROJECT_ROOT}")"
fi

mkdir -p "${WORKSPACE_DIR}"
WORKSPACE_DIR="$(cd -- "${WORKSPACE_DIR}" && pwd -P)"

NEXTPNR_DIR="${WORKSPACE_DIR}/nextpnr"
PRJTRELLIS_DIR="${WORKSPACE_DIR}/prjtrellis"
NEXTPNR_BUILD_DIR="${NEXTPNR_DIR}/${NEXTPNR_BUILD_DIR_NAME}"

printf 'Workspace:          %s\n' "${WORKSPACE_DIR}"
printf 'Project Trellis:    %s\n' "${PRJTRELLIS_DIR}"
printf 'nextpnr source:     %s\n' "${NEXTPNR_DIR}"
printf 'nextpnr build:      %s\n' "${NEXTPNR_BUILD_DIR}"
printf 'Install prefix:     %s\n' "${INSTALL_PREFIX}"
printf 'Required Trellis:   %s (%s)\n' \
    "${EXPECTED_TRELLIS_VERSION}" "${PRJTRELLIS_COMMIT}"
printf 'Required nextpnr:   %s (%s)\n' \
    "${EXPECTED_NEXTPNR_VERSION}" "${NEXTPNR_COMMIT}"
printf 'Build jobs:         %s\n\n' "${JOBS}"

INSTALLED_TRELLIS_BINARY="$(command -v ecppack 2>/dev/null || true)"
INSTALLED_TRELLIS_OUTPUT=""
if [[ -n "${INSTALLED_TRELLIS_BINARY}" ]]; then
    INSTALLED_TRELLIS_OUTPUT="$(
        "${INSTALLED_TRELLIS_BINARY}" --version 2>&1 || true
    )"
fi

INSTALLED_NEXTPNR_BINARY="$(command -v nextpnr-ecp5 2>/dev/null || true)"
INSTALLED_NEXTPNR_OUTPUT=""
if [[ -n "${INSTALLED_NEXTPNR_BINARY}" ]]; then
    INSTALLED_NEXTPNR_OUTPUT="$(
        "${INSTALLED_NEXTPNR_BINARY}" --version 2>&1 || true
    )"
fi

if [[ "${INSTALLED_TRELLIS_OUTPUT}" == *"Project Trellis ecppack Version ${EXPECTED_TRELLIS_VERSION}"* &&
      "${INSTALLED_NEXTPNR_OUTPUT}" == *"${EXPECTED_NEXTPNR_VERSION}"* ]]; then
    printf 'Project Trellis %s is already installed; reusing it.\n' \
        "${EXPECTED_TRELLIS_VERSION}"
    printf 'nextpnr-ecp5 %s is already installed; reusing it.\n' \
        "${EXPECTED_NEXTPNR_VERSION}"
    exit 0
fi

if ((SKIP_PACKAGES == 0)) && command -v apt-get >/dev/null 2>&1; then
    printf 'Installing build dependencies...\n'
    sudo apt-get -o Dpkg::Use-Pty=0 update
    sudo apt-get -o Dpkg::Use-Pty=0 install -y \
        build-essential \
        cmake \
        git \
        libboost-all-dev \
        libeigen3-dev \
        python3 \
        python3-dev
    printf '\n'
fi

for command_name in git cmake python3 sha256sum awk grep sort c++; do
    command -v "${command_name}" >/dev/null 2>&1 ||
        die "required command not found: ${command_name}"
done

CMAKE_VERSION="$(cmake --version | awk 'NR == 1 {print $3}')"
version_ge "${CMAKE_VERSION}" "3.25" ||
    die "nextpnr requires CMake 3.25 or newer; found ${CMAKE_VERSION}"

printf 'CMake:              %s\n' "${CMAKE_VERSION}"
printf 'C++ compiler:       %s\n\n' "$(c++ --version | head -n 1)"

ensure_clean_tracked_tree() {
    local repo_dir="$1"
    local repo_name="$2"

    if [[ -n "$(git -C "${repo_dir}" status --porcelain --untracked-files=no)" ]]; then
        die "${repo_name} has tracked local changes; refusing to change revisions: ${repo_dir}"
    fi
}

prepare_repo() {
    local repo_dir="$1"
    local repo_name="$2"
    local repository="$3"
    local commit="$4"

    if [[ ! -d "${repo_dir}/.git" ]]; then
        if [[ -e "${repo_dir}" ]]; then
            die "path exists but is not a Git repository: ${repo_dir}"
        fi
        git clone --recursive "${repository}" "${repo_dir}"
    else
        ensure_clean_tracked_tree "${repo_dir}" "${repo_name}"
    fi

    git -C "${repo_dir}" fetch --tags origin
    git -C "${repo_dir}" cat-file -e "${commit}^{commit}" 2>/dev/null ||
        die "${repo_name} commit not found after fetch: ${commit}"

    git -C "${repo_dir}" switch --detach "${commit}"
    git -C "${repo_dir}" submodule sync --recursive
    git -C "${repo_dir}" submodule update --init --recursive
}

trellis_installed_version() {
    local ecppack=""

    ecppack="$(command -v ecppack 2>/dev/null || true)"
    if [[ -z "${ecppack}" || ! -x "${ecppack}" ]]; then
        return 1
    fi

    "${ecppack}" --version 2>&1 | awk '/Project Trellis ecppack Version/ {print $NF; exit}'
}

printf 'Preparing Project Trellis source...\n'
prepare_repo \
    "${PRJTRELLIS_DIR}" \
    "prjtrellis" \
    "${PRJTRELLIS_REPOSITORY}" \
    "${PRJTRELLIS_COMMIT}"

TRELLIS_SHORT_COMMIT="$(git -C "${PRJTRELLIS_DIR}" rev-parse --short=7 HEAD)"
[[ "${TRELLIS_SHORT_COMMIT}" == "${PRJTRELLIS_COMMIT}" ]] ||
    die "checked out Trellis ${TRELLIS_SHORT_COMMIT}, expected ${PRJTRELLIS_COMMIT}"

TRELLIS_DESCRIBE="$(git -C "${PRJTRELLIS_DIR}" describe --tags --always)"
[[ "${TRELLIS_DESCRIBE}" == "${EXPECTED_TRELLIS_VERSION}" ]] ||
    die "Trellis source reports ${TRELLIS_DESCRIBE}, expected ${EXPECTED_TRELLIS_VERSION}"

INSTALLED_TRELLIS_VERSION="$(trellis_installed_version || true)"

if [[ "${INSTALLED_TRELLIS_VERSION}" == "${EXPECTED_TRELLIS_VERSION}" ]]; then
    printf 'Project Trellis %s is already installed; reusing it.\n\n' \
        "${EXPECTED_TRELLIS_VERSION}"
else
    if [[ -n "${INSTALLED_TRELLIS_VERSION}" ]]; then
        printf 'Replacing Project Trellis %s with %s...\n' \
            "${INSTALLED_TRELLIS_VERSION}" "${EXPECTED_TRELLIS_VERSION}"
    else
        printf 'Installing Project Trellis %s...\n' "${EXPECTED_TRELLIS_VERSION}"
    fi

    TRELLIS_BUILD_DIR="${PRJTRELLIS_DIR}/libtrellis"

    # Project Trellis expects an in-tree libtrellis build. Remove CMake's
    # generated build state so changing revisions cannot reuse old objects.
    rm -rf \
        "${TRELLIS_BUILD_DIR}/CMakeCache.txt" \
        "${TRELLIS_BUILD_DIR}/CMakeFiles"

    cmake \
        -S "${TRELLIS_BUILD_DIR}" \
        -B "${TRELLIS_BUILD_DIR}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}"

    cmake --build "${TRELLIS_BUILD_DIR}" --parallel "${JOBS}"

    # Remove installed database/Python module directories before installing
    # the pinned revision so files from a newer Trellis cannot remain behind.
    sudo rm -rf \
        "${INSTALL_PREFIX}/share/trellis" \
        "${INSTALL_PREFIX}/lib/trellis"

    sudo cmake --install "${TRELLIS_BUILD_DIR}"
    sudo ldconfig

    INSTALLED_TRELLIS_VERSION="$(trellis_installed_version || true)"
    [[ "${INSTALLED_TRELLIS_VERSION}" == "${EXPECTED_TRELLIS_VERSION}" ]] ||
        die "installed Trellis reports ${INSTALLED_TRELLIS_VERSION:-unknown}, expected ${EXPECTED_TRELLIS_VERSION}"

    printf 'Project Trellis installed successfully.\n\n'
fi

printf 'Preparing nextpnr source...\n'
prepare_repo \
    "${NEXTPNR_DIR}" \
    "nextpnr" \
    "${NEXTPNR_REPOSITORY}" \
    "${NEXTPNR_COMMIT}"

NEXTPNR_SHORT_COMMIT="$(git -C "${NEXTPNR_DIR}" rev-parse --short=8 HEAD)"
[[ "${NEXTPNR_SHORT_COMMIT}" == "${NEXTPNR_COMMIT}" ]] ||
    die "checked out nextpnr ${NEXTPNR_SHORT_COMMIT}, expected ${NEXTPNR_COMMIT}"

printf '\nBuilding nextpnr-ecp5...\n'
rm -rf "${NEXTPNR_BUILD_DIR}"

cmake \
    -S "${NEXTPNR_DIR}" \
    -B "${NEXTPNR_BUILD_DIR}" \
    -DARCH=ecp5 \
    -DTRELLIS_INSTALL_PREFIX="${INSTALL_PREFIX}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}"

cmake --build "${NEXTPNR_BUILD_DIR}" --parallel "${JOBS}"

BUILT_BINARY="${NEXTPNR_BUILD_DIR}/nextpnr-ecp5"
[[ -x "${BUILT_BINARY}" ]] ||
    die "build did not produce: ${BUILT_BINARY}"

BUILT_VERSION="$("${BUILT_BINARY}" --version 2>&1)"
printf '\nBuilt version:\n%s\n' "${BUILT_VERSION}"

[[ "${BUILT_VERSION}" == *"${EXPECTED_NEXTPNR_VERSION}"* ]] ||
    die "built binary does not report ${EXPECTED_NEXTPNR_VERSION}"

printf '\nInstalling nextpnr-ecp5...\n'
sudo cmake --install "${NEXTPNR_BUILD_DIR}"
sudo ldconfig

INSTALLED_BINARY="${INSTALL_PREFIX}/bin/nextpnr-ecp5"
[[ -x "${INSTALLED_BINARY}" ]] ||
    die "installed binary not found: ${INSTALLED_BINARY}"

INSTALLED_VERSION="$("${INSTALLED_BINARY}" --version 2>&1)"
[[ "${INSTALLED_VERSION}" == *"${EXPECTED_NEXTPNR_VERSION}"* ]] ||
    die "installed binary does not report ${EXPECTED_NEXTPNR_VERSION}"

BUILT_SHA256="$(sha256sum "${BUILT_BINARY}" | awk '{print $1}')"
INSTALLED_SHA256="$(sha256sum "${INSTALLED_BINARY}" | awk '{print $1}')"
[[ "${BUILT_SHA256}" == "${INSTALLED_SHA256}" ]] ||
    die "installed nextpnr-ecp5 checksum differs from the built binary"

printf '\nInstallation complete.\n'
printf 'Trellis source:  %s\n' "${PRJTRELLIS_DIR}"
printf 'Trellis commit:  %s\n' "$(git -C "${PRJTRELLIS_DIR}" rev-parse HEAD)"
printf 'Trellis version: %s\n' "${INSTALLED_TRELLIS_VERSION}"
printf 'nextpnr source:  %s\n' "${NEXTPNR_DIR}"
printf 'nextpnr commit:  %s\n' "$(git -C "${NEXTPNR_DIR}" rev-parse HEAD)"
printf 'Binary:          %s\n' "${INSTALLED_BINARY}"
printf 'Version:         %s\n' "${INSTALLED_VERSION}"
printf 'SHA256:          %s\n' "${INSTALLED_SHA256}"
printf '\nRefresh this shell with:\n'
printf '    hash -r\n'
printf '    ecppack --version\n'
printf '    nextpnr-ecp5 --version\n'
