#!/usr/bin/env bash

set -euo pipefail

XPACK_VERSION="15.2.0-1"
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

printf '\n'
printf 'RISC-V toolchain installer\n'
printf '%s\n' '--------------------------'
printf 'Version:      %s\n' "${XPACK_VERSION}"
printf 'Platform:     %s\n' "${PLATFORM}"
printf 'Install path: %s\n' "${INSTALL_DIR}"
printf '\n'

if [[ -x "${INSTALL_DIR}/bin/riscv-none-elf-gcc" ]]; then
    printf 'Toolchain is already installed.\n'
else
    printf 'Installing required Ubuntu packages...\n'
    sudo apt-get update
    sudo apt-get install -y \
        ca-certificates \
        curl

    mkdir -p "${INSTALL_ROOT}"

    TMP_DIR="$(mktemp -d)"
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

    if [[ ! -x "${INSTALL_DIR}/bin/riscv-none-elf-gcc" ]]; then
        printf 'ERROR: Toolchain installation failed.\n' >&2
        exit 1
    fi
fi

ln -sfn \
    "xpack-riscv-none-elf-gcc-${XPACK_VERSION}" \
    "${CURRENT_LINK}"

PATH_LINE='export PATH="$HOME/.local/xPacks/riscv-none-elf-gcc/current/bin:$PATH"'

if ! grep -Fqx "${PATH_LINE}" "${HOME}/.bashrc" 2>/dev/null; then
    printf '\n# xPack RISC-V GCC toolchain\n%s\n' "${PATH_LINE}" >> "${HOME}/.bashrc"
    printf 'Added RISC-V toolchain to ~/.bashrc\n'
fi

export PATH="${CURRENT_LINK}/bin:${PATH}"

printf '\nInstalled successfully:\n\n'
riscv-none-elf-gcc --version
printf '\n'
riscv-none-elf-gdb --version | head -n 1
printf '\n'
printf 'Toolchain path:\n  %s\n' "${CURRENT_LINK}/bin"
printf '\n'
printf 'For new terminals, PATH is configured automatically.\n'
printf 'For the current terminal after this script finishes, run:\n\n'
printf '  source ~/.bashrc\n\n'