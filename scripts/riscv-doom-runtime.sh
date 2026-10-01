#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File:        riscv-doom-runtime.sh
# Path:        scripts/riscv-doom-runtime.sh
#
# Project:     Hazard3-Doom
# Purpose:     Detect and configure the target C runtime used by Doom builds.
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

hazard3_resolve_riscv_tool()
{
    local tool="$1"

    if [[ "${tool}" == */* ]]; then
        if [[ -x "${tool}" ]]; then
            printf '%s' "${tool}"
            return 0
        fi
        return 1
    fi

    command -v "${tool}" 2>/dev/null
}

hazard3_riscv_prefix_is_complete()
{
    local prefix="$1"
    local tool=""

    for tool in gcc objcopy objdump size ar nm; do
        if ! hazard3_resolve_riscv_tool "${prefix}${tool}" >/dev/null; then
            return 1
        fi
    done

    return 0
}

hazard3_riscv_compiler_accepts_hazard3()
{
    local prefix="$1"
    local gcc=""

    if ! gcc="$(hazard3_resolve_riscv_tool "${prefix}gcc")"; then
        return 1
    fi

    if printf '%s\n' 'int hazard3_toolchain_check;' |
        "${gcc}" \
            -march=rv32imc_zicsr_zifencei_zba_zbb_zbs \
            -mabi=ilp32 \
            -ffreestanding \
            -x c \
            -c \
            -o /dev/null \
            - >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

hazard3_riscv_prefix_is_compatible()
{
    local prefix="$1"

    if ! hazard3_riscv_prefix_is_complete "${prefix}"; then
        return 1
    fi
    if ! hazard3_riscv_compiler_accepts_hazard3 "${prefix}"; then
        return 1
    fi
    if ! hazard3_configure_doom_runtime "${prefix}"; then
        return 1
    fi

    return 0
}

hazard3_find_compatible_riscv_prefix()
{
    local candidate=""

    # An explicit prefix is authoritative. Do not silently fall back to another
    # compiler when the caller has selected one deliberately.
    if [[ -n "${TOOLCHAIN_PREFIX:-}" ]]; then
        if hazard3_riscv_prefix_is_compatible "${TOOLCHAIN_PREFIX}"; then
            printf '%s' "${TOOLCHAIN_PREFIX}"
            return 0
        fi
        return 2
    fi

    # Prefer supported command prefixes already on PATH, then retain the
    # historical /opt installation as a compatibility fallback. Crucially,
    # continue past a compiler that exists but is incomplete for Hazard3-Doom.
    for candidate in \
        riscv-none-elf- \
        riscv32-unknown-elf- \
        riscv64-unknown-elf- \
        /opt/riscv/bin/riscv32-unknown-elf-
    do
        if hazard3_riscv_prefix_is_compatible "${candidate}"; then
            printf '%s' "${candidate}"
            return 0
        fi
    done

    return 1
}

hazard3_find_picolibc_specs()
{
    local gcc="$1"
    local candidate=""
    local target=""

    if [[ -n "${HAZARD3_DOOM_PICOLIBC_SPECS:-}" ]]; then
        if [[ -r "${HAZARD3_DOOM_PICOLIBC_SPECS}" ]]; then
            printf '%s' "${HAZARD3_DOOM_PICOLIBC_SPECS}"
            return 0
        fi
        return 1
    fi

    candidate="$("${gcc}" -print-file-name=picolibc.specs 2>/dev/null || true)"
    if [[ -n "${candidate}" && "${candidate}" != "picolibc.specs" && -r "${candidate}" ]]; then
        printf '%s' "${candidate}"
        return 0
    fi

    target="$("${gcc}" -dumpmachine 2>/dev/null || true)"
    if [[ -n "${target}" ]]; then
        candidate="/usr/lib/picolibc/${target}/picolibc.specs"
        if [[ -r "${candidate}" ]]; then
            printf '%s' "${candidate}"
            return 0
        fi
    fi

    return 1
}

hazard3_doom_headers_compile()
{
    local gcc="$1"
    local specs="${2:-}"
    local -a runtime_flags=()

    if [[ -n "${specs}" ]]; then
        runtime_flags+=("--specs=${specs}")
    fi

    printf '%s\n' \
        '#include <strings.h>' \
        '#include <stdlib.h>' \
        'int hazard3_doom_runtime_check(void) { return strcasecmp("a", "b"); }' |
        "${gcc}" \
            "${runtime_flags[@]}" \
            -march=rv32ima_zicsr_zifencei \
            -mabi=ilp32 \
            -ffreestanding \
            -x c \
            -c \
            -o /dev/null \
            - >/dev/null 2>&1
}

hazard3_doom_library_is_available()
{
    local gcc="$1"
    local specs="$2"
    local library="$3"
    local library_path=""
    local -a runtime_flags=()

    if [[ -n "${specs}" ]]; then
        runtime_flags+=("--specs=${specs}")
    fi

    library_path="$(
        "${gcc}" \
            "${runtime_flags[@]}" \
            -march=rv32ima_zicsr_zifencei \
            -mabi=ilp32 \
            -print-file-name="${library}" 2>/dev/null || true
    )"

    [[ -n "${library_path}" && "${library_path}" != "${library}" && -r "${library_path}" ]]
}

hazard3_doom_newlib_runtime_is_usable()
{
    local gcc="$1"
    local library=""

    if ! hazard3_doom_headers_compile "${gcc}"; then
        return 1
    fi

    for library in libc.a libm.a libgcc.a libnosys.a; do
        if ! hazard3_doom_library_is_available "${gcc}" "" "${library}"; then
            return 1
        fi
    done

    return 0
}

hazard3_doom_picolibc_link_test()
{
    local gcc="$1"
    local specs="$2"
    local linker_script=""
    local status=0

    if ! linker_script="$(mktemp "${TMPDIR:-/tmp}/hazard3-picolibc-link.XXXXXX")"; then
        return 1
    fi

    cat > "${linker_script}" <<'EOF_LINKER'
ENTRY(main)
SECTIONS
{
    . = 0x00010000;
    .text : { *(.text*) }
    .rodata : { *(.rodata*) }
    .data : { *(.data*) }
    .bss : { *(.bss*) *(COMMON) }
}
EOF_LINKER

    if ! printf '%s\n' \
        '#include <math.h>' \
        '#include <strings.h>' \
        'volatile double hazard3_picolibc_value = 1.0;' \
        'int main(void) {' \
        '    return strcasecmp("a", "b") + (int)sin(hazard3_picolibc_value);' \
        '}' |
        "${gcc}" \
            "--specs=${specs}" \
            -march=rv32ima_zicsr_zifencei \
            -mabi=ilp32 \
            -ffreestanding \
            -nostartfiles \
            -no-pie \
            -Wl,--no-relax \
            -T"${linker_script}" \
            -x c \
            -o /dev/null \
            - \
            -Wl,--start-group -lc -lm -lgcc -Wl,--end-group \
            >/dev/null 2>&1; then
        status=1
    fi

    rm -f -- "${linker_script}"
    return "${status}"
}

hazard3_doom_picolibc_runtime_is_usable()
{
    local gcc="$1"
    local specs="$2"

    if [[ -z "${specs}" || ! -r "${specs}" ]]; then
        return 1
    fi

    if ! hazard3_doom_headers_compile "${gcc}" "${specs}"; then
        return 1
    fi

    # Do not use -print-file-name to validate Picolibc libraries. GCC does not
    # necessarily apply specs-provided linker search paths to that query. Prove
    # the configuration the same way the Doom build uses it: compile and link
    # an RV32 program through picolibc.specs with libc, libm, and libgcc.
    hazard3_doom_picolibc_link_test "${gcc}" "${specs}"
}

# This helper is sourced by several build/check scripts. The function below
# intentionally writes HAZARD3_DOOM_RUNTIME_* globals for those callers.
# shellcheck disable=SC2034
hazard3_configure_doom_runtime()
{
    local prefix="$1"
    local gcc=""
    local requested="${HAZARD3_DOOM_LIBC:-auto}"
    local specs=""

    HAZARD3_DOOM_RUNTIME_MODE=""
    HAZARD3_DOOM_RUNTIME_SPECS=""
    HAZARD3_DOOM_RUNTIME_ERROR=""
    HAZARD3_DOOM_RUNTIME_COMPILE_FLAGS=()
    HAZARD3_DOOM_RUNTIME_LINK_FLAGS=()
    HAZARD3_DOOM_RUNTIME_LIBRARIES=()
    HAZARD3_DOOM_RUNTIME_PORT_SOURCES=()

    if ! gcc="$(hazard3_resolve_riscv_tool "${prefix}gcc")"; then
        HAZARD3_DOOM_RUNTIME_ERROR="RISC-V GCC not found: ${prefix}gcc"
        return 1
    fi

    case "${requested}" in
    auto|newlib|picolibc)
        ;;
    *)
        HAZARD3_DOOM_RUNTIME_ERROR="Unsupported HAZARD3_DOOM_LIBC=${requested} (use auto, newlib, or picolibc)"
        return 1
        ;;
    esac

    if [[ "${requested}" == "auto" || "${requested}" == "newlib" ]]; then
        if hazard3_doom_newlib_runtime_is_usable "${gcc}"; then
            HAZARD3_DOOM_RUNTIME_MODE="newlib"
            HAZARD3_DOOM_RUNTIME_LIBRARIES=(-lc -lm -lgcc -lnosys)
            return 0
        fi
        if [[ "${requested}" == "newlib" ]]; then
            HAZARD3_DOOM_RUNTIME_ERROR="Selected RISC-V compiler does not provide the Newlib Doom runtime"
            return 1
        fi
    fi

    if [[ "${requested}" == "auto" || "${requested}" == "picolibc" ]]; then
        specs="$(hazard3_find_picolibc_specs "${gcc}" || true)"
        if hazard3_doom_picolibc_runtime_is_usable "${gcc}" "${specs}"; then
            HAZARD3_DOOM_RUNTIME_MODE="picolibc"
            HAZARD3_DOOM_RUNTIME_SPECS="${specs}"
            HAZARD3_DOOM_RUNTIME_COMPILE_FLAGS=("--specs=${specs}")
            HAZARD3_DOOM_RUNTIME_LINK_FLAGS=("--specs=${specs}")
            HAZARD3_DOOM_RUNTIME_LIBRARIES=(-lc -lm -lgcc)
            HAZARD3_DOOM_RUNTIME_PORT_SOURCES=(hazard3_picolibc.c)
            return 0
        fi
        if [[ "${requested}" == "picolibc" ]]; then
            HAZARD3_DOOM_RUNTIME_ERROR="Selected RISC-V compiler does not provide a usable Picolibc Doom runtime"
            return 1
        fi
    fi

    HAZARD3_DOOM_RUNTIME_ERROR="Selected RISC-V compiler has neither a complete Newlib runtime nor a usable Picolibc specs configuration"
    return 1
}
