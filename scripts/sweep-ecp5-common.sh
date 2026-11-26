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

# Verify this script against the recorded inventory without blocking normal execution.
"$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/inventory.sh" \
    --check-file "${BASH_SOURCE[0]}" || true

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

sweep_ecp5_run_synthesis()
{
    local synth_dir="$1"
    local synth_log="$2"
    local status

    shift 2
    SWEEP_SYNTHESIS_RAN=0
    rm -f "${synth_dir}/synth.log"
    if make -C "${synth_dir}" "$@"; then
        status=0
    else
        status=$?
    fi

    if [[ -f "${synth_dir}/synth.log" ]]; then
        mv -f "${synth_dir}/synth.log" "${synth_log}"
        # Output variable read by the board-specific script sourcing this file.
        # Do not export.
        # shellcheck disable=SC2034
        SWEEP_SYNTHESIS_RAN=1
    fi

    return "${status}"
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

# Physical clocks and nextpnr timing requirements come from the RTL/PLL and
# generated LPF/SDC. Reported clock targets do not reconfigure those clocks.
# All routed ECP5 sweeps check physical and configured targets before PASS.
sweep_ecp5_hdmi_output_resolution()
{
    local expected_resolution
    case "${SWEEP_ECP5_BOARD_ID}" in
    ulx3s-85f) expected_resolution=640x480 ;;
    ulx3s-12f|ulx3s-45f|ulx4m-ld-85f) expected_resolution=1024x600 ;;
    *) echo "Unsupported ECP5 HDMI profile: ${SWEEP_ECP5_BOARD_ID}" >&2; return 1 ;;
    esac

    SWEEP_HDMI_OUTPUT_RESOLUTION="${SWEEP_HDMI_OUTPUT_RESOLUTION:-${expected_resolution}}"
    if [[ "${SWEEP_HDMI_OUTPUT_RESOLUTION}" != "${expected_resolution}" ]]; then
        printf 'Invalid HDMI output resolution %s for %s; this target implements %s.\n' \
            "${SWEEP_HDMI_OUTPUT_RESOLUTION}" "${SWEEP_ECP5_BOARD_ID}" "${expected_resolution}" >&2
        echo 'Changing the physical HDMI resolution requires RTL/PLL changes, not a sweep override.' >&2
        return 1
    fi
}

# Resolve the board clock profile in Python, the same source used to verify
# nextpnr constraints. Keep physical clocks, qualification floors and user
# requests separate. No shell code is evaluated from the helper output.
sweep_ecp5_clock_targets()
{
    sweep_ecp5_hdmi_output_resolution || return 1
    local helper_dir profile role nominal floor target_name required_name requested
    local -a system_arg=()
    helper_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
    case "${SWEEP_ECP5_BOARD_ID}" in
    ulx3s-85f)
        if [[ -n "${HAZARD3_ULX3S_85F_SYS_CLK_MHZ:-}" ]]; then
            system_arg=("${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}")
        fi
        ;;
    ulx3s-12f|ulx3s-45f) ;;
    ulx4m-ld-85f)
        if [[ -n "${HAZARD3_ULX4M_SYS_CLK_MHZ:-}" ]]; then
            system_arg=("${HAZARD3_ULX4M_SYS_CLK_MHZ}")
        fi
        ;;
    *) echo "Unsupported ECP5 clock profile: ${SWEEP_ECP5_BOARD_ID}" >&2; return 1 ;;
    esac
    sweep_ecp5_require_tool python3
    profile="$(python3 "${helper_dir}/sweep-ecp5-clocks.py" profile \
        "${SWEEP_ECP5_BOARD_ID}" "${system_arg[@]}")" || return 1

    while read -r role nominal floor; do
        case "${role}" in
        sys)
            SWEEP_PHYSICAL_SYS_MHZ="${nominal}"
            target_name=SWEEP_SYS_TARGET_MHZ
            required_name=SWEEP_SYS_REQUIRED_MHZ
            ;;
        video)
            # Output variable read by watch-ecp5-sweep-results.sh; do not export.
            # shellcheck disable=SC2034
            SWEEP_PHYSICAL_VIDEO_MHZ="${nominal}"
            target_name=SWEEP_VIDEO_TARGET_MHZ
            required_name=SWEEP_VIDEO_REQUIRED_MHZ
            ;;
        tmds)
            # Output variable read by watch-ecp5-sweep-results.sh; do not export.
            # shellcheck disable=SC2034
            SWEEP_PHYSICAL_TMDS_MHZ="${nominal}"
            target_name=SWEEP_TMDS_TARGET_MHZ
            required_name=SWEEP_TMDS_REQUIRED_MHZ
            ;;
        litedram_user)
            # Output variable read by watch-ecp5-sweep-results.sh; do not export.
            # shellcheck disable=SC2034
            SWEEP_PHYSICAL_LITEDRAM_MHZ="${nominal}"
            target_name=SWEEP_LITEDRAM_TARGET_MHZ
            required_name=SWEEP_LITEDRAM_REQUIRED_MHZ
            ;;
        init)
            # Output variable read by watch-ecp5-sweep-results.sh; do not export.
            # shellcheck disable=SC2034
            SWEEP_PHYSICAL_INIT_MHZ="${nominal}"
            target_name=SWEEP_INIT_TARGET_MHZ
            required_name=SWEEP_INIT_REQUIRED_MHZ
            ;;
        *) echo "Unknown ECP5 clock role: ${role}" >&2; return 1 ;;
        esac
        # Default to the board floor; local overrides may only raise it.
        requested="${!target_name:-${floor}}"
        if [[ ! "${requested}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
            echo "${target_name} must be a nonnegative MHz value." >&2
            return 1
        fi
        printf -v "${target_name}" '%s' "${requested}"
        printf -v "${required_name}" '%s' "$(sweep_ecp5_effective_clock_requirement "${floor}" "${requested}")"
    done <<< "${profile}"
}

sweep_ecp5_init_tuning()
{
    ecp5_board_defaults "${SWEEP_ECP5_BOARD_ID}"
    SWEEP_NEXTPNR_PLACER="${SWEEP_NEXTPNR_PLACER:-${HAZARD3_ULX4M_NEXTPNR_PLACER:-heap}}"
    SWEEP_NEXTPNR_ROUTER="${SWEEP_NEXTPNR_ROUTER:-${HAZARD3_ULX4M_NEXTPNR_ROUTER:-router1}}"
    # Keep the sweep default identical to this board's production build.
    SWEEP_NEXTPNR_HEAP_TIMINGWEIGHT="${SWEEP_NEXTPNR_HEAP_TIMINGWEIGHT:-${HAZARD3_ULX4M_NEXTPNR_HEAP_TIMINGWEIGHT:-${ECP5_DEFAULT_NEXTPNR_HEAP_TIMINGWEIGHT}}}"
    SWEEP_NEXTPNR_HEAP_CRITEXP="${SWEEP_NEXTPNR_HEAP_CRITEXP:-${HAZARD3_ULX4M_NEXTPNR_HEAP_CRITEXP:-2}}"
    SWEEP_NEXTPNR_TMG_RIPUP="$(sweep_ecp5_bool "${SWEEP_NEXTPNR_TMG_RIPUP:-${HAZARD3_ULX4M_NEXTPNR_TMG_RIPUP:-0}}")"
    SWEEP_NEXTPNR_ROUTER2_ALT_WEIGHTS="$(sweep_ecp5_bool "${SWEEP_NEXTPNR_ROUTER2_ALT_WEIGHTS:-${HAZARD3_ULX4M_NEXTPNR_ROUTER2_ALT_WEIGHTS:-0}}")"
    SWEEP_NEXTPNR_EXTRA_ARGS="${SWEEP_NEXTPNR_EXTRA_ARGS:-${HAZARD3_ULX4M_NEXTPNR_EXTRA_ARGS:-}}"
    SWEEP_ROUTE_TIMEOUT_SECONDS="${SWEEP_ROUTE_TIMEOUT_SECONDS:-7200}"
    SWEEP_ROUTE_KILL_AFTER_SECONDS="${SWEEP_ROUTE_KILL_AFTER_SECONDS:-30}"

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
    if [[ ! "${SWEEP_ROUTE_TIMEOUT_SECONDS}" =~ ^[1-9][0-9]*$ ]]; then
        echo "SWEEP_ROUTE_TIMEOUT_SECONDS must be a positive integer." >&2
        exit 1
    fi
    if [[ ! "${SWEEP_ROUTE_KILL_AFTER_SECONDS}" =~ ^[1-9][0-9]*$ ]]; then
        echo "SWEEP_ROUTE_KILL_AFTER_SECONDS must be a positive integer." >&2
        exit 1
    fi

    if [[ "${SWEEP_NEXTPNR_PLACER}" != "heap" &&
          ( "${SWEEP_NEXTPNR_HEAP_TIMINGWEIGHT}" != "${ECP5_DEFAULT_NEXTPNR_HEAP_TIMINGWEIGHT}" ||
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
        # See also --placer-heap-timingweight setting in build-ecp5-bitstream-common.sh
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

# nextpnr accepts signed 32-bit positive seeds; reject overflow before Bash
# arithmetic, and normalize decimal input (including leading zeros).
sweep_ecp5_valid_seed()
{
    [[ "$1" =~ ^0*([1-9][0-9]*)$ ]] || return 1
    REPLY="${BASH_REMATCH[1]}"
    (( ${#REPLY} <= 10 )) && (( 10#${REPLY} <= 2147483647 ))
}

sweep_ecp5_parse_seeds()
{
    local usage_function="$1"
    shift

    SWEEP_SEEDS=()
    SWEEP_SEEDS_FROM_ALL=0
    declare -gA SWEEP_SEEN_SEEDS=()

    if (( $# == 1 )) && [[ "$1" == "--all" ]]; then
        local all_seed_last="${SWEEP_ALL_SEED_LAST:-512}"
        if ! sweep_ecp5_valid_seed "${all_seed_last}"; then
            echo "Invalid SWEEP_ALL_SEED_LAST: ${all_seed_last}; expected 1-2147483647." >&2
            exit 1
        fi
        SWEEP_SEEDS_FROM_ALL=1
        mapfile -t SWEEP_SEEDS < <(seq 1 "${REPLY}")
        return
    fi

    if (( $# == 0 )); then
        "${usage_function}"
        exit 1
    fi

    local arg seed_arg seed_first seed_last seed_value raw_first raw_last
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
                raw_first="${BASH_REMATCH[1]}"
                raw_last="${BASH_REMATCH[2]}"
                if ! sweep_ecp5_valid_seed "${raw_first}"; then
                    echo "Invalid starting seed: ${raw_first}; expected 1-2147483647." >&2
                    exit 1
                fi
                seed_first="${REPLY}"
                if ! sweep_ecp5_valid_seed "${raw_last}"; then
                    echo "Invalid ending seed: ${raw_last}; expected 1-2147483647." >&2
                    exit 1
                fi
                seed_last="${REPLY}"
                if (( seed_first > seed_last )); then
                    echo "Invalid seed range: ${seed_arg}; first must be <= last." >&2
                    exit 1
                fi
                while (( seed_first <= seed_last )); do
                    if [[ -z "${SWEEP_SEEN_SEEDS[${seed_first}]+x}" ]]; then
                        SWEEP_SEEDS+=("${seed_first}")
                        SWEEP_SEEN_SEEDS["${seed_first}"]=1
                    fi
                    seed_first=$((seed_first + 1))
                done
            elif sweep_ecp5_valid_seed "${seed_arg}"; then
                seed_value="${REPLY}"
                if [[ -z "${SWEEP_SEEN_SEEDS[${seed_value}]+x}" ]]; then
                    SWEEP_SEEDS+=("${seed_value}")
                    SWEEP_SEEN_SEEDS["${seed_value}"]=1
                fi
            else
                echo "Invalid seed: ${seed_arg}; expected 1-2147483647 or a range such as 750-1261." >&2
                "${usage_function}"
                exit 1
            fi
        done
    done
}

sweep_ecp5_results_filename()
{
    local sweep_dir="$1"

    if [[ "${SWEEP_SEEDS_FROM_ALL:-0}" == "1" ]]; then
        printf '%s/results.csv\n' "${sweep_dir}"
    elif (( ${#SWEEP_SEEDS[@]} == 260 )) &&
         [[ "${SWEEP_SEEDS[0]}" == "1" && "${SWEEP_SEEDS[259]}" == "260" ]]; then
        # Preserve the legacy filename for the historical 1-260 sweep.
        printf '%s/results.csv\n' "${sweep_dir}"
    elif (( ${#SWEEP_SEEDS[@]} == 1 )); then
        printf '%s/results-seed-%s.csv\n' "${sweep_dir}" "${SWEEP_SEEDS[0]}"
    else
        printf '%s/results-selected.csv\n' "${sweep_dir}"
    fi
}

# The ULX3S 85F once used a PLL-derived clk_sys (50 MHz). In the 25 MHz
# direct-oscillator configuration, nextpnr instead reports clk_osc$TRELLIS_IO_IN.
# Identify the name from the final timing report, never from the requested seed,
# and reject unknown/ambiguous reports rather than silently marking a pass.
sweep_ecp5_ulx3s_85f_system_clock()
{
    local log="$1"
    local reports have_sys=0 have_osc=0

    reports="$(grep 'Max frequency for clock' "${log}" 2>/dev/null || true)"
    if [[ "${reports}" == *"'\$glbnet\$clk_sys'"* ]]; then
        have_sys=1
    fi
    if [[ "${reports}" == *"'\$glbnet\$clk_osc'"* ||
          "${reports}" == *"'\$glbnet\$clk_osc\$TRELLIS_IO_IN'"* ]]; then
        have_osc=1
    fi

    case "${have_sys}${have_osc}" in
    10) printf 'clk_sys\n' ;;
    01) printf 'clk_osc\n' ;;
    *)
        printf 'ERROR: ULX3S 85F system clock is missing or ambiguous in %s (clk_sys=%s, clk_osc=%s).\n' \
            "${log}" "${have_sys}" "${have_osc}" >&2
        return 1
        ;;
    esac
}

# Resolve logical clock roles once per frozen netlist. The helper uses the
# PLL output connections and exact bit aliases rather than timing-log names.
sweep_ecp5_discover_clocks()
{
    local netlist="$1"
    local helper_dir
    helper_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
    sweep_ecp5_require_tool python3
    if ! SWEEP_CLOCK_MAP="$(python3 "${helper_dir}/sweep-ecp5-clocks.py" \
        discover "${netlist}" "${SWEEP_ECP5_BOARD_ID}" "${SWEEP_PHYSICAL_SYS_MHZ}")"; then
        return 1
    fi
}

# Pack mode: 1 = timing-passing seeds (local default), 0 = timing only.
# CI preflight uses 2 to exercise ecppack even when timing misses.
sweep_ecp5_init_pack_mode()
{
    SWEEP_PACK_BITSTREAMS="${SWEEP_PACK_BITSTREAMS:-1}"
    case "${SWEEP_PACK_BITSTREAMS}" in
    0|1|2) ;;
    *) echo 'SWEEP_PACK_BITSTREAMS must be 0, 1 or 2.' >&2; return 1 ;;
    esac
    case "${SWEEP_PACK_BITSTREAMS}" in
    0) echo 'Bitstream packing: skipped (timing only)' ;;
    1) echo 'Bitstream packing: timing PASS seeds only' ;;
    2) echo 'Bitstream packing: all completed routes (preflight)' ;;
    esac
}

sweep_ecp5_read_routed_clocks()
{
    local log="$1"
    local helper_dir
    helper_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
    python3 "${helper_dir}/sweep-ecp5-clocks.py" read "${SWEEP_CLOCK_MAP}" "${log}" \
        "${SWEEP_ECP5_BOARD_ID}" "${SWEEP_PHYSICAL_SYS_MHZ}"
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

# Check a routed Fmax against a MHz target, independently of nextpnr's own
# PASS/FAIL verdict. Missing or malformed results must never count as PASS.
sweep_ecp5_clock_meets_target()
{
    local measured_mhz="$1"
    local required_mhz="$2"

    [[ "${measured_mhz}" =~ ^[0-9]+([.][0-9]+)?$ ]] || return 1
    [[ "${required_mhz}" =~ ^[0-9]+([.][0-9]+)?$ ]] || return 1

    awk -v measured="${measured_mhz}" -v required="${required_mhz}" \
        'BEGIN { exit ((measured + 0) < (required + 0)) ? 1 : 0 }'
}

# Compute once during profile initialization, then reuse for PASS and metadata.
sweep_ecp5_effective_clock_requirement()
{
    local minimum="$1"
    local requested="$2"
    if sweep_ecp5_clock_meets_target "${requested}" "${minimum}"; then
        printf '%s\n' "${requested}"
    else
        printf '%s\n' "${minimum}"
    fi
}

sweep_ecp5_write_clock_requirement()
{
    local role="$1"
    local requested="$2"
    local effective="$3"
    printf '%s_requested_mhz=%s\n' "${role}" "${requested}"
    printf '%s_required_mhz=%s\n' "${role}" "${effective}"
}

# The same effective values are consumed by the board routing verdicts.
sweep_ecp5_write_clock_requirements()
{
    sweep_ecp5_write_clock_requirement clk_sys "${SWEEP_SYS_TARGET_MHZ}" "${SWEEP_SYS_REQUIRED_MHZ}"
    if [[ "${SWEEP_ECP5_BOARD_ID}" == ulx4m-ld-85f ]]; then
        sweep_ecp5_write_clock_requirement litedram_user "${SWEEP_LITEDRAM_TARGET_MHZ}" "${SWEEP_LITEDRAM_REQUIRED_MHZ}"
    fi
    sweep_ecp5_write_clock_requirement clk_video "${SWEEP_VIDEO_TARGET_MHZ}" "${SWEEP_VIDEO_REQUIRED_MHZ}"
    sweep_ecp5_write_clock_requirement clk_tmds "${SWEEP_TMDS_TARGET_MHZ}" "${SWEEP_TMDS_REQUIRED_MHZ}"
    if [[ "${SWEEP_ECP5_BOARD_ID}" == ulx4m-ld-85f ]]; then
        sweep_ecp5_write_clock_requirement init_clk "${SWEEP_INIT_TARGET_MHZ}" "${SWEEP_INIT_REQUIRED_MHZ}"
    fi
}

sweep_ecp5_extract_clock_status()
{
    local log="$1"
    local clock="$2"
    local line

    line="$(
        grep "Max frequency for clock.*${clock}" "${log}" 2>/dev/null |
            tail -n 1 || true
    )"

    case "${line}" in
    *"(FAIL at "*)
        printf 'FAIL\n'
        ;;
    *"(PASS at "*)
        printf 'PASS\n'
        ;;
    *)
        printf 'UNKNOWN\n'
        ;;
    esac
}

sweep_ecp5_run_nextpnr()
{
    printf 'nextpnr command:'
    printf ' %q' nextpnr-ecp5 "$@"
    printf '\n'

    timeout \
        --signal=TERM \
        --kill-after="${SWEEP_ROUTE_KILL_AFTER_SECONDS}s" \
        "${SWEEP_ROUTE_TIMEOUT_SECONDS}s" \
        nextpnr-ecp5 "$@"
}

sweep_ecp5_write_tuning_metadata()
{
    printf 'hdmi_output_resolution=%s\n' "${SWEEP_HDMI_OUTPUT_RESOLUTION}"
    printf 'placer=%s\n' "${SWEEP_NEXTPNR_PLACER}"
    printf 'router=%s\n' "${SWEEP_NEXTPNR_ROUTER}"
    printf 'heap_timingweight=%s\n' "${SWEEP_NEXTPNR_HEAP_TIMINGWEIGHT}"
    printf 'heap_critexp=%s\n' "${SWEEP_NEXTPNR_HEAP_CRITEXP}"
    printf 'tmg_ripup=%s\n' "${SWEEP_NEXTPNR_TMG_RIPUP}"
    printf 'router2_alt_weights=%s\n' "${SWEEP_NEXTPNR_ROUTER2_ALT_WEIGHTS}"
    printf 'extra_args=%s\n' "${SWEEP_NEXTPNR_EXTRA_ARGS}"
    printf 'route_timeout_seconds=%s\n' "${SWEEP_ROUTE_TIMEOUT_SECONDS}"
    printf 'route_kill_after_seconds=%s\n' "${SWEEP_ROUTE_KILL_AFTER_SECONDS}"
    if command -v nextpnr-ecp5 >/dev/null 2>&1; then
        printf 'nextpnr_version=%s\n' "$(nextpnr-ecp5 --version 2>&1 | head -n 1)"
    fi
}
