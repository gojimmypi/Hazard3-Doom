#!/bin/bash
# -----------------------------------------------------------------------------
# File:        full-clean.sh
# Path:        scripts/full-clean.sh
#
# Project:     Hazard3-Doom
# Purpose:     Clean supported FPGA synthesis outputs and remove the
#              repository build tree.
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
#
# Full cleanup behavior:
#
# Removes entire Hazard3-Doom/build
#
# - Runs ShellCheck on this script when ShellCheck is installed and stops if
#   linting fails.
# - Accepts -n/--dry-run to report every cleanup operation without modifying
#   files, and -h/--help to display usage.
# - Resolves the Hazard3-Doom repository root from this script's location.
# - Uses third_party/Hazard3 by default, or the checkout selected through
#   HAZARD3_ROOT.
# - Refuses to operate on "/" or on a directory that does not contain the
#   expected scripts, doom, and src directories.
# - Runs the clean targets from ULX3S.mk, ULX3S_12F.mk, and ULX4M_LD_85F.mk
#   when those Makefiles exist; missing Makefiles are reported and skipped.
# - The shared ECP5 clean rules remove each target's JSON, ASC, BIT, and
#   synthesized Verilog files, along with synth.log, pnr.log, pnr*.log, and
#   pnr_try*.asc from the Hazard3 example_soc/synth directory.
# - The ULX3S 12F clean rule additionally removes its CONFIG, SVF, and
#   memory-profile files from the Hazard3 synthesis directory.
# - Removes the complete Hazard3-Doom build/ tree, including firmware,
#   Doom images, FPGA outputs, timing stamps, routing sweeps, integration-test
#   artifacts, logs, and other generated files stored below build/.
# - Guards the recursive removal so that only the repository's exact build/
#   path can be selected.
# - Does not reset Git repositories or remove submodule source, WAD files, or
#   checked-in LiteDRAM sources.
#
# Removed from third_party/Hazard3/example_soc/synth/
#
#   fpga_ulx3s.json
#   fpga_ulx3s.asc
#   fpga_ulx3s.bit
#   fpga_ulx3s_synth.v
#
#   fpga_ulx3s_85f.json
#   fpga_ulx3s_85f.asc
#   fpga_ulx3s_85f.bit
#   fpga_ulx3s_85f_synth.v
#   fpga_ulx3s_85f.config
#   fpga_ulx3s_85f.svf
#   fpga_ulx3s_85f.memory-profile
#
#   fpga_ulx3s_12f.json
#   fpga_ulx3s_12f.asc
#   fpga_ulx3s_12f.bit
#   fpga_ulx3s_12f_synth.v
#   fpga_ulx3s_12f.config
#   fpga_ulx3s_12f.svf
#   fpga_ulx3s_12f.memory-profile
#
#   fpga_ulx4m_ld.json
#   fpga_ulx4m_ld.asc
#   fpga_ulx4m_ld.bit
#   fpga_ulx4m_ld_synth.v
#
#   synth.log
#   pnr.log
#   pnr*.log
#   pnr_try*.asc
#
# Note: the pinned shared ECP5 clean rules do not remove CONFIG or SVF files
# produced directly in example_soc/synth for the ULX3S 85F or ULX4M-LD targets.

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
