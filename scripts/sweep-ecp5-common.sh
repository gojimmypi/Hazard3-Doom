#!/bin/bash
# -----------------------------------------------------------------------------
# File:        sweep-ecp5-common.sh
# Path:        scripts/sweep-ecp5-common.sh
#
# Project:     Hazard3-Doom
# Purpose:     Shared helpers for routed ECP5 seed sweeps.
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

# This file is sourced by sweep scripts. Do not enable shell options here.

sweep_ecp5_require_tool()
{
    local tool="$1"

    command -v "${tool}" >/dev/null 2>&1 || {
        echo "Missing required tool: ${tool}" >&2
        exit 1
    }
}

sweep_ecp5_require_file()
{
    local path="$1"

    [[ -f "${path}" ]] || {
        echo "Missing required file: ${path}" >&2
        exit 1
    }
}

sweep_ecp5_bool()
{
    local value="$1"

    case "${value}" in
    0|false|FALSE|False|no|NO|No)
        printf '0\n'
        ;;
    1|true|TRUE|True|yes|YES|Yes)
        printf '1\n'
        ;;
    *)
        echo "Expected boolean value, got: ${value}" >&2
        return 1
        ;;
    esac
}

sweep_ecp5_init_tuning()
{
    SWEEP_NEXTPNR_PLACER="${SWEEP_NEXTPNR_PLACER:-${HAZARD3_ULX4M_NEXTPNR_PLACER:-heap}}"
    SWEEP_NEXTPNR_ROUTER="${SWEEP_NEXTPNR_ROUTER:-${HAZARD3_ULX4M_NEXTPNR_ROUTER:-router1}}"
    SWEEP_NEXTPNR_HEAP_TIMINGWEIGHT="${SWEEP_NEXTPNR_HEAP_TIMINGWEIGHT:-${HAZARD3_ULX4M_NEXTPNR_HEAP_TIMINGWEIGHT:-10}}"
    SWEEP_NEXTPNR_HEAP_CRITEXP="${SWEEP_NEXTPNR_HEAP_CRITEXP:-${HAZARD3_ULX4M_NEXTPNR_HEAP_CRITEXP:-2}}"
    SWEEP_NEXTPNR_TMG_RIPUP="$(sweep_ecp5_bool "${SWEEP_NEXTPNR_TMG_RIPUP:-${HAZARD3_ULX4M_NEXTPNR_TMG_RIPUP:-0}}")"
    SWEEP_NEXTPNR_ROUTER2_ALT_WEIGHTS="$(sweep_ecp5_bool "${SWEEP_NEXTPNR_ROUTER2_ALT_WEIGHTS:-${HAZARD3_ULX4M_NEXTPNR_ROUTER2_ALT_WEIGHTS:-0}}")"
    SWEEP_NEXTPNR_EXTRA_ARGS="${SWEEP_NEXTPNR_EXTRA_ARGS:-${HAZARD3_ULX4M_NEXTPNR_EXTRA_ARGS:-}}"

    case "${SWEEP_NEXTPNR_PLACER}" in
    heap|sa)
        ;;
    *)
        echo "SWEEP_NEXTPNR_PLACER must be heap or sa." >&2
        exit 1
        ;;
    esac

    case "${SWEEP_NEXTPNR_ROUTER}" in
    router1|router2)
        ;;
    *)
        echo "SWEEP_NEXTPNR_ROUTER must be router1 or router2." >&2
        exit 1
        ;;
    esac

    if [[ ! "${SWEEP_NEXTPNR_HEAP_TIMINGWEIGHT}" =~ ^[1-9][0-9]*$ ]]; then
        echo "SWEEP_NEXTPNR_HEAP_TIMINGWEIGHT must be a positive integer." >&2
        exit 1
    fi
    if [[ ! "${SWEEP_NEXTPNR_HEAP_CRITEXP}" =~ ^[1-9][0-9]*$ ]]; then
        echo "SWEEP_NEXTPNR_HEAP_CRITEXP must be a positive integer." >&2
        exit 1
    fi

    if [[ "${SWEEP_NEXTPNR_PLACER}" != "heap" &&
          ( "${SWEEP_NEXTPNR_HEAP_TIMINGWEIGHT}" != "10" ||
            "${SWEEP_NEXTPNR_HEAP_CRITEXP}" != "2" ) ]]; then
        echo "HeAP timingweight/critexp tuning requires placer=heap." >&2
        exit 1
    fi

    if [[ "${SWEEP_NEXTPNR_ROUTER2_ALT_WEIGHTS}" == "1" &&
          "${SWEEP_NEXTPNR_ROUTER}" != "router2" ]]; then
        echo "Router2 alternate weights require router=router2." >&2
        exit 1
    fi

    SWEEP_NEXTPNR_ARGS=(
        --placer "${SWEEP_NEXTPNR_PLACER}"
        --router "${SWEEP_NEXTPNR_ROUTER}"
    )

    if [[ "${SWEEP_NEXTPNR_PLACER}" == "heap" ]]; then
        SWEEP_NEXTPNR_ARGS+=(
            --placer-heap-timingweight "${SWEEP_NEXTPNR_HEAP_TIMINGWEIGHT}"
            --placer-heap-critexp "${SWEEP_NEXTPNR_HEAP_CRITEXP}"
        )
    fi
    if [[ "${SWEEP_NEXTPNR_TMG_RIPUP}" == "1" ]]; then
        SWEEP_NEXTPNR_ARGS+=(--tmg-ripup)
    fi
    if [[ "${SWEEP_NEXTPNR_ROUTER2_ALT_WEIGHTS}" == "1" ]]; then
        SWEEP_NEXTPNR_ARGS+=(--router2-alt-weights)
    fi
    if [[ -n "${SWEEP_NEXTPNR_EXTRA_ARGS}" ]]; then
        local extra_args=()
        read -r -a extra_args <<< "${SWEEP_NEXTPNR_EXTRA_ARGS}"
        SWEEP_NEXTPNR_ARGS+=("${extra_args[@]}")
    fi
}

sweep_ecp5_tuning_suffix()
{
    local suffix=""
    local extra_hash

    if [[ "${SWEEP_NEXTPNR_PLACER}" != "heap" ]]; then
        suffix="${suffix}-${SWEEP_NEXTPNR_PLACER}"
    fi
    if [[ "${SWEEP_NEXTPNR_ROUTER}" != "router1" ]]; then
        suffix="${suffix}-${SWEEP_NEXTPNR_ROUTER}"
    fi
    if [[ "${SWEEP_NEXTPNR_PLACER}" == "heap" &&
          "${SWEEP_NEXTPNR_HEAP_TIMINGWEIGHT}" != "10" ]]; then
        suffix="${suffix}-tw${SWEEP_NEXTPNR_HEAP_TIMINGWEIGHT}"
    fi
    if [[ "${SWEEP_NEXTPNR_PLACER}" == "heap" &&
          "${SWEEP_NEXTPNR_HEAP_CRITEXP}" != "2" ]]; then
        suffix="${suffix}-ce${SWEEP_NEXTPNR_HEAP_CRITEXP}"
    fi
    if [[ "${SWEEP_NEXTPNR_TMG_RIPUP}" == "1" ]]; then
        suffix="${suffix}-ripup"
    fi
    if [[ "${SWEEP_NEXTPNR_ROUTER2_ALT_WEIGHTS}" == "1" ]]; then
        suffix="${suffix}-altw"
    fi
    if [[ -n "${SWEEP_NEXTPNR_EXTRA_ARGS}" ]]; then
        extra_hash="$(printf '%s' "${SWEEP_NEXTPNR_EXTRA_ARGS}" | sha256sum | awk '{print $1}')"
        suffix="${suffix}-extra-${extra_hash:0:8}"
    fi

    printf '%s\n' "${suffix}"
}

sweep_ecp5_parse_seeds()
{
    local usage_function="$1"
    shift

    SWEEP_SEEDS=()
    declare -gA SWEEP_SEEN_SEEDS=()

    if (( $# == 1 )) && [[ "$1" == "--all" ]]; then
        mapfile -t SWEEP_SEEDS < <(seq 1 260)
        return
    fi

    if (( $# == 0 )); then
        "${usage_function}"
        exit 1
    fi

    local arg seed_arg seed_first seed_last seed_value
    local arg_seeds=()

    for arg in "$@"; do
        if [[ "${arg}" == "--all" ]]; then
            echo "--all cannot be combined with explicit seeds." >&2
            "${usage_function}"
            exit 1
        fi

        IFS=',' read -r -a arg_seeds <<< "${arg}"
        for seed_arg in "${arg_seeds[@]}"; do
            if [[ "${seed_arg}" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                seed_first=$((10#${BASH_REMATCH[1]}))
                seed_last=$((10#${BASH_REMATCH[2]}))
                if (( seed_first < 1 || seed_last > 260 || seed_first > seed_last )); then
                    echo "Invalid seed range: ${seed_arg}; expected start-end within 1-260." >&2
                    "${usage_function}"
                    exit 1
                fi
                while (( seed_first <= seed_last )); do
                    if [[ -z "${SWEEP_SEEN_SEEDS[${seed_first}]+x}" ]]; then
                        SWEEP_SEEDS+=("${seed_first}")
                        SWEEP_SEEN_SEEDS["${seed_first}"]=1
                    fi
                    seed_first=$((seed_first + 1))
                done
            elif [[ "${seed_arg}" =~ ^[0-9]+$ ]]; then
                seed_value=$((10#${seed_arg}))
                if (( seed_value < 1 || seed_value > 260 )); then
                    echo "Invalid seed: ${seed_arg}; expected 1-260." >&2
                    "${usage_function}"
                    exit 1
                fi
                if [[ -z "${SWEEP_SEEN_SEEDS[${seed_value}]+x}" ]]; then
                    SWEEP_SEEDS+=("${seed_value}")
                    SWEEP_SEEN_SEEDS["${seed_value}"]=1
                fi
            else
                echo "Invalid seed: ${seed_arg}; expected 1-260 or a range such as 1-32." >&2
                "${usage_function}"
                exit 1
            fi
        done
    done
}

sweep_ecp5_results_filename()
{
    local sweep_dir="$1"

    if (( ${#SWEEP_SEEDS[@]} == 260 )); then
        printf '%s/results.csv\n' "${sweep_dir}"
    elif (( ${#SWEEP_SEEDS[@]} == 1 )); then
        printf '%s/results-seed-%s.csv\n' "${sweep_dir}" "${SWEEP_SEEDS[0]}"
    else
        printf '%s/results-selected.csv\n' "${sweep_dir}"
    fi
}

sweep_ecp5_extract_clock()
{
    local log="$1"
    local clock="$2"
    local value

    value="$(
        grep "Max frequency for clock.*${clock}" "${log}" 2>/dev/null |
            tail -n 1 |
            sed -E 's/.*: ([0-9.]+) MHz.*/\1/' || true
    )"

    if [[ -z "${value}" ]]; then
        value="NA"
    fi

    printf '%s\n' "${value}"
}

sweep_ecp5_clock_at_least()
{
    local value="$1"
    local minimum="$2"

    [[ "${value}" =~ ^[0-9]+([.][0-9]+)?$ ]] || return 1
    awk -v value="${value}" -v minimum="${minimum}" \
        'BEGIN { exit !(value >= minimum) }'
}

sweep_ecp5_write_tuning_metadata()
{
    printf 'placer=%s\n' "${SWEEP_NEXTPNR_PLACER}"
    printf 'router=%s\n' "${SWEEP_NEXTPNR_ROUTER}"
    printf 'heap_timingweight=%s\n' "${SWEEP_NEXTPNR_HEAP_TIMINGWEIGHT}"
    printf 'heap_critexp=%s\n' "${SWEEP_NEXTPNR_HEAP_CRITEXP}"
    printf 'tmg_ripup=%s\n' "${SWEEP_NEXTPNR_TMG_RIPUP}"
    printf 'router2_alt_weights=%s\n' "${SWEEP_NEXTPNR_ROUTER2_ALT_WEIGHTS}"
    printf 'extra_args=%s\n' "${SWEEP_NEXTPNR_EXTRA_ARGS}"
    if command -v nextpnr-ecp5 >/dev/null 2>&1; then
        printf 'nextpnr_version=%s\n' "$(nextpnr-ecp5 --version 2>&1 | head -n 1)"
    fi
}
