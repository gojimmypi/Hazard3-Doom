#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if command -v shellcheck >/dev/null 2>&1; then
    shellcheck "$0"
else
    echo "shellcheck is not installed; skipping script self-check."
fi
PROFILE="${COREMARK_BUILD_PROFILE:-baseline}"
RUN_NAME="${1:-performance}"
SERIAL_PORT="${2:-${COREMARK_SERIAL_PORT:-}}"
SYSTEM_CLOCK_HZ="${HAZARD3_SYS_CLK_HZ:-50000000}"
BUILD_DIR="${HAZARD3_COREMARK_BUILD_DIR:-${ROOT_DIR}/build/coremark/${PROFILE}}"
ELF="${BUILD_DIR}/coremark-${RUN_NAME}.elf"

case "${RUN_NAME}" in
performance|validation)
    ;;
*)
    echo "Usage: $0 [performance|validation] [serial-port]" >&2
    exit 1
    ;;
esac

if [[ ! -f "${ELF}" ]]; then
    "${SCRIPT_DIR}/build-coremark.sh"
fi

if [[ -z "${SERIAL_PORT}" ]]; then
    printf 'Loading %s\n' "${ELF}"
    printf 'Capture the 115200 8N1 UART output in your terminal.\n'
    "${SCRIPT_DIR}/load_firmware.sh" "${ELF}"
    exit 0
fi

python3 "${ROOT_DIR}/benchmarks/coremark/run_coremark.py" \
    --elf "${ELF}" \
    --port "${SERIAL_PORT}" \
    --loader "${SCRIPT_DIR}/load_firmware.sh" \
    --clock-hz "${SYSTEM_CLOCK_HZ}"
