#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
HAZARD3_ROOT="${HAZARD3_ROOT:-${ROOT_DIR}/third_party/Hazard3}"
SYNTH_DIR="${HAZARD3_ROOT}/example_soc/synth"
BUILD_DIR="${ROOT_DIR}/build"
DRY_RUN=0

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

usage()
{
    cat <<EOF
Usage: $(basename "$0") [--dry-run]

Remove all generated ULX3S, ULX4M-LD, monitor, and Doom image build outputs.

Options:
  -n, --dry-run  Show the cleanup operations without changing files.
  -h, --help     Show this help text.

HAZARD3_ROOT may select a Hazard3 checkout other than:
  ${ROOT_DIR}/third_party/Hazard3
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run)
            DRY_RUN=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

[[ "${ROOT_DIR}" != "/" ]] || {
    echo "Refusing to clean filesystem root." >&2
    exit 1
}

[[ -d "${ROOT_DIR}/scripts" && -d "${ROOT_DIR}/doom" && -d "${ROOT_DIR}/src" ]] || {
    echo "Refusing to clean an unexpected directory: ${ROOT_DIR}" >&2
    echo "This script must remain in the Hazard3-Doom scripts directory." >&2
    exit 1
}

run_make_clean()
{
    local makefile="$1"

    if [[ ! -f "${SYNTH_DIR}/${makefile}" ]]; then
        printf 'Skipping missing Hazard3 makefile: %s\n' "${SYNTH_DIR}/${makefile}"
        return
    fi

    if [[ "${DRY_RUN}" -eq 1 ]]; then
        printf 'Would run: make -C %q -f %q clean\n' "${SYNTH_DIR}" "${makefile}"
    else
        printf 'Cleaning Hazard3 target with %s...\n' "${makefile}"
        make -C "${SYNTH_DIR}" -f "${makefile}" clean
    fi
}

remove_build_tree()
{
    local path="$1"

    [[ "${path}" == "${ROOT_DIR}/build" ]] || {
        echo "Refusing unexpected cleanup path: ${path}" >&2
        exit 1
    }

    if [[ ! -e "${path}" && ! -L "${path}" ]]; then
        printf 'Already clean: %s\n' "${path}"
        return
    fi

    if [[ "${DRY_RUN}" -eq 1 ]]; then
        printf 'Would remove: %s\n' "${path}"
    else
        printf 'Removing generated build tree: %s\n' "${path}"
        rm -rf -- "${path}"
    fi
}

run_make_clean ULX3S.mk
run_make_clean ULX3S_12F.mk
run_make_clean ULX4M_LD_85F.mk
remove_build_tree "${BUILD_DIR}"

if [[ "${DRY_RUN}" -eq 1 ]]; then
    printf 'Dry run complete. No files were removed.\n'
else
    printf 'Full ULX3S/ULX4M-LD Doom clean complete.\n'
fi

printf 'Preserved submodules, WAD files, and checked-in LiteDRAM sources.\n'
