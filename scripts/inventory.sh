#!/usr/bin/env bash
set -euo pipefail

# Inventory Git-tracked files under a selected directory and generate stable SHA-256
# identification manifests for integrity verification, reproducibility, and release auditing.
#
# Only paths present in the current Git index are inventoried. Ignored and
# untracked local files, including locally installed toolchains, are skipped.
# The generated manifest files are excluded from their own inventory so that
# repeated runs over an unchanged Git index produce identical content.

usage()
{
    cat <<'USAGE'
Usage: ./scripts/inventory.sh [--check] DIRECTORY

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
  --check    Regenerate temporary manifests and verify they exactly match the
             existing INVENTORY files. No manifest files are changed.
  -h, --help Show this help text.

Examples:
  ./scripts/inventory.sh bin
  ./scripts/inventory.sh third_party/Hazard3
  ./scripts/inventory.sh --check bin
USAGE
}

mode="write"
target_arg=""

while [[ $# -gt 0 ]]; do
    case "$1" in
    --check)
        mode="check"
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

if [[ -z "${target_arg}" ]]; then
    echo "Missing target directory." >&2
    usage >&2
    exit 2
fi

if ! command -v git >/dev/null 2>&1; then
    echo "Missing required tool: git" >&2
    exit 1
fi

if [[ "${target_arg}" = /* ]]; then
    TARGET_DIR="${target_arg}"
else
    TARGET_DIR="${PWD}/${target_arg}"
fi

if ! TARGET_DIR="$(cd -- "${TARGET_DIR}" 2>/dev/null && pwd -P)"; then
    echo "Target directory does not exist: ${target_arg}" >&2
    exit 1
fi

if ! REPO_ROOT="$(git -C "${TARGET_DIR}" rev-parse --show-toplevel 2>/dev/null)"; then
    echo "Target directory must be inside a Git checkout: ${target_arg}" >&2
    exit 1
fi

TARGET_PREFIX="$(git -C "${TARGET_DIR}" rev-parse --show-prefix)"

OUTPUT_PREFIX="${TARGET_DIR}/INVENTORY"
TSV_OUT="${OUTPUT_PREFIX}.tsv"
SHA_OUT="${OUTPUT_PREFIX}.sha256"
MD_OUT="${OUTPUT_PREFIX}.md"

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
    fpga_*.bit|hazard3-*.elf|hazard3-*.map|hazard3-*.h3d)
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
    *.h3d)
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
    mktemp "${TARGET_DIR}/.inventory.XXXXXX"
}

TSV_TMP="$(make_temp_file)"
SHA_TMP="$(make_temp_file)"
MD_TMP="$(make_temp_file)"
LIST_TMP="$(make_temp_file)"

cleanup()
{
    rm -f -- "${TSV_TMP}" "${SHA_TMP}" "${MD_TMP}" "${LIST_TMP}"
}
trap cleanup EXIT

SHA256_TOOL="$(find_sha256_tool)"

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
        rel_path="${repo_path#${TARGET_PREFIX}}"
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
        printf '| `%s` | %s | `%s` | %s | %s |\n' \
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
            echo "Missing inventory manifest: ${committed#${TARGET_DIR}/}" >&2
            status=1
        elif ! cmp -s -- "${generated}" "${committed}"; then
            echo "Inventory manifest is stale: ${committed#${TARGET_DIR}/}" >&2
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
