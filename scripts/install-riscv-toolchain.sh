#!/usr/bin/env bash

set -euo pipefail

# Verify this script against the recorded inventory without blocking normal execution.
"$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/inventory.sh" \
    --check-file "${BASH_SOURCE[0]}" || true

# Keep this package release aligned with the FPGA GitHub workflows.
XPACK_VERSION="15.2.0-1"
EXPECTED_GCC_VERSION="15.2.0"
XPACK_BASE_URL="https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/download/v${XPACK_VERSION}"

INSTALL_ROOT="${HOME}/.local/xPacks/riscv-none-elf-gcc"
INSTALL_DIR="${INSTALL_ROOT}/xpack-riscv-none-elf-gcc-${XPACK_VERSION}"
CURRENT_LINK="${INSTALL_ROOT}/current"

case "$(uname -m)" in
    x86_64)
        PLATFORM="linux-x64"
        SHA256="aaaa8060c914851a3e5ee1ba82cc3d6f80972f90638a05c6e823a37557a33758"
        ;;
    aarch64|arm64)
        PLATFORM="linux-arm64"
        SHA256="4e60e2a54c16385e4e2476d08240f857495d5a61609d97e1ee49f72875a6ec1e"
        ;;
    *)
        printf 'ERROR: Unsupported architecture: %s\n' "$(uname -m)" >&2
        exit 1
        ;;
esac

ARCHIVE="xpack-riscv-none-elf-gcc-${XPACK_VERSION}-${PLATFORM}.tar.gz"
URL="${XPACK_BASE_URL}/${ARCHIVE}"

compiler_version()
{
    local gcc="$1"
    "${gcc}" -dumpfullversion -dumpversion 2>/dev/null || true
}

CURRENT_GCC="$(command -v riscv-none-elf-gcc 2>/dev/null || true)"
CURRENT_GCC_VERSION=""
if [[ -n "${CURRENT_GCC}" ]]; then
    CURRENT_GCC_VERSION="$(compiler_version "${CURRENT_GCC}")"
fi

printf '\n'
printf 'RISC-V toolchain installer\n'
printf '%s\n' '--------------------------'
printf 'Desired xPack: %s\n' "${XPACK_VERSION}"
printf 'Desired GCC:   %s\n' "${EXPECTED_GCC_VERSION}"
printf 'Platform:      %s\n' "${PLATFORM}"
printf 'Install path:  %s\n' "${INSTALL_DIR}"
printf '\n'

if [[ -n "${CURRENT_GCC}" ]]; then
    printf 'Current PATH compiler:\n'
    printf '  Binary:  %s\n' "${CURRENT_GCC}"
    printf '  GCC:     %s\n' "${CURRENT_GCC_VERSION:-unknown}"
    "${CURRENT_GCC}" --version | head -n 1 || true
    printf '\n'
else
    printf 'Current PATH compiler: not found\n\n'
fi

MANAGED_GCC="${INSTALL_DIR}/bin/riscv-none-elf-gcc"
MANAGED_GCC_VERSION=""
if [[ -x "${MANAGED_GCC}" ]]; then
    MANAGED_GCC_VERSION="$(compiler_version "${MANAGED_GCC}")"
fi

if [[ "${MANAGED_GCC_VERSION}" == "${EXPECTED_GCC_VERSION}" ]]; then
    printf 'Exact xPack package directory is already installed; reusing it.\n'
elif [[ -e "${INSTALL_DIR}" ]]; then
    printf 'Existing managed xPack directory is incomplete or has the wrong GCC version.\n'
    printf 'Found GCC: %s; expected: %s. Reinstalling.\n\n' \
        "${MANAGED_GCC_VERSION:-unknown}" "${EXPECTED_GCC_VERSION}"
    rm -rf -- "${INSTALL_DIR}"
fi

if [[ ! -x "${MANAGED_GCC}" ]]; then
    if [[ -n "${CURRENT_GCC}" && "${CURRENT_GCC_VERSION}" == "${EXPECTED_GCC_VERSION}" ]]; then
        printf '%s\n' \
            'The compiler on PATH has the desired GCC version, but its exact xPack' \
            "package release cannot be verified as ${XPACK_VERSION}. Installing the" \
            'managed pinned xPack release so the local toolchain exactly matches CI.'
        printf '\n'
    elif [[ -n "${CURRENT_GCC}" ]]; then
        printf 'PATH compiler does not match desired GCC %s; installing pinned xPack.\n\n' \
            "${EXPECTED_GCC_VERSION}"
    fi

    missing_download_tools=0
    for command_name in curl sha256sum tar; do
        if ! command -v "${command_name}" >/dev/null 2>&1; then
            missing_download_tools=1
        fi
    done

    if ((missing_download_tools == 1)); then
        if ! command -v apt-get >/dev/null 2>&1; then
            printf 'ERROR: curl, sha256sum, and tar are required.\n' >&2
            exit 1
        fi
        printf 'Installing required Ubuntu packages...\n'
        sudo apt-get update
        sudo apt-get install -y \
            ca-certificates \
            coreutils \
            curl \
            tar
    fi

    mkdir -p "${INSTALL_ROOT}"

    # Keep the download on the same filesystem as the managed installation.
    # Some Linux systems mount /tmp as a small tmpfs, which is too small for
    # large toolchain archives even when the home filesystem has ample space.
    TMP_DIR="$(mktemp -d "${INSTALL_ROOT}/.install-tmp.XXXXXX")"
    trap 'rm -rf "${TMP_DIR}"' EXIT

    printf '\nDownloading:\n  %s\n\n' "${URL}"

    curl \
        --fail \
        --location \
        --retry 3 \
        --output "${TMP_DIR}/${ARCHIVE}" \
        "${URL}"

    printf 'Verifying SHA-256 checksum...\n'
    printf '%s  %s\n' \
        "${SHA256}" \
        "${TMP_DIR}/${ARCHIVE}" |
        sha256sum --check -

    printf '\nExtracting toolchain...\n'
    tar \
        --extract \
        --gzip \
        --file "${TMP_DIR}/${ARCHIVE}" \
        --directory "${INSTALL_ROOT}"

    if [[ ! -x "${MANAGED_GCC}" ]]; then
        printf 'ERROR: Toolchain installation failed.\n' >&2
        exit 1
    fi

    MANAGED_GCC_VERSION="$(compiler_version "${MANAGED_GCC}")"
    if [[ "${MANAGED_GCC_VERSION}" != "${EXPECTED_GCC_VERSION}" ]]; then
        printf 'ERROR: Installed GCC reports %s; expected %s.\n' \
            "${MANAGED_GCC_VERSION:-unknown}" "${EXPECTED_GCC_VERSION}" >&2
        exit 1
    fi
fi

ln -sfn \
    "xpack-riscv-none-elf-gcc-${XPACK_VERSION}" \
    "${CURRENT_LINK}"

# Keep $HOME and $PATH literal for expansion when the shell startup file is sourced.
# shellcheck disable=SC2016
PATH_LINE='export PATH="$HOME/.local/xPacks/riscv-none-elf-gcc/current/bin:$PATH"'

if ! grep -Fqx "${PATH_LINE}" "${HOME}/.bashrc" 2>/dev/null; then
    printf '\n# xPack RISC-V GCC toolchain\n%s\n' "${PATH_LINE}" >> "${HOME}/.bashrc"
    printf 'Added RISC-V toolchain to ~/.bashrc\n'
fi

export PATH="${CURRENT_LINK}/bin:${PATH}"
hash -r

ACTIVE_GCC_VERSION="$(compiler_version "$(command -v riscv-none-elf-gcc)")"
if [[ "${ACTIVE_GCC_VERSION}" != "${EXPECTED_GCC_VERSION}" ]]; then
    printf 'ERROR: Active RISC-V GCC reports %s; expected %s.\n' \
        "${ACTIVE_GCC_VERSION:-unknown}" "${EXPECTED_GCC_VERSION}" >&2
    exit 1
fi

printf '\nInstalled successfully:\n\n'
riscv-none-elf-gcc --version
printf '\n'
riscv-none-elf-gdb --version | head -n 1
printf '\n'
printf 'xPack release:  %s\n' "${XPACK_VERSION}"
printf 'Toolchain path:\n  %s\n' "${CURRENT_LINK}/bin"
printf '\n'
printf 'For new terminals, PATH is configured automatically.\n'
printf 'For the current terminal after this script finishes, run:\n\n'
printf '  source ~/.bashrc\n\n'
