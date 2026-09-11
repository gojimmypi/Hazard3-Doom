#!/bin/bash
# -----------------------------------------------------------------------------
# File:        check-system-requirements.sh
# Path:        scripts/check-system-requirements.sh
#
# Project:     Hazard3-Doom
# Purpose:     Check minimum host resources for development/source builds
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

# Keep the thresholds and resource detection in one place. This file may be
# executed directly or sourced by other Hazard3-Doom scripts.
# /proc/meminfo reports guest-visible RAM, which may be less than the amount
# configured in a VM or physical host. Treat 7168 MiB guest-visible RAM as
# satisfying the documented 8 GiB configured-memory minimum.
H3_MIN_CONFIGURED_RAM_GIB=8
H3_MIN_RAM_MIB=7168
H3_MIN_CPU_COUNT=2
H3_MIN_DISK_GIB=40
H3_RECOMMENDED_SWAP_MIB=4096

system_requirements_pass()
{
    printf '[PASS] %s\n' "$1"
}

system_requirements_warn()
{
    printf '[WARN] %s\n' "$1"
}

system_requirements_fail()
{
    printf '[FAIL] %s\n' "$1" >&2
}

check_system_requirements()
{
    local disk_path="${1:-.}"
    local pass_callback="${2:-system_requirements_pass}"
    local warn_callback="${3:-system_requirements_warn}"
    local fail_callback="${4:-system_requirements_fail}"
    local ram_kib=0
    local ram_mib=0
    local cpu_count=0
    local disk_kib=0
    local disk_avail_kib=0
    local disk_gib=0
    local disk_avail_gib=0
    local swap_kib=0
    local swap_mib=0
    local failures=0

    if [[ -r /proc/meminfo ]]; then
        ram_kib="$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo 2>/dev/null || true)"
        swap_kib="$(awk '/^SwapTotal:/ {print $2; exit}' /proc/meminfo 2>/dev/null || true)"
    fi
    [[ "${ram_kib}" =~ ^[0-9]+$ ]] || ram_kib=0
    [[ "${swap_kib}" =~ ^[0-9]+$ ]] || swap_kib=0
    ram_mib=$((ram_kib / 1024))
    swap_mib=$((swap_kib / 1024))

    if command -v nproc >/dev/null 2>&1; then
        cpu_count="$(nproc 2>/dev/null || true)"
    elif command -v getconf >/dev/null 2>&1; then
        cpu_count="$(getconf _NPROCESSORS_ONLN 2>/dev/null || true)"
    fi
    [[ "${cpu_count}" =~ ^[0-9]+$ ]] || cpu_count=0

    if read -r disk_kib disk_avail_kib < <(
        df -Pk "${disk_path}" 2>/dev/null | awk 'NR == 2 {print $2, $4}'
    ); then
        [[ "${disk_kib}" =~ ^[0-9]+$ ]] || disk_kib=0
        [[ "${disk_avail_kib}" =~ ^[0-9]+$ ]] || disk_avail_kib=0
    fi
    disk_gib=$((disk_kib / 1024 / 1024))
    disk_avail_gib=$((disk_avail_kib / 1024 / 1024))

    printf '\n=== System resources ===\n'
    printf 'Minimum: %d GiB configured RAM (%d MiB guest-visible), %d CPUs, %d GiB filesystem capacity\n' \
        "${H3_MIN_CONFIGURED_RAM_GIB}" "${H3_MIN_RAM_MIB}" \
        "${H3_MIN_CPU_COUNT}" "${H3_MIN_DISK_GIB}"
    printf 'Swap: %d MiB recommended for source builds\n' \
        "${H3_RECOMMENDED_SWAP_MIB}"
    printf 'Filesystem checked: %s\n' "${disk_path}"
    printf 'Detected: %d MiB guest-visible RAM, %d CPUs, %d GiB filesystem capacity, %d GiB free, %d MiB swap\n' \
        "${ram_mib}" "${cpu_count}" "${disk_gib}" "${disk_avail_gib}" "${swap_mib}"

    if (( ram_mib >= H3_MIN_RAM_MIB )); then
        "${pass_callback}" \
            "RAM meets the ${H3_MIN_CONFIGURED_RAM_GIB} GiB configured-memory minimum (${H3_MIN_RAM_MIB} MiB guest-visible threshold)"
    else
        "${fail_callback}" \
            "RAM is below the ${H3_MIN_CONFIGURED_RAM_GIB} GiB configured-memory minimum (${H3_MIN_RAM_MIB} MiB guest-visible threshold)"
        printf '%s\n' '       Increase VM memory before long Yosys/nextpnr source builds.'
        failures=$((failures + 1))
    fi

    if (( cpu_count >= H3_MIN_CPU_COUNT )); then
        "${pass_callback}" "CPU count meets the ${H3_MIN_CPU_COUNT} CPU minimum"
    else
        "${fail_callback}" "CPU count is below the ${H3_MIN_CPU_COUNT} CPU minimum"
        failures=$((failures + 1))
    fi

    if (( disk_gib >= H3_MIN_DISK_GIB )); then
        "${pass_callback}" "Filesystem capacity meets the ${H3_MIN_DISK_GIB} GiB minimum"
    else
        "${fail_callback}" "Filesystem capacity is below the ${H3_MIN_DISK_GIB} GiB minimum"
        failures=$((failures + 1))
    fi

    if (( swap_mib >= H3_RECOMMENDED_SWAP_MIB )); then
        "${pass_callback}" "Swap meets the ${H3_RECOMMENDED_SWAP_MIB} MiB recommendation"
    else
        "${warn_callback}" "Swap is below the ${H3_RECOMMENDED_SWAP_MIB} MiB recommendation"
        printf '%s\n' '       Long Yosys/nextpnr source builds may exhaust memory under load.'
    fi

    (( failures == 0 ))
}

system_requirements_usage()
{
    cat <<EOF_USAGE
Usage: ${0##*/} [PATH]

Check the minimum host resources used for Hazard3-Doom development and source
builds. PATH selects the filesystem to inspect and defaults to the current
directory.

  -h, --help  Show this help text.
EOF_USAGE
}

system_requirements_main()
{
    local disk_path="."

    case "${1:-}" in
    -h|--help)
        system_requirements_usage
        return 0
        ;;
    "")
        ;;
    *)
        disk_path="$1"
        shift
        ;;
    esac

    if (( $# > 0 )); then
        printf 'Unexpected argument: %s\n\n' "$1" >&2
        system_requirements_usage >&2
        return 2
    fi

    if check_system_requirements "${disk_path}"; then
        printf '\nRESULT: PASS - minimum system resources were found.\n'
        return 0
    fi

    printf '\nRESULT: FAIL - minimum system resources were not found.\n' >&2
    return 1
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    set -u
    set -o pipefail
    system_requirements_main "$@"
fi
