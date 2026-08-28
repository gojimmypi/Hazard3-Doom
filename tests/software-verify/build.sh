#!/bin/bash
# -----------------------------------------------------------------------------
# File:        build.sh
# Path:        tests/software-verify/build.sh
#
# Project:     Hazard3-Doom
# Purpose:     Build the standalone Hazard3 software verification payload.
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
OUT_DIR="${ROOT_DIR}/build/software-verify"
TOOLCHAIN_PREFIX="${TOOLCHAIN_PREFIX:-/opt/riscv/bin/riscv32-unknown-elf-}"
CC="${TOOLCHAIN_PREFIX}gcc"
OBJDUMP="${TOOLCHAIN_PREFIX}objdump"
SIZE="${TOOLCHAIN_PREFIX}size"
ROUNDS="${VERIFY_ROUNDS:-10000}"
SYS_CLK_HZ="${HAZARD3_SYS_CLK_HZ:-50000000}"

mkdir -p "${OUT_DIR}"

for tool in "${CC}" "${OBJDUMP}" "${SIZE}"; do
    if [[ ! -x "${tool}" ]] && ! command -v "${tool}" >/dev/null 2>&1; then
        echo "ERROR: required tool not found: ${tool}" >&2
        exit 1
    fi
done

ELF="${OUT_DIR}/hazard3-software-verify.elf"
MAP="${OUT_DIR}/hazard3-software-verify.map"
DIS="${OUT_DIR}/hazard3-software-verify.dis"

echo "Building Hazard3 software verifier"
echo "  rounds: ${ROUNDS}"
echo "  sys_clk_hz: ${SYS_CLK_HZ}"
echo "  output: ${ELF}"

"${CC}" \
    -march=rv32ima_zicsr_zifencei \
    -mabi=ilp32 \
    -O2 \
    -g3 \
    -ffreestanding \
    -fno-builtin \
    -fno-pic \
    -ffunction-sections \
    -fdata-sections \
    -msmall-data-limit=0 \
    -Wall \
    -Wextra \
    -Werror \
    -DVERIFY_ROUNDS="${ROUNDS}" \
    -DVERIFY_SYS_CLK_HZ="${SYS_CLK_HZ}" \
    -nostdlib \
    -nostartfiles \
    -Wl,--gc-sections \
    -Wl,--no-warn-rwx-segments \
    -Wl,-Map,"${MAP}" \
    -T "${SCRIPT_DIR}/link.ld" \
    "${SCRIPT_DIR}/start.S" \
    "${SCRIPT_DIR}/verify.c" \
    -o "${ELF}"

"${OBJDUMP}" -h -d "${ELF}" > "${DIS}"
"${SIZE}" "${ELF}"

echo "Ready: ${ELF}"
