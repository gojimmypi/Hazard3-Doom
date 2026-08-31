#!/bin/bash
# -----------------------------------------------------------------------------
# File:        sweep-ecp5.sh
# Path:        scripts/sweep-ecp5.sh
#
# Project:     Hazard3-Doom
# Purpose:     Common local/CI entry point for board-specific ECP5 seed sweeps.
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
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
usage()
{
    cat >&2 <<EOF_USAGE
Usage: $0 TARGET SEED [SEED ...]
       $0 TARGET START-END
       $0 TARGET --all
       $0 --prepare TARGET
       $0 --print-sweep-dir TARGET
       $0 --print-netlist TARGET
       $0 --list-targets

Targets:
    ulx3s-85f
    ulx3s-12f
    ulx4m-ld-85f

Board-specific settings remain environment variables understood by the target
sweep script. Generic nextpnr tuning uses SWEEP_NEXTPNR_* variables.
EOF_USAGE
} # usage

target_script()
{
    case "$1" in
    ulx3s-85f)
        printf '%s/sweep-ulx3s-85f.sh\n' "${SCRIPT_DIR}"
        ;;
    ulx3s-12f)
        printf '%s/sweep-ulx3s-12f.sh\n' "${SCRIPT_DIR}"
        ;;
    ulx4m-ld|ulx4m-ld-85f)
        printf '%s/sweep-ulx4m-ld.sh\n' "${SCRIPT_DIR}"
        ;;
    *)
        echo "Unknown ECP5 sweep target: $1" >&2
        usage
        exit 1
        ;;
    esac
} # target_script

canonical_target()
{
    case "$1" in
    ulx4m-ld)
        printf 'ulx4m-ld-85f\n'
        ;;
    *)
        printf '%s\n' "$1"
        ;;
    esac
} # canonical_target

# Run shellcheck to ensure this is a good script.
# Specify the executable shell checker you want to use:
MY_SHELLCHECK="${MY_SHELLCHECK:-shellcheck}"

if command -v "${MY_SHELLCHECK}" >/dev/null 2>&1; then
    (
        cd -- "${REPO_ROOT}"
        "${MY_SHELLCHECK}" -x "scripts/$(basename -- "${BASH_SOURCE[0]}")"
    ) || exit 1
else
    echo "${MY_SHELLCHECK} is not installed. Please install it if changes to this script have been made."
fi

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
if (( $# == 0 )); then
    usage
    exit 1
fi

case "$1" in
--list-targets)
    printf '%s\n' ulx3s-85f ulx3s-12f ulx4m-ld-85f
    exit 0
    ;;
--prepare)
    (( $# == 2 )) || { usage; exit 1; }
    target="$(canonical_target "$2")"
    script="$(target_script "${target}")"
    SWEEP_PREPARE_ONLY=1 exec "${script}"
    ;;
--print-sweep-dir)
    (( $# == 2 )) || { usage; exit 1; }
    target="$(canonical_target "$2")"
    script="$(target_script "${target}")"
    exec "${script}" --print-sweep-dir
    ;;
--print-netlist)
    (( $# == 2 )) || { usage; exit 1; }
    target="$(canonical_target "$2")"
    case "${target}" in
    ulx3s-85f)
        printf 'third_party/Hazard3/example_soc/synth/fpga_ulx3s.json\n'
        ;;
    ulx3s-12f)
        printf 'third_party/Hazard3/example_soc/synth/fpga_ulx3s_12f.json\n'
        ;;
    ulx4m-ld-85f)
        printf 'third_party/Hazard3/example_soc/synth/fpga_ulx4m_ld.json\n'
        ;;
    esac
    exit 0
    ;;
--*)
    usage
    exit 1
    ;;
*)
    target="$(canonical_target "$1")"
    shift
    script="$(target_script "${target}")"
    exec "${script}" "$@"
    ;;
esac
