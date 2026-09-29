#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File:        inventory.sh
# Path:        scripts/inventory.sh
#
# Project:     Hazard3-Doom
# Purpose:     Generate deterministic SHA-256 inventories for Git-tracked
#              files under a selected directory.
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

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
SELF_PATH="${SCRIPT_DIR}/$(basename -- "${BASH_SOURCE[0]}")"
SELF_NAME="${SELF_PATH##*/}"

# Inventory Git-tracked files under a selected directory and generate stable SHA-256
# identification manifests for integrity verification, reproducibility, and release auditing.
#
# Only paths present in the current Git index are inventoried. Ignored and
# untracked local files, including locally installed toolchains, are skipped.
# The generated manifest files are excluded from their own inventory so that
# repeated runs over an unchanged Git index produce identical content.

# Run shellcheck to ensure this is a good script.
# Specify the executable shell checker you want to use:
MY_SHELLCHECK="shellcheck"

# Check if the executable is available in the PATH. Skip this lint pass for
# lightweight --check-file calls made automatically by the other scripts.
if [[ "${1:-}" != "--check-file" ]]; then
    if command -v "$MY_SHELLCHECK" >/dev/null 2>&1; then
        # Run your command here
        shellcheck "$0" || exit 1
    else
        echo "$MY_SHELLCHECK is not installed. Please install it if changes to this script have been made."
    fi
fi

usage()
{
    cat <<'USAGE'
Usage:
  ./scripts/inventory.sh DIRECTORY
  ./scripts/inventory.sh --check DIRECTORY
  ./scripts/inventory.sh --check-file FILE

Inventory Git-tracked files under DIRECTORY and write the generated manifests
into that same directory:

  DIRECTORY/INVENTORY.tsv
  DIRECTORY/INVENTORY.sha256
  DIRECTORY/INVENTORY.md

The SHA-256 manifest can also be verified directly with:

  (cd DIRECTORY && sha256sum -c INVENTORY.sha256)

Only files present in the current Git index are inventoried. Ignored and
untracked files under DIRECTORY are not read or hashed.

Options:
  --check       Regenerate temporary manifests and verify they exactly match the
                existing INVENTORY files. No manifest files are changed.
  --check-file  Compare FILE with its entry in the nearest applicable
                INVENTORY.sha256. No manifest files are changed.
  -h, --help    Show this help text.

Examples:
  ./scripts/inventory.sh bin
  ./scripts/inventory.sh third_party/Hazard3
  ./scripts/inventory.sh --check bin
  ./scripts/inventory.sh --check-file scripts/build-ulx3s-12f-doom.sh
USAGE
}

mode="write"
target_arg=""
check_file_arg=""

while [[ $# -gt 0 ]]; do
    case "$1" in
    --check)
        if [[ "${mode}" != "write" ]]; then
            echo "Only one mode option may be specified." >&2
            usage >&2
            exit 2
        fi
        mode="check"
        shift
        ;;
    --check-file)
        if [[ "${mode}" != "write" ]]; then
            echo "Only one mode option may be specified." >&2
            usage >&2
            exit 2
        fi
        mode="check-file"
        shift
        if [[ $# -eq 0 ]]; then
            echo "Missing file argument for --check-file." >&2
            usage >&2
            exit 2
        fi
        check_file_arg="$1"
        shift
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    --)
        shift
        if [[ $# -gt 0 ]]; then
            target_arg="$1"
            shift
        fi
        break
        ;;
    -* )
        echo "Unknown option: $1" >&2
        usage >&2
        exit 2
        ;;
    *)
        if [[ -n "${target_arg}" ]]; then
            echo "Too many directory arguments." >&2
            usage >&2
            exit 2
        fi
        target_arg="$1"
        shift
        ;;
    esac
done

if [[ $# -gt 0 ]]; then
    echo "Too many arguments." >&2
    usage >&2
    exit 2
fi

if [[ "${mode}" == "check-file" ]]; then
    if [[ -n "${target_arg}" ]]; then
        echo "A directory argument cannot be used with --check-file." >&2
        usage >&2
        exit 2
    fi
else
    if [[ -z "${target_arg}" ]]; then
        echo "Missing target directory." >&2
        usage >&2
        exit 2
    fi
fi

if ! command -v git >/dev/null 2>&1; then
    echo "Missing required tool: git" >&2
    exit 1
fi

if [[ "${mode}" == "check-file" ]]; then
    if [[ "${check_file_arg}" = /* ]]; then
        CHECK_FILE_PATH="${check_file_arg}"
    else
        CHECK_FILE_PATH="${PWD}/${check_file_arg}"
    fi

    check_file_dir="$(dirname -- "${CHECK_FILE_PATH}")"
    check_file_name="$(basename -- "${CHECK_FILE_PATH}")"
    if ! check_file_dir="$(cd -- "${check_file_dir}" 2>/dev/null && pwd -P)"; then
        echo "File directory does not exist: ${check_file_arg}" >&2
        exit 1
    fi
    CHECK_FILE_PATH="${check_file_dir}/${check_file_name}"

    if [[ ! -f "${CHECK_FILE_PATH}" ]]; then
        echo "File does not exist or is not a regular file: ${check_file_arg}" >&2
        exit 1
    fi

    TARGET_DIR="${check_file_dir}"
else
    if [[ "${target_arg}" = /* ]]; then
        TARGET_DIR="${target_arg}"
    else
        TARGET_DIR="${PWD}/${target_arg}"
    fi

    if ! TARGET_DIR="$(cd -- "${TARGET_DIR}" 2>/dev/null && pwd -P)"; then
        echo "Target directory does not exist: ${target_arg}" >&2
        exit 1
    fi
fi

if ! REPO_ROOT="$(git -C "${TARGET_DIR}" rev-parse --show-toplevel 2>/dev/null)"; then
    if [[ "${mode}" == "check-file" ]]; then
        echo "File must be inside a Git checkout: ${check_file_arg}" >&2
    else
        echo "Target directory must be inside a Git checkout: ${target_arg}" >&2
    fi
    exit 1
fi

if [[ "${mode}" == "check-file" ]]; then
    case "${CHECK_FILE_PATH}" in
    "${REPO_ROOT}"/*)
        ;;
    *)
        echo "File must be inside the current Git checkout: ${check_file_arg}" >&2
        exit 1
        ;;
    esac
else
    VERSION_FILE="${REPO_ROOT}/VERSION"
    if [[ ! -r "${VERSION_FILE}" ]]; then
        echo "Missing Hazard3-Doom VERSION file: ${VERSION_FILE}" >&2
        exit 1
    fi
    PROJECT_VERSION="$(tr -d '\r\n' < "${VERSION_FILE}")"
    if [[ ! "${PROJECT_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$ ]]; then
        echo "Invalid Hazard3-Doom VERSION value: ${PROJECT_VERSION}" >&2
        exit 1
    fi

    TARGET_PREFIX="$(git -C "${TARGET_DIR}" rev-parse --show-prefix)"

    OUTPUT_PREFIX="${TARGET_DIR}/INVENTORY"
    TSV_OUT="${OUTPUT_PREFIX}.tsv"
    SHA_OUT="${OUTPUT_PREFIX}.sha256"
    MD_OUT="${OUTPUT_PREFIX}.md"
    TEMP_DIR="${REPO_ROOT}/build/inventory-tmp"
fi

find_sha256_tool()
{
    if command -v sha256sum >/dev/null 2>&1; then
        echo "sha256sum"
    elif command -v shasum >/dev/null 2>&1; then
        echo "shasum"
    elif command -v openssl >/dev/null 2>&1; then
        echo "openssl"
    else
        echo "Missing SHA-256 tool: install sha256sum, shasum, or openssl." >&2
        exit 1
    fi
}

sha256_file()
{
    local path="$1"

    case "${SHA256_TOOL}" in
    sha256sum)
        sha256sum -- "${path}" | awk '{print $1}'
        ;;
    shasum)
        shasum -a 256 -- "${path}" | awk '{print $1}'
        ;;
    openssl)
        openssl dgst -sha256 -r -- "${path}" | awk '{print $1}'
        ;;
    *)
        echo "Internal error: unsupported SHA-256 tool ${SHA256_TOOL}" >&2
        exit 1
        ;;
    esac
}

check_self_inventory_signature()
{
    local inventory_file="${SCRIPT_DIR}/INVENTORY.sha256"
    local recorded_hash=""
    local self_hash=""

    if [[ ! -r "${inventory_file}" ]]; then
        printf 'Self SHA-256: inventory unavailable (%s)\n' "${inventory_file}"
        return 0
    fi

    if ! recorded_hash="$(
        awk -v name="${SELF_NAME}" '
            $2 == name {
                hash = $1
                matches++
            }
            END {
                if (matches != 1) {
                    exit 1
                }
                print hash
            }
        ' "${inventory_file}"
    )"; then
        printf 'Self SHA-256: signature unavailable for %s in %s\n' \
            "${SELF_NAME}" "${inventory_file}"
        return 0
    fi

    self_hash="$(sha256_file "${SELF_PATH}")"

    if [[ "${self_hash}" == "${recorded_hash}" ]]; then
        printf 'Self SHA-256: SAME (%s matches INVENTORY.sha256)\n' "${SELF_NAME}"
    else
        printf 'Self SHA-256: DIFFERENT (%s does not match INVENTORY.sha256)\n' "${SELF_NAME}"
        printf '  inventory: %s\n' "${recorded_hash}"
        printf '  current:   %s\n' "${self_hash}"
    fi
}

check_file_inventory_signature()
{
    local file_path="$1"
    local inventory_dir
    local inventory_file
    local relative_path
    local line
    local line_hash
    local line_path
    local recorded_hash=""
    local current_hash
    local matches
    local parent_dir
    local repo_relative_path

    inventory_dir="$(dirname -- "${file_path}")"

    while :; do
        inventory_file="${inventory_dir}/INVENTORY.sha256"

        if [[ -r "${inventory_file}" ]]; then
            relative_path="${file_path#"${inventory_dir}/"}"
            recorded_hash=""
            matches=0

            while IFS= read -r line || [[ -n "${line}" ]]; do
                if [[ "${line}" != *"  "* ]]; then
                    continue
                fi

                line_hash="${line%%  *}"
                line_path="${line#*  }"

                if [[ "${line_path}" == "${relative_path}" ]]; then
                    recorded_hash="${line_hash}"
                    matches=$((matches + 1))
                fi
            done < "${inventory_file}"

            if [[ ${matches} -gt 1 ]]; then
                printf 'File SHA-256: signature is ambiguous for %s in %s\n' \
                    "${relative_path}" "${inventory_file}" >&2
                return 1
            fi

            if [[ ${matches} -eq 1 ]]; then
                break
            fi
        fi

        if [[ "${inventory_dir}" == "${REPO_ROOT}" ]]; then
            printf 'File SHA-256: signature unavailable for %s\n' \
                "${file_path#"${REPO_ROOT}/"}" >&2
            return 1
        fi

        parent_dir="$(dirname -- "${inventory_dir}")"
        if [[ "${parent_dir}" == "${inventory_dir}" ]]; then
            printf 'File SHA-256: signature unavailable for %s\n' \
                "${file_path#"${REPO_ROOT}/"}" >&2
            return 1
        fi
        inventory_dir="${parent_dir}"
    done

    current_hash="$(sha256_file "${file_path}")"
    repo_relative_path="${file_path#"${REPO_ROOT}/"}"

    if [[ "${current_hash}" == "${recorded_hash}" ]]; then
        printf 'File SHA-256: SAME (%s matches %s)\n' \
            "${repo_relative_path}" "${inventory_file#"${REPO_ROOT}/"}"
        return 0
    fi

    printf 'File SHA-256: DIFFERENT (%s does not match %s)\n' \
        "${repo_relative_path}" "${inventory_file#"${REPO_ROOT}/"}"
    printf '  inventory: %s\n' "${recorded_hash}"
    printf '  current:   %s\n' "${current_hash}"
    return 1
}

component_for_path()
{
    local path="$1"

    case "${path}" in
    gdb/*)
        echo "xPack GNU RISC-V Embedded GCC/GDB runtime"
        ;;
    fujprog-v48-win64.exe)
        echo "fujprog"
        ;;
    openFPGALoader.exe)
        echo "openFPGALoader"
        ;;
    openocd.exe|openocd/*)
        echo "OpenOCD"
        ;;
    putty.exe)
        echo "PuTTY"
        ;;
    zadig-*.exe)
        echo "Zadig/libwdi"
        ;;
    libftdi1.dll)
        echo "libftdi"
        ;;
    libusb-1.0.dll)
        echo "libusb"
        ;;
    fpga_*.bit|hazard3-*.elf|hazard3-*.map|hazard3-*.h3img)
        echo "Hazard3-Doom project output"
        ;;
    inventory.sh)
        echo "Hazard3-Doom repository"
        ;;
    *)
        echo "REVIEW"
        ;;
    esac
}

kind_for_path()
{
    local path="$1"

    case "${path}" in
    *.exe)
        echo "Windows executable"
        ;;
    *.dll)
        echo "Windows DLL"
        ;;
    *.elf)
        echo "ELF image"
        ;;
    *.bit)
        echo "FPGA bitstream"
        ;;
    *.h3img)
        echo "Hazard3-Doom image"
        ;;
    *.map)
        echo "Linker map"
        ;;
    *.md)
        echo "Markdown documentation"
        ;;
    *.sh)
        echo "Shell script"
        ;;
    *)
        echo "File"
        ;;
    esac
}

markdown_escape()
{
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//|/\\|}"
    printf '%s' "${value}"
}

is_generated_output()
{
    local path="$1"

    case "${path}" in
    INVENTORY.tsv|INVENTORY.sha256|INVENTORY.md)
        return 0
        ;;
    *)
        return 1
        ;;
    esac
}

make_temp_file()
{
    mkdir -p -- "${TEMP_DIR}"
    mktemp "${TEMP_DIR}/inventory.XXXXXX"
}

SHA256_TOOL="$(find_sha256_tool)"

if [[ "${mode}" == "check-file" ]]; then
    check_file_inventory_signature "${CHECK_FILE_PATH}"
    exit $?
fi

TSV_TMP="$(make_temp_file)"
SHA_TMP="$(make_temp_file)"
MD_TMP="$(make_temp_file)"
LIST_TMP="$(make_temp_file)"

cleanup()
{
    rm -f -- "${TSV_TMP}" "${SHA_TMP}" "${MD_TMP}" "${LIST_TMP}"
}
trap cleanup EXIT

check_self_inventory_signature

# Ask Git for the current index instead of walking the filesystem. This keeps
# large ignored/untracked local toolchains out of the inventory automatically.
# NUL delimiters preserve spaces and other ordinary filename characters.
if [[ -n "${TARGET_PREFIX}" ]]; then
    git -C "${REPO_ROOT}" ls-files --cached -z -- "${TARGET_PREFIX}"
else
    git -C "${REPO_ROOT}" ls-files --cached -z
fi | LC_ALL=C sort -z > "${LIST_TMP}"

printf 'path\tsize_bytes\tsha256\tcomponent\tkind\n' > "${TSV_TMP}"

file_count=0
total_bytes=0

while IFS= read -r -d '' repo_path; do
    if [[ -n "${TARGET_PREFIX}" ]]; then
        rel_path="${repo_path#"${TARGET_PREFIX}"}"
    else
        rel_path="${repo_path}"
    fi
    full_path="${REPO_ROOT}/${repo_path}"

    if [[ -n "${TARGET_PREFIX}" && "${rel_path}" == "${repo_path}" ]]; then
        echo "Unexpected Git path outside target directory: ${repo_path}" >&2
        exit 1
    fi

    if [[ -z "${rel_path}" ]]; then
        continue
    fi

    if is_generated_output "${rel_path}"; then
        continue
    fi

    if [[ ! -f "${full_path}" ]]; then
        echo "Tracked target file is missing or is not a regular file: ${rel_path}" >&2
        exit 1
    fi

    if [[ "${rel_path}" == *$'\n'* || "${rel_path}" == *$'\t'* ]]; then
        echo "Unsupported tab/newline in target filename: ${rel_path}" >&2
        exit 1
    fi

    size_before="$(wc -c < "${full_path}" | tr -d '[:space:]')"
    hash="$(sha256_file "${full_path}")"
    size_after="$(wc -c < "${full_path}" | tr -d '[:space:]')"

    if [[ "${size_before}" != "${size_after}" ]]; then
        echo "File changed while hashing: ${rel_path}" >&2
        exit 1
    fi

    component="$(component_for_path "${rel_path}")"
    kind="$(kind_for_path "${rel_path}")"

    printf '%s\t%s\t%s\t%s\t%s\n' \
        "${rel_path}" \
        "${size_before}" \
        "${hash}" \
        "${component}" \
        "${kind}" >> "${TSV_TMP}"

    # Standard sha256sum-check format. Paths are relative to the target directory.
    printf '%s  %s\n' "${hash}" "${rel_path}" >> "${SHA_TMP}"

    file_count=$((file_count + 1))
    total_bytes=$((total_bytes + size_before))
done < "${LIST_TMP}"

{
    echo "# Hazard3-Doom Inventory"
    echo
    echo "This manifest identifies every Git-tracked file under \`${TARGET_PREFIX:-.}\`,"
    echo "except the generated \`INVENTORY.*\` manifest files themselves."
    echo "Ignored and untracked local files are intentionally not inventoried."
    echo
    echo "It is intended to support integrity verification, reproducibility, release"
    echo "auditing, and exact identification of tracked artifacts. A hash identifies"
    echo "the bytes in a file; it does not by itself establish provenance or intent."
    echo
    echo "Project version: v${PROJECT_VERSION}"
    echo
    echo "Git source: current index (\`git ls-files --cached\`)"
    echo
    echo "Files inventoried: ${file_count}"
    echo
    echo "Total bytes: ${total_bytes}"
    echo
    echo "## Verification"
    echo
    echo '```bash'
    if [[ -n "${TARGET_PREFIX}" ]]; then
        printf '(cd %q && sha256sum -c INVENTORY.sha256)\n' "${TARGET_PREFIX%/}"
    else
        echo 'sha256sum -c INVENTORY.sha256'
    fi
    echo '```'
    echo
    echo "The \`component\` column is an identification aid. Any entry marked \`REVIEW\`"
    echo "should be identified before a public release."
    echo
    echo "| Path | Bytes | SHA-256 | Component | Kind |"
    echo "|---|---:|---|---|---|"

    tail -n +2 "${TSV_TMP}" | while IFS=$'\t' read -r path bytes hash component kind; do
        printf "| \`%s\` | %s | \`%s\` | %s | %s |\n" \
            "$(markdown_escape "${path}")" \
            "${bytes}" \
            "${hash}" \
            "$(markdown_escape "${component}")" \
            "$(markdown_escape "${kind}")"
    done
} > "${MD_TMP}"

if [[ "${mode}" == "check" ]]; then
    status=0

    for pair in \
        "${TSV_TMP}:${TSV_OUT}" \
        "${SHA_TMP}:${SHA_OUT}" \
        "${MD_TMP}:${MD_OUT}"
    do
        generated="${pair%%:*}"
        committed="${pair#*:}"

        if [[ ! -f "${committed}" ]]; then
            echo "Missing inventory manifest: ${committed#"${TARGET_DIR}"/}" >&2
            status=1
        elif ! cmp -s -- "${generated}" "${committed}"; then
            echo "Inventory manifest is stale: ${committed#"${TARGET_DIR}"/}" >&2
            status=1
        fi
    done

    if [[ ${status} -ne 0 ]]; then
        printf 'Run ./scripts/inventory.sh %q and review the regenerated manifests.\n' "${target_arg}" >&2
        exit "${status}"
    fi

    echo "inventory manifests are current (${file_count} Git-tracked files, ${total_bytes} bytes)."
    exit 0
fi

mv -f -- "${TSV_TMP}" "${TSV_OUT}"
mv -f -- "${SHA_TMP}" "${SHA_OUT}"
mv -f -- "${MD_TMP}" "${MD_OUT}"

# The moved files no longer need cleanup. Re-arm the trap for LIST_TMP only.
TSV_TMP=""
SHA_TMP=""
MD_TMP=""

printf 'Wrote inventory for %d Git-tracked files (%d bytes):\n' "${file_count}" "${total_bytes}"
printf '  %s\n' "${TSV_OUT}"
printf '  %s\n' "${SHA_OUT}"
printf '  %s\n' "${MD_OUT}"
