#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
GDB="${GDB:-/opt/riscv/bin/riscv32-unknown-elf-gdb}"
ELF="${1:-${ROOT_DIR}/build/hazard3-boot-monitor.elf}"

# Run shellcheck to ensure this is a good script.
# Specify the executable shell checker you want to use:
MY_SHELLCHECK="shellcheck"

# Check if the executable is available in the PATH
if command -v "$MY_SHELLCHECK" >/dev/null 2>&1; then
    # Run your command here
    shellcheck "$0" || exit 1
else
    echo "$MY_SHELLCHECK is not installed. Please install it if changes to this script have been made."
fi

if [[ ! -x "${GDB}" ]]; then
    echo "Missing RISC-V GDB executable: ${GDB}" >&2
    exit 1
fi

if [[ ! -f "${ELF}" ]]; then
    echo "Missing firmware ELF: ${ELF}" >&2
    echo "Run ${ROOT_DIR}/scripts/build.sh first or use the file in the prebuilt ./bin/ directory." >&2
    exit 1
fi

# The GDB expression $pc must be passed literally rather than expanded by Bash.
# shellcheck disable=SC2016
"${GDB}" \
    --batch \
    --quiet \
    "${ELF}" \
    -ex 'set confirm off' \
    -ex 'set pagination off' \
    -ex 'set remotetimeout 120' \
    -ex 'target extended-remote localhost:3333' \
    -ex 'monitor halt' \
    -ex 'load' \
    -ex 'compare-sections' \
    -ex 'set $pc = _start' \
    -ex 'monitor resume' \
    -ex 'disconnect'
