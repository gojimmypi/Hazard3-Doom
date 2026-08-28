#!/bin/bash
# -----------------------------------------------------------------------------
# File:        run-coremark.sh
# Path:        scripts/run-coremark.sh
#
# Project:     Hazard3-Doom
# Purpose:     Run and qualify Hazard3 CoreMark images over the target UART
#              and record results.
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
PORT_DIR="${ROOT_DIR}/benchmarks/coremark"
HAZARD3_ROOT="${HAZARD3_ROOT:-${ROOT_DIR}/third_party/Hazard3}"
COREMARK_DIR="${COREMARK_DIR:-${HAZARD3_ROOT}/test/sim/coremark/dist}"
SOURCE_CHECKER="${PORT_DIR}/check_coremark_sources.py"
SOURCE_INTEGRITY_JSON="${BUILD_DIR}/source-integrity.json"
BUILD_INFO="${BUILD_DIR}/build-info.txt"

case "${RUN_NAME}" in
performance|validation|qualify)
    ;;
*)
    echo "Usage: $0 [performance|validation|qualify] [serial-port]" >&2
    exit 1
    ;;
esac

build_if_needed()
{
    local run_name="$1"
    local elf="${BUILD_DIR}/coremark-${run_name}.elf"
    local isa_json="${BUILD_DIR}/coremark-${run_name}.isa.json"

    if [[ ! -f "${elf}" || ! -f "${isa_json}" || ! -f "${SOURCE_INTEGRITY_JSON}" ]]; then
        COREMARK_BUILD_PROFILE="${PROFILE}" "${SCRIPT_DIR}/build-coremark.sh"
    fi
}

refresh_source_integrity()
{
    python3 "${SOURCE_CHECKER}" \
        --hazard3-root "${HAZARD3_ROOT}" \
        --coremark-dir "${COREMARK_DIR}" \
        --json "${SOURCE_INTEGRITY_JSON}"
}

run_one()
{
    local run_name="$1"
    local elf="${BUILD_DIR}/coremark-${run_name}.elf"
    local isa_json="${BUILD_DIR}/coremark-${run_name}.isa.json"
    local log_file="${BUILD_DIR}/coremark-${run_name}.run.log"
    local result_json="${BUILD_DIR}/coremark-${run_name}.result.json"

    build_if_needed "${run_name}"

    if [[ -z "${SERIAL_PORT}" ]]; then
        printf 'Loading %s\n' "${elf}"
        printf 'Capture the 115200 8N1 UART output in your terminal.\n'
        "${SCRIPT_DIR}/load-firmware.sh" "${elf}"
        return 0
    fi

    python3 "${PORT_DIR}/run_coremark.py" \
        --elf "${elf}" \
        --port "${SERIAL_PORT}" \
        --loader "${SCRIPT_DIR}/load-firmware.sh" \
        --clock-hz "${SYSTEM_CLOCK_HZ}" \
        --isa-json "${isa_json}" \
        --source-integrity-json "${SOURCE_INTEGRITY_JSON}" \
        --build-info "${BUILD_INFO}" \
        --log-file "${log_file}" \
        --result-json "${result_json}"
}

if [[ "${RUN_NAME}" != "qualify" ]]; then
    build_if_needed "${RUN_NAME}"
    refresh_source_integrity
    run_one "${RUN_NAME}"
    exit $?
fi

if [[ -z "${SERIAL_PORT}" ]]; then
    echo "The qualify command requires a serial port." >&2
    echo "Usage: $0 qualify /dev/ttyS7" >&2
    exit 1
fi

build_if_needed performance
build_if_needed validation
refresh_source_integrity

performance_status=0
validation_status=0
if ! run_one performance; then
    performance_status=1
fi
if ! run_one validation; then
    validation_status=1
fi

performance_result="${BUILD_DIR}/coremark-performance.result.json"
validation_result="${BUILD_DIR}/coremark-validation.result.json"

if python3 - "${performance_result}" "${validation_result}" "${SOURCE_INTEGRITY_JSON}" <<'PY'
import json
import sys
from pathlib import Path

performance = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
validation = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
source = json.loads(Path(sys.argv[3]).read_text(encoding="utf-8"))

performance_ok = performance.get("status") == "PASS"
validation_ok = validation.get("status") == "PASS"
source_ok = source.get("status") == "PASS"
isa_ok = performance.get("isa_compatibility") is not False and validation.get("isa_compatibility") is not False
result = performance_ok and validation_ok and source_ok and isa_ok

print()
print("Hazard3 ULX3S CoreMark qualification")
print(f"  performance run    : {'PASS' if performance_ok else 'FAIL'}")
print(f"  validation run     : {'PASS' if validation_ok else 'FAIL'}")
print(f"  source integrity   : {'PASS' if source_ok else 'FAIL'}")
print(f"  ISA compatibility  : {'PASS' if isa_ok else 'FAIL'}")
print(f"  RESULT             : {'VALID' if result else 'INVALID'}")
sys.exit(0 if result else 1)
PY
then
    qualify_status=0
else
    qualify_status=1
fi

if (( performance_status != 0 || validation_status != 0 )); then
    exit 1
fi
exit "${qualify_status}"
