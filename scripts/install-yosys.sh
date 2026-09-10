#!/usr/bin/env bash
#
# Build and install the Hazard3-Doom reference Yosys 0.67.
#
# Intended location:
#   <workspace>/hazard3-doom/scripts/install-yosys.sh
#
# Clones Yosys into the parent workspace:
#   <workspace>/yosys
#
# Exact revision:
#   2d1509d1bcb8df0723f6790057e3b1d21c876683
#
# Yosys 0.67 uses CMake, not the legacy Makefile build.
#
# Usage:
#   ./scripts/install-yosys.sh
#   ./scripts/install-yosys.sh --jobs 2
#   ./scripts/install-yosys.sh --workspace /path/to/workspace
#   ./scripts/install-yosys.sh --skip-packages
#

set -euo pipefail

YOSYS_REPOSITORY="https://github.com/YosysHQ/yosys.git"
YOSYS_COMMIT="2d1509d1bcb8df0723f6790057e3b1d21c876683"
EXPECTED_VERSION_FRAGMENT="Yosys 0.67"
EXPECTED_COMMIT_FRAGMENT="2d1509d1b"

INSTALL_PREFIX="/usr/local"
BUILD_DIR_NAME="build-hazard3"

WORKSPACE_DIR=""
JOBS=2
SKIP_PACKAGES=0

usage() {
    cat <<'EOF'
Usage:
    install-yosys.sh [options]

Options:
    --workspace DIR    Parent workspace. Default: parent of Hazard3-Doom repo.
    --jobs N           Parallel build jobs. Default: 2.
    --skip-packages    Do not install Ubuntu/Debian build dependencies.
    -h, --help         Show this help.
EOF
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

if [[ -z "${WORKSPACE_DIR}" ]]; then
    PROJECT_ROOT="$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel 2>/dev/null)" ||
        die "cannot determine Hazard3-Doom repository; use --workspace DIR"
    WORKSPACE_DIR="$(dirname -- "${PROJECT_ROOT}")"
fi

mkdir -p "${WORKSPACE_DIR}"
WORKSPACE_DIR="$(cd -- "${WORKSPACE_DIR}" && pwd -P)"

YOSYS_DIR="${WORKSPACE_DIR}/yosys"
YOSYS_BUILD_DIR="${YOSYS_DIR}/${BUILD_DIR_NAME}"

printf 'Workspace:       %s\n' "${WORKSPACE_DIR}"
printf 'Yosys source:    %s\n' "${YOSYS_DIR}"
printf 'Yosys build:     %s\n' "${YOSYS_BUILD_DIR}"
printf 'Install prefix:  %s\n' "${INSTALL_PREFIX}"
printf 'Required commit: %s\n' "${YOSYS_COMMIT}"
printf 'Build jobs:      %s\n\n' "${JOBS}"

if ((SKIP_PACKAGES == 0)) && command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y \
        bison \
        flex \
        gawk \
        git \
        graphviz \
        libffi-dev \
        libfl-dev \
        libreadline-dev \
        ninja-build \
        pkg-config \
        python3 \
        tcl-dev \
        xdot \
        zlib1g-dev
fi

for command_name in git cmake ninja python3 bison flex awk grep sha256sum sort c++; do
    command -v "${command_name}" >/dev/null 2>&1 ||
        die "required command not found: ${command_name}"
done

CMAKE_VERSION="$(cmake --version | awk 'NR == 1 {print $3}')"
version_ge "${CMAKE_VERSION}" "3.28" ||
    die "Yosys 0.67 requires CMake 3.28 or newer; found ${CMAKE_VERSION}"

printf 'CMake:           %s\n' "${CMAKE_VERSION}"
printf 'C++ compiler:    %s\n\n' "$(c++ --version | head -n 1)"

ensure_clean_tracked_tree() {
    local repo_dir="$1"
    local repo_name="$2"
    if [[ -n "$(git -C "${repo_dir}" status --porcelain --untracked-files=no)" ]]; then
        die "${repo_name} has tracked local changes; refusing to change revisions: ${repo_dir}"
    fi
}

if [[ ! -d "${YOSYS_DIR}/.git" ]]; then
    [[ ! -e "${YOSYS_DIR}" ]] ||
        die "path exists but is not a Git repository: ${YOSYS_DIR}"
    git clone --recursive "${YOSYS_REPOSITORY}" "${YOSYS_DIR}"
else
    ensure_clean_tracked_tree "${YOSYS_DIR}" "yosys"
fi

git -C "${YOSYS_DIR}" fetch --tags origin
git -C "${YOSYS_DIR}" cat-file -e "${YOSYS_COMMIT}^{commit}" 2>/dev/null ||
    die "Yosys commit not found after fetch: ${YOSYS_COMMIT}"

git -C "${YOSYS_DIR}" switch --detach "${YOSYS_COMMIT}"
git -C "${YOSYS_DIR}" submodule sync --recursive
git -C "${YOSYS_DIR}" submodule update --init --recursive

ACTUAL_COMMIT="$(git -C "${YOSYS_DIR}" rev-parse HEAD)"
[[ "${ACTUAL_COMMIT}" == "${YOSYS_COMMIT}" ]] ||
    die "checked out ${ACTUAL_COMMIT}, expected ${YOSYS_COMMIT}"

rm -rf "${YOSYS_BUILD_DIR}"

cmake \
    -S "${YOSYS_DIR}" \
    -B "${YOSYS_BUILD_DIR}" \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}"

cmake --build "${YOSYS_BUILD_DIR}" --parallel "${JOBS}"

BUILT_BINARY="${YOSYS_BUILD_DIR}/yosys"
[[ -x "${BUILT_BINARY}" ]] || die "build did not produce: ${BUILT_BINARY}"

BUILT_VERSION="$("${BUILT_BINARY}" -V 2>&1)"
printf '\nBuilt version:\n%s\n' "${BUILT_VERSION}"

[[ "${BUILT_VERSION}" == *"${EXPECTED_VERSION_FRAGMENT}"* ]] ||
    die "built Yosys does not report ${EXPECTED_VERSION_FRAGMENT}"
[[ "${BUILT_VERSION}" == *"${EXPECTED_COMMIT_FRAGMENT}"* ]] ||
    die "built Yosys does not report commit ${EXPECTED_COMMIT_FRAGMENT}"

sudo cmake --install "${YOSYS_BUILD_DIR}"

INSTALLED_BINARY="${INSTALL_PREFIX}/bin/yosys"
[[ -x "${INSTALLED_BINARY}" ]] || die "installed binary not found: ${INSTALLED_BINARY}"

INSTALLED_VERSION="$("${INSTALLED_BINARY}" -V 2>&1)"
[[ "${INSTALLED_VERSION}" == *"${EXPECTED_VERSION_FRAGMENT}"* ]] ||
    die "installed Yosys does not report ${EXPECTED_VERSION_FRAGMENT}"
[[ "${INSTALLED_VERSION}" == *"${EXPECTED_COMMIT_FRAGMENT}"* ]] ||
    die "installed Yosys does not report commit ${EXPECTED_COMMIT_FRAGMENT}"

BUILT_SHA256="$(sha256sum "${BUILT_BINARY}" | awk '{print $1}')"
INSTALLED_SHA256="$(sha256sum "${INSTALLED_BINARY}" | awk '{print $1}')"
[[ "${BUILT_SHA256}" == "${INSTALLED_SHA256}" ]] ||
    die "installed Yosys checksum differs from built binary"

printf '\nInstallation complete.\n'
printf 'Source:  %s\n' "${YOSYS_DIR}"
printf 'Commit:  %s\n' "${ACTUAL_COMMIT}"
printf 'Binary:  %s\n' "${INSTALLED_BINARY}"
printf 'Version: %s\n' "${INSTALLED_VERSION}"
printf 'SHA256:  %s\n' "${INSTALLED_SHA256}"
printf '\nRefresh this shell with:\n'
printf '    hash -r\n'
printf '    yosys -V\n'
