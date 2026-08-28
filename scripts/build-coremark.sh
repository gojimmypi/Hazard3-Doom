#!/bin/bash
# -----------------------------------------------------------------------------
# File:        build-coremark.sh
# Path:        scripts/build-coremark.sh
#
# Project:     Hazard3-Doom
# Purpose:     Build the Hazard3 CoreMark port using the selected baseline or
#              tuned profile.
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
PORT_DIR="${ROOT_DIR}/benchmarks/coremark"
HAZARD3_ROOT="${HAZARD3_ROOT:-${ROOT_DIR}/third_party/Hazard3}"
COREMARK_DIR="${COREMARK_DIR:-${HAZARD3_ROOT}/test/sim/coremark/dist}"
TOOLCHAIN_PREFIX="${TOOLCHAIN_PREFIX:-/opt/riscv/bin/riscv32-unknown-elf-}"
CC="${TOOLCHAIN_PREFIX}gcc"
SIZE="${TOOLCHAIN_PREFIX}size"
READELF="${TOOLCHAIN_PREFIX}readelf"
OBJDUMP="${TOOLCHAIN_PREFIX}objdump"
PROFILE="${COREMARK_BUILD_PROFILE:-baseline}"
ITERATIONS="${COREMARK_ITERATIONS:-3000}"
SYSTEM_CLOCK_HZ="${HAZARD3_SYS_CLK_HZ:-50000000}"
BUILD_DIR="${HAZARD3_COREMARK_BUILD_DIR:-${ROOT_DIR}/build/coremark/${PROFILE}}"
SOURCE_CHECKER="${PORT_DIR}/check_coremark_sources.py"
ELF_ANALYZER="${PORT_DIR}/analyze_elf.py"

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

require_tool()
{
    local tool="$1"
    if [[ "${tool}" == */* ]]; then
        [[ -x "${tool}" ]] || { echo "Missing required executable: ${tool}" >&2; exit 1; }
    else
        command -v "${tool}" >/dev/null 2>&1 || { echo "Missing required tool: ${tool}" >&2; exit 1; }
    fi
}

require_file()
{
    [[ -f "$1" ]] || { echo "Missing required file: $1" >&2; exit 1; }
}

case "${PROFILE}" in
baseline)
    optimization_flags=(-O2 -fomit-frame-pointer)
    ;;
tuned)
    optimization_flags=(
        -O3
        -fomit-frame-pointer
        -mbranch-cost=1
        -funroll-all-loops
        --param max-inline-insns-auto=200
        -finline-limit=10000
        -fno-code-hoisting
        -fno-if-conversion2
        -falign-functions=4
        -falign-jumps=4
        -falign-loops=4
    )
    ;;
*)
    echo "Unsupported COREMARK_BUILD_PROFILE: ${PROFILE} (use baseline or tuned)" >&2
    exit 1
    ;;
esac

case "${SYSTEM_CLOCK_HZ}" in
25000000|50000000)
    ;;
*)
    echo "Unsupported HAZARD3_SYS_CLK_HZ: ${SYSTEM_CLOCK_HZ} (use 25000000 or 50000000)" >&2
    exit 1
    ;;
esac

[[ "${ITERATIONS}" =~ ^[1-9][0-9]*$ ]] || {
    echo "COREMARK_ITERATIONS must be a positive integer" >&2
    exit 1
}

require_tool "${CC}"
require_tool "${SIZE}"
require_tool "${READELF}"
require_tool "${OBJDUMP}"
require_tool python3
require_tool git
for file in \
    core_list_join.c \
    core_main.c \
    core_matrix.c \
    core_state.c \
    core_util.c \
    coremark.h; do
    require_file "${COREMARK_DIR}/${file}"
done
for file in \
    core_portme.c \
    core_portme.h \
    ee_printf.c \
    start.S \
    link.ld \
    check_coremark_sources.py \
    analyze_elf.py; do
    require_file "${PORT_DIR}/${file}"
done

mkdir -p "${BUILD_DIR}"
SOURCE_INTEGRITY_JSON="${BUILD_DIR}/source-integrity.json"
python3 "${SOURCE_CHECKER}" \
    --hazard3-root "${HAZARD3_ROOT}" \
    --coremark-dir "${COREMARK_DIR}" \
    --json "${SOURCE_INTEGRITY_JSON}"

arch_flags=(
    -march=rv32imc_zicsr_zifencei_zba_zbb_zbs
    -mabi=ilp32
)
common_flags=(
    "${arch_flags[@]}"
    "${optimization_flags[@]}"
    -g3
    -ffreestanding
    -fno-builtin
    -fno-pic
    -msmall-data-limit=0
    -ffunction-sections
    -fdata-sections
    -nostdlib
    -nostartfiles
    -DHAS_FLOAT=0
    -DTOTAL_DATA_SIZE=2000
    "-DITERATIONS=${ITERATIONS}"
    "-DHAZARD3_SYS_CLK_HZ=${SYSTEM_CLOCK_HZ}u"
    -I"${PORT_DIR}"
    -I"${COREMARK_DIR}"
)
flags_str="${common_flags[*]}"
common_flags+=("-DFLAGS_STR=\"${flags_str}\"")

sources=(
    "${PORT_DIR}/start.S"
    "${PORT_DIR}/core_portme.c"
    "${PORT_DIR}/ee_printf.c"
    "${COREMARK_DIR}/core_list_join.c"
    "${COREMARK_DIR}/core_main.c"
    "${COREMARK_DIR}/core_matrix.c"
    "${COREMARK_DIR}/core_state.c"
    "${COREMARK_DIR}/core_util.c"
)

hazard3_commit="$(git -C "${HAZARD3_ROOT}" rev-parse HEAD)"
hazard3_doom_commit="unknown"
if git -C "${ROOT_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    hazard3_doom_commit="$(git -C "${ROOT_DIR}" rev-parse HEAD)"
fi
compiler_version="$("${CC}" --version)"
compiler_version="${compiler_version%%$'\n'*}"
cat > "${BUILD_DIR}/build-info.txt" <<EOF_INFO
profile=${PROFILE}
iterations=${ITERATIONS}
clock_hz=${SYSTEM_CLOCK_HZ}
hazard3_commit=${hazard3_commit}
hazard3_doom_commit=${hazard3_doom_commit}
compiler=${compiler_version}
compiler_flags=${flags_str}
memory=linker-defined internal SRAM (code/data/stack)
EOF_INFO

EXPECTED_ISA_OBJECT="${BUILD_DIR}/expected-isa.o"
printf 'void coremark_expected_isa(void) {}\n' | \
    "${CC}" "${arch_flags[@]}" -ffreestanding -fno-builtin -c -x c - \
        -o "${EXPECTED_ISA_OBJECT}"

build_one()
{
    local run_name="$1"
    local run_define="$2"
    local output_elf="${BUILD_DIR}/coremark-${run_name}.elf"
    local output_map="${BUILD_DIR}/coremark-${run_name}.map"
    local output_isa_json="${BUILD_DIR}/coremark-${run_name}.isa.json"
    local output_isa_text="${BUILD_DIR}/coremark-${run_name}.isa.txt"

    printf 'Building CoreMark %-11s profile=%s iterations=%s clock=%s Hz\n' \
        "${run_name}" "${PROFILE}" "${ITERATIONS}" "${SYSTEM_CLOCK_HZ}"
    "${CC}" \
        "${common_flags[@]}" \
        "${run_define}" \
        -Wl,-T,"${PORT_DIR}/link.ld" \
        -Wl,-Map,"${output_map}" \
        -Wl,--gc-sections \
        "${sources[@]}" \
        -lgcc \
        -o "${output_elf}"
    "${SIZE}" "${output_elf}"
    python3 "${ELF_ANALYZER}" \
        --elf "${output_elf}" \
        --readelf "${READELF}" \
        --objdump "${OBJDUMP}" \
        --json "${output_isa_json}" \
        --text "${output_isa_text}" \
        --expected-arch-object "${EXPECTED_ISA_OBJECT}"
    printf 'CoreMark ELF: %s\n' "${output_elf}"
}

build_one performance -DPERFORMANCE_RUN=1
build_one validation -DVALIDATION_RUN=1
