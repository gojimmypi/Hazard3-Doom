#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File:        peek-elf.sh
# Path:        scripts/peek-elf.sh
#
# Project:     Hazard3-Doom
# Purpose:     Inspect RISC-V ELF, map, multilib, ISA, ABI, and
#              runtime-library selection details.
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

# Hazard3 CoreMark ELF/toolchain diagnostic helper.
#
# This script inspects the RISC-V GCC configuration used for the Hazard3
# CoreMark build and compares the requested ISA/ABI with what GCC actually
# selects and what the final linked ELF advertises.  In particular, it makes
# otherwise-silent multilib fallback behavior visible, compares the selected
# libgcc.a with the base-ISA multilib, probes GCC/assembler ISA attributes
# using the exact build flags, checks linker-map references, and validates the
# final ELF class, ABI flags, RVC flag, and Tag_RISCV_arch attributes.
#
# This is a diagnostic tool, not a build step.  WARN results identify
# suspicious or noteworthy toolchain conditions but do not make the script
# fail.  The script exits nonzero only for required-tool/input errors or
# invalid command-line usage.
#
# Usage:
#   ./scripts/peek-elf.sh [MAP_FILE [ELF_FILE]]
#
# Environment overrides:
#   CC       RISC-V GCC executable
#   READELF  RISC-V readelf executable
#   ARCH     GCC -march option
#   ABI      GCC -mabi option
#
# With no arguments, the script examines the baseline Hazard3 CoreMark
# performance map and ELF under build/coremark/baseline/.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly REPO_ROOT

readonly CC="${CC:-/opt/riscv/bin/riscv32-unknown-elf-gcc}"
readonly READELF="${READELF:-/opt/riscv/bin/riscv32-unknown-elf-readelf}"
readonly ARCH="${ARCH:--march=rv32imc_zicsr_zifencei_zba_zbb_zbs}"
readonly ABI="${ABI:--mabi=ilp32}"
readonly DEFAULT_MAP_FILE="${REPO_ROOT}/build/coremark/baseline/coremark-performance.map"
readonly DEFAULT_ELF_FILE="${REPO_ROOT}/build/coremark/baseline/coremark-performance.elf"

WARNING_COUNT=0

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

usage() {
    cat <<EOF_USAGE
Usage: ${0##*/} [MAP_FILE [ELF_FILE]]

Diagnose the RISC-V GCC multilib and libgcc selection used by the Hazard3
CoreMark build, then compare that selection with the final ELF.

The report shows:
    - requested -march and -mabi
    - GCC-selected multilib and libgcc.a
    - all installed GCC multilibs
    - a base-ISA multilib probe (for example rv32imc vs rv32imc_z*)
    - libgcc.a references and archive members visible in the linker map
    - RISC-V architecture attributes in the selected libgcc.a
    - a compiler/assembler object probe using the exact requested flags
    - RISC-V architecture attributes and ELF header details in the final ELF
    - ISA implication-aware PASS/WARN diagnostics

Environment overrides:
    CC        RISC-V GCC executable
    READELF   RISC-V readelf executable
    ARCH      GCC -march option
    ABI       GCC -mabi option

Default map file:
    ${DEFAULT_MAP_FILE}

Default ELF file:
    ${DEFAULT_ELF_FILE}

If MAP_FILE is supplied without ELF_FILE, the ELF path is derived by replacing
its .map suffix with .elf.
EOF_USAGE
}

die() {
    printf '[FAIL] %s\n' "$*" >&2
    exit 1
}

info() {
    printf '[INFO] %s\n' "$*"
}

pass() {
    printf '[PASS] %s\n' "$*"
}

warn() {
    printf '[WARN] %s\n' "$*"
    ((WARNING_COUNT += 1))
}

heading() {
    printf '\n== %s ==\n' "$1"
}

require_tool() {
    local tool="$1"

    if [[ "${tool}" == */* ]]; then
        [[ -x "${tool}" ]] || die "tool is not executable: ${tool}"
    elif ! command -v -- "${tool}" >/dev/null 2>&1; then
        die "tool not found in PATH: ${tool}"
    fi
}

option_value() {
    local option="$1"
    local prefix="$2"

    [[ "${option}" == "${prefix}"* ]] || return 1
    printf '%s\n' "${option#"${prefix}"}"
}

find_multilib() {
    local multilibs="$1"
    local march="$2"
    local abi="$3"

    awk -F'[@;]' -v march="${march}" -v abi="${abi}" '
        {
            have_march = 0
            have_abi = 0
            for (i = 2; i <= NF; ++i) {
                if ($i == "march=" march)
                    have_march = 1
                if ($i == "mabi=" abi)
                    have_abi = 1
            }
            if (have_march && have_abi)
                print $1
        }
    ' <<<"${multilibs}"
}

arch_attributes() {
    local file="$1"

    "${READELF}" -A "${file}" 2>/dev/null |
        awk '/Tag_RISCV_arch/ {
            line = $0
            sub(/^.*Tag_RISCV_arch:[[:space:]]*/, "", line)
            gsub(/^"|"$/, "", line)
            print line
        }' |
        sort -u
}

extensions_for_arch() {
    local march="$1"
    local body
    local first
    local token
    local normalized
    local i

    body="${march#rv32}"
    body="${body#rv64}"
    first="${body%%_*}"

    normalized="$(sed -E 's/[0-9]+p[0-9]+//g; s/[0-9]+//g' <<<"${first}")"
    for ((i = 0; i < ${#normalized}; ++i)); do
        printf '%s\n' "${normalized:i:1}"
    done

    if [[ "${body}" == *_* ]]; then
        body="${body#*_}"
        while IFS= read -r token; do
            normalized="$(sed -E 's/[0-9]+p[0-9]+//g; s/[0-9]+//g' <<<"${token}")"
            [[ -n "${normalized}" ]] && printf '%s\n' "${normalized}"
        done < <(tr '_' '\n' <<<"${body}")
    fi
}

extensions_for_arch_list() {
    local arch

    while IFS= read -r arch; do
        [[ -n "${arch}" ]] || continue
        extensions_for_arch "${arch}"
    done | sort -u
}

join_lines() {
    local text="$1"

    awk 'BEGIN { first = 1 }
        NF {
            if (!first)
                printf ", "
            printf "%s", $0
            first = 0
        }
        END {
            if (!first)
                printf "\n"
        }
    ' <<<"${text}"
}

has_line() {
    local needle="$1"
    local haystack="$2"

    grep -Fx -- "${needle}" <<<"${haystack}" >/dev/null 2>&1
}

effective_extensions() {
    local requested="$1"

    printf '%s\n' "${requested}"

    # RISC-V defines M as implying Zmmul.  Treat an emitted zmmul attribute
    # as expected whenever M was requested rather than reporting a false alarm.
    if has_line 'm' "${requested}"; then
        printf '%s\n' 'zmmul'
    fi
}

derive_elf_file() {
    local map_file="$1"

    if [[ "${map_file}" == *.map ]]; then
        printf '%s.elf\n' "${map_file%.map}"
    else
        printf '%s.elf\n' "${map_file}"
    fi
}

case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
esac

[[ $# -le 2 ]] || {
    usage >&2
    exit 2
}

readonly MAP_FILE="${1:-${DEFAULT_MAP_FILE}}"
if [[ $# -ge 2 ]]; then
    ELF_FILE="$2"
elif [[ $# -eq 1 ]]; then
    ELF_FILE="$(derive_elf_file "${MAP_FILE}")"
else
    ELF_FILE="${DEFAULT_ELF_FILE}"
fi
readonly ELF_FILE

require_tool "${CC}"
require_tool "${READELF}"
[[ -f "${MAP_FILE}" ]] || die "linker map not found: ${MAP_FILE}"

MARCH="$(option_value "${ARCH}" '-march=')" ||
    die "ARCH must be a single -march=... option; got: ${ARCH}"
ABI_NAME="$(option_value "${ABI}" '-mabi=')" ||
    die "ABI must be a single -mabi=... option; got: ${ABI}"
readonly MARCH
readonly ABI_NAME
readonly BASE_MARCH="${MARCH%%_*}"
MULTILIBS="$("${CC}" -print-multi-lib)"
readonly MULTILIBS
MULTI_DIR="$("${CC}" "${ARCH}" "${ABI}" -print-multi-directory)"
readonly MULTI_DIR
LIBGCC="$("${CC}" "${ARCH}" "${ABI}" -print-libgcc-file-name)"
readonly LIBGCC
GCC_VERSION="$("${CC}" -dumpfullversion -dumpversion)"
readonly GCC_VERSION
GCC_TARGET="$("${CC}" -dumpmachine)"
readonly GCC_TARGET
REQUESTED_EXTENSIONS="$(extensions_for_arch "${MARCH}" | sort -u)"
readonly REQUESTED_EXTENSIONS
EFFECTIVE_REQUESTED_EXTENSIONS="$(effective_extensions "${REQUESTED_EXTENSIONS}" | sort -u)"
readonly EFFECTIVE_REQUESTED_EXTENSIONS
GCC_VERBOSE="$("${CC}" -v 2>&1 || true)"
readonly GCC_VERBOSE
GCC_CONFIG_ISA_SPEC=''
if [[ "${GCC_VERBOSE}" =~ --with-isa-spec=([^[:space:]]+) ]]; then
    GCC_CONFIG_ISA_SPEC="${BASH_REMATCH[1]}"
fi
readonly GCC_CONFIG_ISA_SPEC

[[ -f "${LIBGCC}" ]] || die "libgcc archive not found: ${LIBGCC}"

FULL_EXACT_MULTILIB="$(find_multilib "${MULTILIBS}" "${MARCH}" "${ABI_NAME}")"
BASE_INSTALLED_MULTILIB="$(find_multilib "${MULTILIBS}" "${BASE_MARCH}" "${ABI_NAME}")"
BASE_MULTI_DIR=''
BASE_LIBGCC=''
if [[ "${BASE_MARCH}" != "${MARCH}" ]]; then
    if BASE_MULTI_DIR="$("${CC}" "-march=${BASE_MARCH}" "${ABI}" -print-multi-directory 2>/dev/null)"; then
        BASE_LIBGCC="$("${CC}" "-march=${BASE_MARCH}" "${ABI}" -print-libgcc-file-name 2>/dev/null || true)"
    fi
fi

heading 'Hazard3 CoreMark toolchain selection'
printf '%-18s %s\n' 'Compiler:' "${CC}"
printf '%-18s %s\n' 'GCC version:' "${GCC_VERSION}"
printf '%-18s %s\n' 'GCC target:' "${GCC_TARGET}"
printf '%-18s %s\n' 'Readelf:' "${READELF}"
printf '%-18s %s\n' 'Architecture:' "${ARCH}"
printf '%-18s %s\n' 'ABI:' "${ABI}"
printf '%-18s %s\n' 'Base ISA:' "${BASE_MARCH}"
if [[ -n "${GCC_CONFIG_ISA_SPEC}" ]]; then
    printf '%-18s %s\n' 'Configured ISA spec:' "${GCC_CONFIG_ISA_SPEC}"
else
    printf '%-18s %s\n' 'Configured ISA spec:' '(not explicit in GCC configure flags)'
fi
printf '%-18s %s\n' 'Full ISA probe:' "${ARCH} ${ABI} -> ${MULTI_DIR}"
printf '%-18s %s\n' 'Selected libgcc:' "${LIBGCC}"
printf '%-18s %s\n' 'Map file:' "${MAP_FILE}"
printf '%-18s %s\n' 'ELF file:' "${ELF_FILE}"

heading 'Compiler/assembler ISA attribute probe'
PROBE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/peek-elf.XXXXXX")"
trap 'rm -rf -- "${PROBE_DIR}"' EXIT
PROBE_SOURCE="${PROBE_DIR}/probe.c"
PROBE_OBJECT="${PROBE_DIR}/probe.o"
printf '%s\n' 'void peek_elf_probe(void) {}' >"${PROBE_SOURCE}"

PROBE_ARCHES=''
PROBE_EXTENSIONS=''
if "${CC}" "${ARCH}" "${ABI}" -ffreestanding -fno-builtin -c "${PROBE_SOURCE}" -o "${PROBE_OBJECT}" >/dev/null 2>&1; then
    PROBE_ARCHES="$(arch_attributes "${PROBE_OBJECT}" || true)"
    if [[ -n "${PROBE_ARCHES}" ]]; then
        info "Exact-flag probe object RISC-V architecture attribute(s):"
        while IFS= read -r line; do
            printf '       Tag_RISCV_arch: "%s"\n' "${line}"
        done <<<"${PROBE_ARCHES}"

        PROBE_EXTENSIONS="$(extensions_for_arch_list <<<"${PROBE_ARCHES}")"
        PROBE_EXTRA_EXTENSIONS="$(comm -13 <(printf '%s\n' "${EFFECTIVE_REQUESTED_EXTENSIONS}") <(printf '%s\n' "${PROBE_EXTENSIONS}"))"
        PROBE_MISSING_EXTENSIONS="$(comm -23 <(printf '%s\n' "${REQUESTED_EXTENSIONS}") <(printf '%s\n' "${PROBE_EXTENSIONS}"))"

        if [[ -n "${PROBE_EXTRA_EXTENSIONS}" ]]; then
            warn "The exact-flag compiler probe advertises extension(s) outside the requested ISA and its known implications: $(join_lines "${PROBE_EXTRA_EXTENSIONS}")"
        else
            pass 'Exact-flag probe has no unexpected ISA extensions.'
        fi

        if [[ -n "${PROBE_MISSING_EXTENSIONS}" ]]; then
            info "The exact-flag probe does not spell out requested extension(s): $(join_lines "${PROBE_MISSING_EXTENSIONS}")"
            info "If the final ELF omits the same extension names, that omission is consistent with this toolchain's own attribute emission and is not by itself evidence that build flags were dropped."
        else
            pass 'Exact-flag probe spells out every explicitly requested extension.'
        fi
    else
        warn 'Exact-flag compiler probe produced no Tag_RISCV_arch attribute.'
    fi
else
    warn "Could not compile the exact-flag ISA probe with ${ARCH} ${ABI}."
fi

if has_line 'm' "${REQUESTED_EXTENSIONS}" && has_line 'zmmul' "${PROBE_EXTENSIONS}"; then
    info 'Probe includes zmmul because M implies Zmmul; this is expected and is not an ISA mismatch.'
fi

if [[ "${GCC_CONFIG_ISA_SPEC}" == '2.2' ]]; then
    if has_line 'zicsr' "${REQUESTED_EXTENSIONS}" || has_line 'zifencei' "${REQUESTED_EXTENSIONS}"; then
        info 'GCC was configured for RISC-V ISA spec 2.2. In that older ISA model, CSR and FENCE.I instructions were part of the base I ISA rather than separately advertised as Zicsr/Zifencei.'
        info 'Therefore, omission of zicsr/zifencei from this compiler probe is expected for this toolchain and should not be treated as evidence that those instructions are unavailable.'
    fi
fi

heading 'Multilib selection diagnostics'
if [[ -n "${FULL_EXACT_MULTILIB}" ]]; then
    pass "An exact installed multilib exists for ${MARCH}/${ABI_NAME}: ${FULL_EXACT_MULTILIB}"
else
    warn "No exact installed multilib advertises ${MARCH}/${ABI_NAME}."
fi

if [[ "${MULTI_DIR}" == '.' ]]; then
    if [[ "${MARCH}" == "${BASE_MARCH}" ]]; then
        info "GCC selected the default multilib (.) for ${MARCH}/${ABI_NAME}."
    else
        warn "GCC selected the default multilib (.) for the extended ISA ${MARCH}/${ABI_NAME}."
        info "The requested ISA adds extensions beyond base ISA ${BASE_MARCH}."
    fi
else
    pass "GCC selected ISA-specific multilib: ${MULTI_DIR}"
fi

if [[ "${BASE_MARCH}" != "${MARCH}" ]]; then
    if [[ -n "${BASE_INSTALLED_MULTILIB}" ]]; then
        info "Installed base-ISA multilib for ${BASE_MARCH}/${ABI_NAME}: ${BASE_INSTALLED_MULTILIB}"
    else
        info "No exact installed base-ISA multilib advertises ${BASE_MARCH}/${ABI_NAME}."
    fi

    if [[ -n "${BASE_MULTI_DIR}" ]]; then
        printf '%-18s %s\n' 'Base probe:' "-march=${BASE_MARCH} ${ABI} -> ${BASE_MULTI_DIR}"
        [[ -n "${BASE_LIBGCC}" ]] && printf '%-18s %s\n' 'Base libgcc:' "${BASE_LIBGCC}"

        if [[ "${MULTI_DIR}" == '.' && "${BASE_MULTI_DIR}" != '.' ]]; then
            warn "Selection changes from '${BASE_MULTI_DIR}' for base ISA ${BASE_MARCH} to '.' when the requested Z extensions are added."
            info "Do not assume this GCC is using the ${BASE_MULTI_DIR} library implementation for ${MARCH}."
        elif [[ "${MULTI_DIR}" == "${BASE_MULTI_DIR}" ]]; then
            pass "Full-ISA and base-ISA probes select the same multilib: ${MULTI_DIR}"
        else
            info "Full-ISA probe selects '${MULTI_DIR}'; base-ISA probe selects '${BASE_MULTI_DIR}'."
        fi
    else
        warn "Could not run the base-ISA multilib probe for ${BASE_MARCH}/${ABI_NAME}."
    fi
fi

heading 'Available GCC multilibs'
printf '%s\n' "${MULTILIBS}"

if [[ -n "${BASE_LIBGCC}" && -f "${BASE_LIBGCC}" && "${BASE_LIBGCC}" != "${LIBGCC}" ]]; then
    heading 'Selected vs base-ISA libgcc comparison'
    printf '%-18s %s\n' 'Full ISA libgcc:' "${LIBGCC}"
    printf '%-18s %s\n' 'Base ISA libgcc:' "${BASE_LIBGCC}"

    BASE_LIBGCC_ARCHES="$(arch_attributes "${BASE_LIBGCC}" || true)"
    if [[ -n "${BASE_LIBGCC_ARCHES}" ]]; then
        info "Base-ISA libgcc RISC-V architecture attribute(s):"
        while IFS= read -r line; do
            printf '       Tag_RISCV_arch: "%s"\n' "${line}"
        done <<<"${BASE_LIBGCC_ARCHES}"
    else
        info "No Tag_RISCV_arch attributes were found in the base-ISA libgcc.a."
    fi

    info "The full ISA request and base ISA probe resolve to different libgcc archives."
fi

heading 'libgcc.a use in linker map'
MAP_LIBGCC_LINES="$(grep -n -m 40 -- 'libgcc\.a' "${MAP_FILE}" || true)"
if [[ -n "${MAP_LIBGCC_LINES}" ]]; then
    printf '%s\n' "${MAP_LIBGCC_LINES}"
else
    warn "No libgcc.a references were found in the linker map."
fi

MAP_LIBGCC_LOADS="$({
    awk '/LOAD[[:space:]].*libgcc\.a/ {
        line = $0
        sub(/^.*LOAD[[:space:]]+/, "", line)
        print line
    }' "${MAP_FILE}"
} | sort -u)"

if [[ -n "${MAP_LIBGCC_LOADS}" ]]; then
    if grep -Fx -- "${LIBGCC}" <<<"${MAP_LIBGCC_LOADS}" >/dev/null; then
        pass "The linker map LOAD entry matches GCC's selected libgcc.a."
    else
        warn "The linker map does not LOAD GCC's currently selected libgcc.a: ${LIBGCC}"
        info "libgcc.a LOAD path(s) recorded in the map:"
        while IFS= read -r line; do
            printf '       %s\n' "${line}"
        done <<<"${MAP_LIBGCC_LOADS}"
    fi
fi

MAP_LIBGCC_MEMBERS="$(grep -oE 'libgcc\.a\([^)]*\)' "${MAP_FILE}" | sort -u || true)"
if [[ -n "${MAP_LIBGCC_MEMBERS}" ]]; then
    info "libgcc archive member references visible in the map:"
    while IFS= read -r line; do
        printf '       %s\n' "${line}"
    done <<<"${MAP_LIBGCC_MEMBERS}"
else
    info "No individual libgcc.a(member.o) references are visible in this map."
fi

heading 'RISC-V architecture attributes in selected libgcc.a'
LIBGCC_ARCHES="$(arch_attributes "${LIBGCC}" || true)"
if [[ -n "${LIBGCC_ARCHES}" ]]; then
    while IFS= read -r line; do
        printf 'Tag_RISCV_arch: "%s"\n' "${line}"
    done <<<"${LIBGCC_ARCHES}"
else
    warn "No Tag_RISCV_arch attributes were found in selected libgcc.a."
fi

if [[ -n "${LIBGCC_ARCHES}" ]]; then
    LIBGCC_EXTENSIONS="$(extensions_for_arch_list <<<"${LIBGCC_ARCHES}")"
    LIBGCC_EXTRA_EXTENSIONS="$(comm -13 <(printf '%s\n' "${EFFECTIVE_REQUESTED_EXTENSIONS}") <(printf '%s\n' "${LIBGCC_EXTENSIONS}"))"

    if [[ -n "${LIBGCC_EXTRA_EXTENSIONS}" ]]; then
        warn "Selected libgcc.a advertises ISA extension(s) not requested by ${ARCH}: $(join_lines "${LIBGCC_EXTRA_EXTENSIONS}")"
        info "Archive attributes describe archive members; only members extracted by the linker can affect the final ELF."
    else
        pass "Selected libgcc.a does not advertise extensions outside the requested ISA."
    fi
fi

heading 'Final ELF diagnostics'
if [[ ! -f "${ELF_FILE}" ]]; then
    warn "Final ELF not found: ${ELF_FILE}"
    info "Map/libgcc diagnostics are still valid, but final linked ISA attributes could not be checked."
else
    ELF_HEADER="$("${READELF}" -h "${ELF_FILE}")"
    printf '%s\n' "${ELF_HEADER}" |
        awk -F: '/^[[:space:]]*(Class|Machine|Entry point address|Flags):/ {
            key = $1
            value = $2
            sub(/^[[:space:]]+/, "", key)
            sub(/^[[:space:]]+/, "", value)
            printf "%-18s %s\n", key ":", value
        }'

    ELF_CLASS="$(awk -F: '/^[[:space:]]*Class:/ { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2 }' <<<"${ELF_HEADER}")"
    ELF_MACHINE="$(awk -F: '/^[[:space:]]*Machine:/ { sub(/^[[:space:]]+/, "", $2); print $2 }' <<<"${ELF_HEADER}")"
    ELF_FLAGS="$(awk -F: '/^[[:space:]]*Flags:/ { sub(/^[[:space:]]+/, "", $2); print $2 }' <<<"${ELF_HEADER}")"

    if [[ "${MARCH}" == rv32* && "${ELF_CLASS}" == ELF32 ]]; then
        pass "Final ELF class is ELF32 as requested by ${MARCH}."
    elif [[ "${MARCH}" == rv64* && "${ELF_CLASS}" == ELF64 ]]; then
        pass "Final ELF class is ELF64 as requested by ${MARCH}."
    else
        warn "Final ELF class '${ELF_CLASS}' does not match requested architecture '${MARCH}'."
    fi

    if [[ "${ELF_MACHINE}" == *RISC-V* ]]; then
        pass "Final ELF machine is RISC-V."
    else
        warn "Final ELF machine is '${ELF_MACHINE}', expected RISC-V."
    fi

    case "${ABI_NAME}" in
        ilp32|ilp32e|lp64)
            EXPECTED_FLOAT_ABI='soft-float ABI'
            ;;
        ilp32f|lp64f)
            EXPECTED_FLOAT_ABI='single-float ABI'
            ;;
        ilp32d|lp64d)
            EXPECTED_FLOAT_ABI='double-float ABI'
            ;;
        *)
            EXPECTED_FLOAT_ABI=''
            ;;
    esac

    if [[ -n "${EXPECTED_FLOAT_ABI}" ]]; then
        if [[ "${ELF_FLAGS}" == *"${EXPECTED_FLOAT_ABI}"* ]]; then
            pass "Final ELF ABI flags match ${ABI}: ${EXPECTED_FLOAT_ABI}."
        else
            warn "Final ELF flags do not advertise the ABI expected for ${ABI}: ${EXPECTED_FLOAT_ABI}."
            info "ELF flags: ${ELF_FLAGS}"
        fi
    fi

    if grep -Fx -- 'c' <<<"${REQUESTED_EXTENSIONS}" >/dev/null; then
        if [[ "${ELF_FLAGS}" == *RVC* ]]; then
            pass "Final ELF RVC flag is consistent with requested C extension."
        else
            info "C is requested, but the final ELF RVC flag is not set; this can be valid if no linked code uses compressed instructions."
        fi
    elif [[ "${ELF_FLAGS}" == *RVC* ]]; then
        warn "Final ELF has the RVC flag set even though C is not present in ${ARCH}."
    fi

    ELF_ARCHES="$(arch_attributes "${ELF_FILE}" || true)"
    if [[ -n "${ELF_ARCHES}" ]]; then
        info "Final ELF RISC-V architecture attribute(s):"
        while IFS= read -r line; do
            printf '       Tag_RISCV_arch: "%s"\n' "${line}"
        done <<<"${ELF_ARCHES}"

        ELF_EXTENSIONS="$(extensions_for_arch_list <<<"${ELF_ARCHES}")"
        ELF_EXTRA_EXTENSIONS="$(comm -13 <(printf '%s\n' "${EFFECTIVE_REQUESTED_EXTENSIONS}") <(printf '%s\n' "${ELF_EXTENSIONS}"))"
        ELF_MISSING_EXTENSIONS="$(comm -23 <(printf '%s\n' "${REQUESTED_EXTENSIONS}") <(printf '%s\n' "${ELF_EXTENSIONS}"))"

        if [[ -n "${ELF_EXTRA_EXTENSIONS}" ]]; then
            warn "Final ELF advertises ISA extension(s) outside ${ARCH} and its known implications: $(join_lines "${ELF_EXTRA_EXTENSIONS}")"
            info "This is stronger evidence than the archive-level warning because these attributes are present on the linked ELF."
        else
            pass "Final ELF does not advertise ISA extensions outside the requested ISA or its known implications."
        fi

        if [[ -n "${ELF_MISSING_EXTENSIONS}" ]]; then
            if [[ -n "${PROBE_EXTENSIONS}" ]]; then
                ELF_MISSING_BUT_PROBE_HAS="$(comm -12 <(printf '%s\n' "${ELF_MISSING_EXTENSIONS}") <(printf '%s\n' "${PROBE_EXTENSIONS}"))"
                ELF_MISSING_AND_PROBE_MISSING="$(comm -23 <(printf '%s\n' "${ELF_MISSING_EXTENSIONS}") <(printf '%s\n' "${PROBE_EXTENSIONS}"))"

                if [[ -n "${ELF_MISSING_BUT_PROBE_HAS}" ]]; then
                    warn "Final ELF omits requested extension(s) that the exact-flag probe DOES advertise: $(join_lines "${ELF_MISSING_BUT_PROBE_HAS}")"
                    info "This may indicate inconsistent compile/link flags or attribute merging; inspect the build commands for ${ARCH}."
                fi

                if [[ -n "${ELF_MISSING_AND_PROBE_MISSING}" ]]; then
                    info "Final ELF omits requested extension name(s) also omitted by the exact-flag toolchain probe: $(join_lines "${ELF_MISSING_AND_PROBE_MISSING}")"
                    info 'Treat these as toolchain attribute spelling/canonicalization behavior unless another check shows the requested instructions are unavailable.'
                fi
            else
                warn "Final ELF does not advertise requested ISA extension(s): $(join_lines "${ELF_MISSING_EXTENSIONS}")"
                info "The exact-flag probe was unavailable, so the omission could not be classified."
            fi
        else
            pass "Final ELF advertises every extension explicitly requested by ${ARCH}."
        fi
    else
        warn "No Tag_RISCV_arch attribute was found in the final ELF."
    fi
fi

heading 'Diagnostic summary'
if ((WARNING_COUNT == 0)); then
    pass 'No suspicious conditions detected.'
else
    printf '[WARN] Completed with %d warning(s). Review the WARN lines above.\n' "${WARNING_COUNT}"
    info 'Warnings are diagnostic only; this script exits successfully unless a required tool or input file is missing.'
fi
