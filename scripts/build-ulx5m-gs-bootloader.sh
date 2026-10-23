#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File:        build-ulx5m-gs-bootloader.sh
# Path:        scripts/build-ulx5m-gs-bootloader.sh
#
# Project:     Hazard3-Doom
# Purpose:     Build the ULX5M-GS SERV diagnostic bootloader bitstream.
#              Offline build only; never programs FPGA SRAM or flash.
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

# See ./bootloader-serv/Makefile.ulx5m-gs for default seed setting and other build details.

usage() {
    cat <<'USAGE'
Usage: ./scripts/build-ulx5m-gs-bootloader.sh [--seed N] [--reuse-json]

By default, regenerate SERV synthesis JSON, route with the selected seed,
and assemble the .bit file using gmpack.

  --seed N       Override SERV_SEED from bootloader-serv/Makefile.ulx5m-gs.
  --reuse-json   Keep existing synthesis JSON; rerun routing and gmpack.
  -h, --help     Show this help.

Requires the verified local OSS CAD Suite 2026-07-20 Yosys/nextpnr pair.
No FPGA programming, USB access, or flash writing is performed.
USAGE
}

seed=''
reuse_json=false
while (( $# > 0 )); do
    case "$1" in
        --seed)
            if (( $# < 2 )); then
                printf 'ERROR: --seed requires a positive integer.\n' >&2
                exit 2
            fi
            seed=$2
            shift 2
            ;;
        --reuse-json)
            reuse_json=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'ERROR: unknown argument: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ -n $seed ]]; then
    if [[ ! $seed =~ ^[0-9]+$ || ${#seed} -gt 9 ]]; then
        printf 'ERROR: seed must be a positive decimal integer (at most 9 digits).\n' >&2
        exit 2
    fi
    seed=$((10#$seed))
    if (( seed < 1 )); then
        printf 'ERROR: seed must be positive.\n' >&2
        exit 2
    fi
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repo_root=$(cd -- "$script_dir/.." && pwd -P)
source_dir=$repo_root/bootloader-serv
build_dir=$source_dir/build-ulx5m-gs
base=top_ulx5m_gs_flash_read-serv
json=$build_dir/$base.json
impl=$build_dir/$base.txt
bit=$build_dir/$base.bit
pnr_log=$build_dir/flash-read-serv-pnr.log
synth_log=$build_dir/flash-read-serv-synth.log

if [[ ! -f $source_dir/Makefile.ulx5m-gs ]]; then
    printf 'ERROR: missing SERV Makefile: %s\n' "$source_dir/Makefile.ulx5m-gs" >&2
    exit 1
fi

if [[ -x $script_dir/inventory.sh ]]; then
    "$script_dir/inventory.sh" --check-file "${BASH_SOURCE[0]}" || true
fi

for tool in yosys nextpnr-himbaechel gmpack make sha256sum; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'ERROR: required tool not found: %s\n' "$tool" >&2
        exit 1
    fi
done

# Use the shared check so stderr-only nextpnr --version is captured.
# A failed toolchain check must stop before invalidating build artifacts.
NEXTPNR=nextpnr-himbaechel "$script_dir/check-ulx5m-oss-cad-suite.sh"

if [[ $reuse_json == true && ! -s $json ]]; then
    printf 'ERROR: --reuse-json requested but synthesis JSON is missing: %s\n' "$json" >&2
    exit 1
fi

# Invalidate routing outputs even when only the seed changes. Deleting the
# JSON as well forces fresh synthesis (the default). Keep firmware outputs.
rm -f -- "$impl" "$bit" "$pnr_log"
if [[ $reuse_json == false ]]; then
    rm -f -- "$json" "$synth_log"
fi

if [[ $reuse_json == true ]]; then
    printf 'SERV bootloader: reuse synthesis JSON\n'
else
    printf 'SERV bootloader: fresh synthesis JSON\n'
fi
if [[ -n $seed ]]; then
    printf 'Requested seed: %s\n' "$seed"
else
    printf 'Requested seed: Makefile SERV_SEED default\n'
fi
printf 'Output: %s\n' "$bit"

# The flash-read-serv target builds JSON -> routed TXT -> packed BIT.
# Force the same checked tools for both synthesis and routing, even when
# the caller has Makefile tool overrides in the environment.
make_args=(-C "$source_dir" -f Makefile.ulx5m-gs flash-read-serv
           YOSYS=yosys NEXTPNR=nextpnr-himbaechel GMPACK=gmpack)
if [[ -n $seed ]]; then
    make_args+=("SERV_SEED=$seed")
fi

build_rc=0
make "${make_args[@]}" || build_rc=$?

if [[ -s $pnr_log ]]; then
    timing_line=$(grep -F "Max frequency for clock 'bram_i.clk'" "$pnr_log" | tail -n 1 || true)
    if [[ -n $timing_line ]]; then
        printf 'Final timing: %s\n' "$timing_line"
    fi
fi

if (( build_rc != 0 )); then
    printf 'ERROR: SERV build failed (exit %d).\n' "$build_rc" >&2
    exit "$build_rc"
fi

if [[ ! -s $json || ! -s $impl || ! -s $bit ]]; then
    printf 'ERROR: missing or empty JSON, routed TXT, or BIT output.\n' >&2
    exit 1
fi

printf 'Synthesis SHA-256:\n'
sha256sum "$json"
printf 'Bitstream SHA-256:\n'
sha256sum "$bit"
printf 'Bitstream ready: %s\n' "$bit"
