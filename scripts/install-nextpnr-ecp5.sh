#!/usr/bin/env bash
#
# Build and install the Hazard3-Doom reference nextpnr-ecp5.
#
# Intended location:
#   <workspace>/hazard3-doom/scripts/install-nextpnr-ecp5.sh
#
# The script clones nextpnr into the parent workspace:
#   <workspace>/nextpnr
#
# and installs the exact nextpnr revision used by the reference CI toolchain:
#   nextpnr-0.10-95-gddc6c8c8
#
# If Project Trellis is not already installed under /usr/local, the script
# also clones prjtrellis into the parent workspace and installs libtrellis.
#
# Usage:
#   ./scripts/install-nextpnr-ecp5.sh
#   ./scripts/install-nextpnr-ecp5.sh --workspace /path/to/workspace
#   ./scripts/install-nextpnr-ecp5.sh --skip-packages
#

set -euo pipefail

NEXTPNR_REPOSITORY="https://github.com/YosysHQ/nextpnr.git"
NEXTPNR_COMMIT="ddc6c8c8"
EXPECTED_VERSION="nextpnr-0.10-95-gddc6c8c8"

PRJTRELLIS_REPOSITORY="https://github.com/YosysHQ/prjtrellis.git"

INSTALL_PREFIX="/usr/local"
BUILD_DIR_NAME="build-hazard3-ecp5"

WORKSPACE_DIR=""
SKIP_PACKAGES=0

usage() {
    cat <<'EOF'
Usage:
    install-nextpnr-ecp5.sh [options]

Options:
    --workspace DIR    Workspace containing Hazard3-Doom and nextpnr.
                       Default: parent of the Hazard3-Doom Git repository.
    --skip-packages    Do not install Ubuntu/Debian build dependencies.
    -h, --help         Show this help.

The installed executable is:
    /usr/local/bin/nextpnr-ecp5

Expected version:
    nextpnr-0.10-95-gddc6c8c8
EOF
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

while (($# > 0)); do
    case "$1" in
        --workspace)
            (($# >= 2)) || die "--workspace requires a directory"
            WORKSPACE_DIR="$2"
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

SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
    pwd -P
)"

if [[ -z "${WORKSPACE_DIR}" ]]; then
    PROJECT_ROOT="$(
        git -C "${SCRIPT_DIR}" rev-parse --show-toplevel 2>/dev/null
    )" || die "cannot determine the Hazard3-Doom repository; use --workspace DIR"

    WORKSPACE_DIR="$(dirname -- "${PROJECT_ROOT}")"
fi

mkdir -p "${WORKSPACE_DIR}"
WORKSPACE_DIR="$(
    cd -- "${WORKSPACE_DIR}"
    pwd -P
)"

NEXTPNR_DIR="${WORKSPACE_DIR}/nextpnr"
PRJTRELLIS_DIR="${WORKSPACE_DIR}/prjtrellis"
NEXTPNR_BUILD_DIR="${NEXTPNR_DIR}/${BUILD_DIR_NAME}"

printf 'Workspace:         %s\n' "${WORKSPACE_DIR}"
printf 'nextpnr source:    %s\n' "${NEXTPNR_DIR}"
printf 'nextpnr build:     %s\n' "${NEXTPNR_BUILD_DIR}"
printf 'Install prefix:    %s\n' "${INSTALL_PREFIX}"
printf 'Required nextpnr:  %s (%s)\n\n' \
    "${EXPECTED_VERSION}" "${NEXTPNR_COMMIT}"

if ((SKIP_PACKAGES == 0)); then
    if command -v apt-get >/dev/null 2>&1; then
        printf 'Installing build dependencies...\n'
        sudo apt-get update
        sudo apt-get install -y \
            build-essential \
            cmake \
            git \
            libboost-all-dev \
            libeigen3-dev \
            python3 \
            python3-dev
        printf '\n'
    else
        printf 'NOTE: apt-get not found; assuming build dependencies are installed.\n\n'
    fi
fi

for command_name in git cmake python3 sha256sum awk grep find; do
    command -v "${command_name}" >/dev/null 2>&1 ||
        die "required command not found: ${command_name}"
done

JOBS="$(nproc 2>/dev/null || printf '1')"

trellis_installed() {
    [[ -d "${INSTALL_PREFIX}/share/trellis" ]] &&
        find "${INSTALL_PREFIX}/lib" \
            -maxdepth 3 \
            \( -name 'libtrellis.so' -o -name 'libtrellis.a' \) \
            -print -quit 2>/dev/null |
            grep -q .
}

ensure_clean_tracked_tree() {
    local repo_dir="$1"
    local repo_name="$2"

    if [[ -n "$(git -C "${repo_dir}" status --porcelain --untracked-files=no)" ]]; then
        die "${repo_name} has tracked local changes; refusing to change revisions: ${repo_dir}"
    fi
}

if trellis_installed; then
    printf 'Project Trellis already installed under %s; reusing it.\n\n' \
        "${INSTALL_PREFIX}"
else
    printf 'Project Trellis was not found under %s.\n' "${INSTALL_PREFIX}"
    printf 'Cloning/building Project Trellis in %s...\n' "${PRJTRELLIS_DIR}"

    if [[ ! -d "${PRJTRELLIS_DIR}/.git" ]]; then
        if [[ -e "${PRJTRELLIS_DIR}" ]]; then
            die "path exists but is not a Git repository: ${PRJTRELLIS_DIR}"
        fi

        git clone --recursive \
            "${PRJTRELLIS_REPOSITORY}" \
            "${PRJTRELLIS_DIR}"
    else
        ensure_clean_tracked_tree "${PRJTRELLIS_DIR}" "prjtrellis"
        git -C "${PRJTRELLIS_DIR}" fetch --tags origin
        git -C "${PRJTRELLIS_DIR}" submodule sync --recursive
        git -C "${PRJTRELLIS_DIR}" submodule update --init --recursive
    fi

    (
        cd "${PRJTRELLIS_DIR}/libtrellis"

        cmake \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
            .

        cmake --build . --parallel "${JOBS}"
        sudo cmake --install .
    )

    trellis_installed ||
        die "Project Trellis installation did not produce libtrellis"

    printf 'Project Trellis installed successfully.\n\n'
fi

printf 'Preparing nextpnr source...\n'

if [[ ! -d "${NEXTPNR_DIR}/.git" ]]; then
    if [[ -e "${NEXTPNR_DIR}" ]]; then
        die "path exists but is not a Git repository: ${NEXTPNR_DIR}"
    fi

    git clone --recursive \
        "${NEXTPNR_REPOSITORY}" \
        "${NEXTPNR_DIR}"
else
    ensure_clean_tracked_tree "${NEXTPNR_DIR}" "nextpnr"
fi

git -C "${NEXTPNR_DIR}" fetch --tags origin

if ! git -C "${NEXTPNR_DIR}" cat-file -e "${NEXTPNR_COMMIT}^{commit}" 2>/dev/null; then
    die "nextpnr commit not found after fetch: ${NEXTPNR_COMMIT}"
fi

git -C "${NEXTPNR_DIR}" switch --detach "${NEXTPNR_COMMIT}"
git -C "${NEXTPNR_DIR}" submodule sync --recursive
git -C "${NEXTPNR_DIR}" submodule update --init --recursive

ACTUAL_COMMIT="$(git -C "${NEXTPNR_DIR}" rev-parse --short=8 HEAD)"
[[ "${ACTUAL_COMMIT}" == "${NEXTPNR_COMMIT}" ]] ||
    die "checked out ${ACTUAL_COMMIT}, expected ${NEXTPNR_COMMIT}"

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

if [[ "${BUILT_VERSION}" != *"${EXPECTED_VERSION}"* ]]; then
    die "built binary does not report ${EXPECTED_VERSION}"
fi

printf '\nInstalling nextpnr-ecp5...\n'
sudo cmake --install "${NEXTPNR_BUILD_DIR}"

INSTALLED_BINARY="${INSTALL_PREFIX}/bin/nextpnr-ecp5"
[[ -x "${INSTALLED_BINARY}" ]] ||
    die "installed binary not found: ${INSTALLED_BINARY}"

INSTALLED_VERSION="$("${INSTALLED_BINARY}" --version 2>&1)"

if [[ "${INSTALLED_VERSION}" != *"${EXPECTED_VERSION}"* ]]; then
    die "installed binary does not report ${EXPECTED_VERSION}"
fi

BUILT_SHA256="$(sha256sum "${BUILT_BINARY}" | awk '{print $1}')"
INSTALLED_SHA256="$(sha256sum "${INSTALLED_BINARY}" | awk '{print $1}')"

[[ "${BUILT_SHA256}" == "${INSTALLED_SHA256}" ]] ||
    die "installed nextpnr-ecp5 checksum differs from the built binary"

printf '\nInstallation complete.\n'
printf 'Source:  %s\n' "${NEXTPNR_DIR}"
printf 'Commit:  %s\n' "$(git -C "${NEXTPNR_DIR}" rev-parse HEAD)"
printf 'Binary:  %s\n' "${INSTALLED_BINARY}"
printf 'Version: %s\n' "${INSTALLED_VERSION}"
printf 'SHA256:  %s\n' "${INSTALLED_SHA256}"
printf '\nFor the current shell, refresh command lookup with:\n'
printf '    hash -r\n'
printf '    nextpnr-ecp5 --version\n'
