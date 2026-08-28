#!/bin/bash
# -----------------------------------------------------------------------------
# File:        run.sh
# Path:        tests/software-verify/run.sh
#
# Project:     Hazard3-Doom
# Purpose:     Build, load, and run the Hazard3 software verification test.
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

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
PORT="${1:-/dev/ttyS6}"
TIMEOUT="${VERIFY_TIMEOUT_S:-120}"
ELF="${ROOT_DIR}/build/software-verify/hazard3-software-verify.elf"

"${SCRIPT_DIR}/build.sh"

if ! python3 -c 'import serial' >/dev/null 2>&1; then
    echo "ERROR: pyserial is required: python3 -m pip install pyserial" >&2
    exit 1
fi

python3 "${SCRIPT_DIR}/capture.py" \
    --port "${PORT}" \
    --timeout "${TIMEOUT}" &
CAPTURE_PID=$!

cleanup() {
    if kill -0 "${CAPTURE_PID}" 2>/dev/null; then
        kill "${CAPTURE_PID}" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# Make sure the UART is open before the loader resumes the target.
sleep 0.5

set +e
"${ROOT_DIR}/scripts/load-firmware.sh" "${ELF}"
LOAD_RC=$?
set -e

if [[ ${LOAD_RC} -ne 0 ]]; then
    echo "ERROR: load-firmware.sh failed with status ${LOAD_RC}" >&2
    exit "${LOAD_RC}"
fi

set +e
wait "${CAPTURE_PID}"
CAPTURE_RC=$?
set -e

if [[ ${CAPTURE_RC} -eq 0 ]]; then
    echo "Software verifier: PASS"
else
    echo "Software verifier: FAIL (capture status ${CAPTURE_RC})" >&2
fi

exit "${CAPTURE_RC}"
