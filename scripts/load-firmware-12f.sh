#!/bin/bash
# Load the ULX3S 12F SDRAM-resident monitor after FPGA configuration.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
ELF="${1:-${ROOT_DIR}/build/ulx3s-12f/monitor/hazard3-boot-monitor.elf}"

# Run ShellCheck to ensure this is a good script.
# Specify the executable shell checker you want to use:
MY_SHELLCHECK="shellcheck"

# Check if the executable is available in the PATH.
if command -v "${MY_SHELLCHECK}" >/dev/null 2>&1; then
    "${MY_SHELLCHECK}" -x "${BASH_SOURCE[0]}" >&2 || exit 1
else
    printf '%s\n' \
        "${MY_SHELLCHECK} is not installed. Please install it if changes to this script have been made." \
        >&2
fi

echo "Calling ${SCRIPT_DIR}/load-firmware.sh with .elf file parameter:"
ls -al "${ELF}"
exec "${SCRIPT_DIR}/load-firmware.sh" "${ELF}"
