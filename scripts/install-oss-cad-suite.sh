#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File:        install-oss-cad-suite.sh
# Path:        scripts/install-oss-cad-suite.sh
#
# Project:     Hazard3-Doom
# Purpose:     Install the pinned OSS CAD Suite release used by FPGA CI.
# -----------------------------------------------------------------------------

set -euo pipefail

# Verify this script against the recorded inventory without blocking normal execution.
"$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/inventory.sh" \
    --check-file "${BASH_SOURCE[0]}" || true

DEFAULT_OSS_CAD_SUITE_VERSION="2026-07-20"
OSS_CAD_SUITE_VERSION="${OSS_CAD_SUITE_VERSION:-${DEFAULT_OSS_CAD_SUITE_VERSION}}"
INSTALL_ROOT="${HOME}/.local/oss-cad-suite"
SKIP_PACKAGES=0
MIN_FREE_KIB=$((4 * 1024 * 1024))

usage()
{
    cat <<'USAGE'
Usage:
    install-oss-cad-suite.sh [options]

Options:
    --version VERSION   OSS CAD Suite release tag. Default: 2026-07-20.
    --install-root DIR  Versioned installation root.
                        Default: ~/.local/oss-cad-suite.
    --skip-packages     Do not install curl/CA certificates if missing.
    -h, --help          Show this help.

The default release matches the main FPGA build and seed-sweep workflows.
The ULX4M bootloader workflow currently uses 2026-09-14 and can be matched with:

    ./scripts/install-oss-cad-suite.sh --version 2026-09-14
USAGE
}

die()
{
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

while (($# > 0)); do
    case "$1" in
        --version)
            if (($# < 2)); then
                die "--version requires a release tag"
            fi
            OSS_CAD_SUITE_VERSION="$2"
            shift 2
            ;;
        --install-root)
            if (($# < 2)); then
                die "--install-root requires a directory"
            fi
            INSTALL_ROOT="$2"
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

if [[ ! "${OSS_CAD_SUITE_VERSION}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    die "OSS CAD Suite version must use YYYY-MM-DD format"
fi

case "$(uname -m)" in
    x86_64)
        PLATFORM="linux-x64"
        ;;
    aarch64|arm64)
        PLATFORM="linux-arm64"
        ;;
    *)
        die "unsupported architecture: $(uname -m)"
        ;;
esac

VERSION_STAMP="${OSS_CAD_SUITE_VERSION//-/}"
ARCHIVE="oss-cad-suite-${PLATFORM}-${VERSION_STAMP}.tgz"
URL="https://github.com/YosysHQ/oss-cad-suite-build/releases/download/${OSS_CAD_SUITE_VERSION}/${ARCHIVE}"
INSTALL_DIR="${INSTALL_ROOT}/${OSS_CAD_SUITE_VERSION}"
SUITE_DIR="${INSTALL_DIR}/oss-cad-suite"
CURRENT_LINK="${INSTALL_ROOT}/current"
MANAGED_BIN="${CURRENT_LINK}/oss-cad-suite/bin"

path_tool_info()
{
    local tool="$1"
    local tool_path=""
    local tool_version=""

    tool_path="$(command -v "${tool}" 2>/dev/null || true)"
    if [[ -z "${tool_path}" ]]; then
        printf '  %-14s not found\n' "${tool}:"
        return
    fi

    case "${tool}" in
        yosys)
            tool_version="$("${tool_path}" -V 2>&1 | head -n 1 || true)"
            ;;
        *)
            tool_version="$("${tool_path}" --version 2>&1 | head -n 1 || true)"
            ;;
    esac

    printf '  %-14s %s\n' "${tool}:" "${tool_path}"
    printf '  %-14s %s\n' "version:" "${tool_version:-unknown}"
}

suite_is_complete()
{
    local suite_dir="$1"

    [[ -x "${suite_dir}/bin/yosys" &&
       -x "${suite_dir}/bin/nextpnr-ecp5" &&
       -x "${suite_dir}/bin/ecppack" ]]
}

check_install_space()
{
    local path="$1"
    local available_kib=0
    local available_gib=0

    available_kib="$(df -Pk "${path}" 2>/dev/null | awk 'NR == 2 {print $4}')"
    if [[ ! "${available_kib}" =~ ^[0-9]+$ ]]; then
        die "cannot determine free disk space for ${path}"
    fi

    available_gib=$((available_kib / 1024 / 1024))

    printf 'Temporary workspace: %s\n' "${path}"
    printf 'Available space:     %d GiB\n' "${available_gib}"
    printf 'Required space:      4 GiB minimum\n\n'

    if ((available_kib < MIN_FREE_KIB)); then
        die "at least 4 GiB free is required to download and extract OSS CAD Suite under ${path}"
    fi
}

printf '\nOSS CAD Suite installer\n'
printf '%s\n' '-----------------------'
printf 'Desired release: %s\n' "${OSS_CAD_SUITE_VERSION}"
printf 'Platform:        %s\n' "${PLATFORM}"
printf 'Install path:    %s\n' "${INSTALL_DIR}"
printf '\nTools currently on PATH:\n'
path_tool_info yosys
path_tool_info nextpnr-ecp5
path_tool_info ecppack
printf '\n'

CURRENT_MANAGED_RELEASE=""
if [[ -L "${CURRENT_LINK}" ]]; then
    CURRENT_MANAGED_RELEASE="$(readlink -- "${CURRENT_LINK}" 2>/dev/null || true)"
fi

if [[ "${CURRENT_MANAGED_RELEASE}" == "${OSS_CAD_SUITE_VERSION}" ]] &&
   suite_is_complete "${CURRENT_LINK}/oss-cad-suite"; then
    printf 'Managed OSS CAD Suite comparison: MATCH (%s).\n\n' \
        "${OSS_CAD_SUITE_VERSION}"
elif [[ -n "${CURRENT_MANAGED_RELEASE}" ]]; then
    printf 'Managed OSS CAD Suite comparison: installed %s, desired %s.\n\n' \
        "${CURRENT_MANAGED_RELEASE}" "${OSS_CAD_SUITE_VERSION}"
else
    printf 'Managed OSS CAD Suite comparison: no managed release is active; desired %s.\n\n' \
        "${OSS_CAD_SUITE_VERSION}"
fi

if suite_is_complete "${SUITE_DIR}"; then
    printf 'OSS CAD Suite %s is already installed; reusing it.\n' \
        "${OSS_CAD_SUITE_VERSION}"
else
    if [[ -e "${INSTALL_DIR}" ]]; then
        printf 'Incomplete OSS CAD Suite installation found; replacing:\n  %s\n' \
            "${INSTALL_DIR}"
        rm -rf -- "${INSTALL_DIR}"
    fi

    missing_download_tools=0
    for command_name in curl tar; do
        if ! command -v "${command_name}" >/dev/null 2>&1; then
            missing_download_tools=1
        fi
    done

    if ((missing_download_tools == 1)); then
        if ((SKIP_PACKAGES == 1)); then
            die "curl and tar are required when --skip-packages is used"
        fi
        if ! command -v apt-get >/dev/null 2>&1; then
            die "curl/tar are missing and apt-get is unavailable"
        fi
        sudo apt-get -o Dpkg::Use-Pty=0 update
        sudo apt-get -o Dpkg::Use-Pty=0 install -y ca-certificates curl tar
    fi

    mkdir -p -- "${INSTALL_ROOT}"
    check_install_space "${INSTALL_ROOT}"

    TMP_DIR="$(mktemp -d "${INSTALL_ROOT}/.install-tmp.XXXXXX")"
    trap 'rm -rf "${TMP_DIR}"' EXIT

    printf 'Downloading OSS CAD Suite %s:\n  %s\n\n' \
        "${OSS_CAD_SUITE_VERSION}" "${URL}"
    curl \
        --fail \
        --location \
        --retry 3 \
        --output "${TMP_DIR}/${ARCHIVE}" \
        "${URL}"

    mkdir -p -- "${TMP_DIR}/extract"
    tar \
        --extract \
        --gzip \
        --file "${TMP_DIR}/${ARCHIVE}" \
        --directory "${TMP_DIR}/extract"

    if ! suite_is_complete "${TMP_DIR}/extract/oss-cad-suite"; then
        die "downloaded archive does not contain the expected Yosys/nextpnr ECP5 tools"
    fi

    mkdir -p -- "$(dirname -- "${INSTALL_DIR}")"
    mv -- "${TMP_DIR}/extract" "${INSTALL_DIR}"
fi

ln -sfn -- "${OSS_CAD_SUITE_VERSION}" "${CURRENT_LINK}"

# Keep $HOME and $PATH literal for expansion when the shell startup file is sourced.
# shellcheck disable=SC2016
PATH_LINE='export PATH="$HOME/.local/oss-cad-suite/current/oss-cad-suite/bin:$PATH"'

if [[ "${INSTALL_ROOT}" == "${HOME}/.local/oss-cad-suite" ]]; then
    if ! grep -Fqx "${PATH_LINE}" "${HOME}/.bashrc" 2>/dev/null; then
        printf '\n# Hazard3-Doom pinned OSS CAD Suite\n%s\n' "${PATH_LINE}" >> "${HOME}/.bashrc"
        printf 'Added OSS CAD Suite to ~/.bashrc\n'
    fi
else
    printf 'Custom install root selected; ~/.bashrc was not modified.\n'
fi

export PATH="${MANAGED_BIN}:${PATH}"
hash -r

printf '\nActive OSS CAD Suite release: %s\n' "${OSS_CAD_SUITE_VERSION}"
printf 'Tool directory: %s\n\n' "${MANAGED_BIN}"
yosys -V
nextpnr-ecp5 --version
ecppack --version
printf '\nFor the current terminal after this script finishes, run:\n\n'
printf '  export PATH=%q:%s\n' "${MANAGED_BIN}" "\"\$PATH\""
printf '  hash -r\n\n'
