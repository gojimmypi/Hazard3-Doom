#!/bin/bash
# -----------------------------------------------------------------------------
# File:        build-ecp5-bitstream-common.sh
# Path:        scripts/build-ecp5-bitstream-common.sh
#
# Project:     Hazard3-Doom
# Purpose:     Provide the shared ECP5 synthesis and place-and-route flow
#              used by board-specific build wrappers.
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

# file: scripts/build-ecp5-bitstream-common.sh
#
# Shared ECP5 synthesis/place-and-route flow for Hazard3-Doom board wrappers.
# Board-specific behavior is selected by the first argument.
#
# ****************************** REMINDER *******************************************
# When changing default here, also review .github/workflows/ulx4m-ld-seed-sweep.yml
# ***********************************************************************************
#
set -euo pipefail

# Verify this script against the recorded inventory without blocking normal execution.
"$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/inventory.sh" \
    --check-file "${BASH_SOURCE[0]}" || true

# Default seed and HeAP timing weight are shared with seed sweeps.
# See scripts/ecp5-board-defaults.sh for per-board configuration.
# NEXTPNR_SEED and NEXTPNR_HEAP_TIMINGWEIGHT remain caller overrides.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/ecp5-board-defaults.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/ecp5-board-defaults.sh"

BOARD_ID="${1:-}"
shift || true

REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
HAZARD3_ROOT="${HAZARD3_ROOT:-${REPO_ROOT}/third_party/Hazard3}"
HAZARD3_SYNTH="${HAZARD3_ROOT}/example_soc/synth"
BUILD_DIR="${REPO_ROOT}/build"
ALLOW_TIMING_FAILURE="${ALLOW_TIMING_FAILURE:-0}"
FORCE_BITSTREAM_REBUILD="${FORCE_BITSTREAM_REBUILD:-0}"
SKIP_SYNTH="${SKIP_SYNTH:-0}"
SYNTHESIS_RAN=0

require_tool()
{
    local tool="$1"

    command -v "${tool}" >/dev/null 2>&1 || {
        echo "Missing required tool: ${tool}" >&2
        exit 1
    }
}

require_file()
{
    local path="$1"

    [[ -f "${path}" ]] || {
        echo "Missing required file: ${path}" >&2
        exit 1
    }
}

move_synth_log()
{
    if [[ -f "${SYNTH_WORK_LOG}" ]]; then
        mv -f "${SYNTH_WORK_LOG}" "${SYNTH_LOG}"
        SYNTHESIS_RAN=1
    fi
}

prepare_ulx3s_video_profile()
{
    local current_video_profile=""
    local current_sys_clock=""
    local current_registered_hits=""
    local current_sram_write_buffer=""
    local current_sram_dual_port=""
    local current_cache_tag_pipeline=""
    local current_tag_ram_mode=""
    local current_cache_addr_pipeline=""
    local monitor_sys_clock=""
    local profile_changed=0

    # A new system PLL also changes the monitor's UART/timer baud calculations.
    # Never embed a known-mismatched monitor or an unstamped experimental one.
    if [[ -f "${MONITOR_SYS_CLK_STAMP}" ]]; then
        read -r monitor_sys_clock < "${MONITOR_SYS_CLK_STAMP}" || true
    fi
    if [[ "${monitor_sys_clock}" != "${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}" ]]; then
        if [[ "${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}" != 25 ||
              -n "${monitor_sys_clock}" ]]; then
            printf 'ERROR: ULX3S 85F monitor preload clock is %s; requested %s MHz.\n' \
                "${monitor_sys_clock:-unrecorded}" "${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}" >&2
            echo 'Run the full board build to regenerate the clock-matched monitor.' >&2
            exit 1
        fi
        printf 'WARNING: Legacy 25 MHz monitor has no clock stamp; verify its provenance.\n' >&2
    fi

    case "${HAZARD3_HDMI_EXTENDED_MODES}" in
    0)
        VIDEO_PROFILE="vga640-standard"
        ;;
    1)
        VIDEO_PROFILE="vga640-extended"
        ;;
    *)
        echo "HAZARD3_HDMI_EXTENDED_MODES must be 0 or 1" >&2
        exit 1
        ;;
    esac

    if [[ -f "${SYNTH_PROFILE_STAMP}" ]]; then
        read -r current_video_profile < "${SYNTH_PROFILE_STAMP}" || true
    fi

    if [[ -f "${SYS_CLK_PROFILE_STAMP}" ]]; then
        read -r current_sys_clock < "${SYS_CLK_PROFILE_STAMP}" || true
    fi
    if [[ -f "${REGISTERED_HITS_PROFILE_STAMP}" ]]; then
        read -r current_registered_hits < "${REGISTERED_HITS_PROFILE_STAMP}" || true
    fi

    if [[ -f "${SRAM_WRITE_BUFFER_PROFILE_STAMP}" ]]; then
        read -r current_sram_write_buffer < "${SRAM_WRITE_BUFFER_PROFILE_STAMP}" || true
    fi
    if [[ -f "${SRAM_DUAL_PORT_PROFILE_STAMP}" ]]; then
        read -r current_sram_dual_port < "${SRAM_DUAL_PORT_PROFILE_STAMP}" || true
    fi
    if [[ -f "${CACHE_TAG_PIPELINE_PROFILE_STAMP}" ]]; then
        read -r current_cache_tag_pipeline < "${CACHE_TAG_PIPELINE_PROFILE_STAMP}" || true
    fi
    if [[ -f "${TAG_RAM_MODE_PROFILE_STAMP}" ]]; then
        read -r current_tag_ram_mode < "${TAG_RAM_MODE_PROFILE_STAMP}" || true
    fi
    if [[ -f "${CACHE_ADDR_PIPELINE_PROFILE_STAMP}" ]]; then
        read -r current_cache_addr_pipeline < "${CACHE_ADDR_PIPELINE_PROFILE_STAMP}" || true
    fi
    if [[ "${current_cache_addr_pipeline}" != "${HAZARD3_ULX3S_85F_CACHE_ADDR_PIPELINE}" ]]; then
        printf "ULX3S 85F AHB cache address pipeline changed: %s -> %s\n" \
            "${current_cache_addr_pipeline:-unrecorded}" "${HAZARD3_ULX3S_85F_CACHE_ADDR_PIPELINE}"
        profile_changed=1
    fi
    if [[ "${current_tag_ram_mode}" != "${HAZARD3_ULX3S_85F_TAG_RAM_MODE}" ]]; then
        printf 'ULX3S 85F tag RAM mode changed: %s -> %s\n' \
            "${current_tag_ram_mode:-unrecorded}" "${HAZARD3_ULX3S_85F_TAG_RAM_MODE}"
        profile_changed=1
    fi
    if [[ "${current_cache_tag_pipeline}" != "${HAZARD3_ULX3S_85F_CACHE_TAG_PIPELINE}" ]]; then
        printf 'ULX3S 85F cache tag pipeline changed: %s -> %s\n' \
            "${current_cache_tag_pipeline:-unrecorded}" "${HAZARD3_ULX3S_85F_CACHE_TAG_PIPELINE}"
        profile_changed=1
    fi
    if [[ "${current_sram_dual_port}" != "${HAZARD3_ULX3S_85F_SRAM_DUAL_PORT_RW}" ]]; then
        printf 'ULX3S 85F SRAM dual-port RW changed: %s -> %s\n' \
            "${current_sram_dual_port:-unrecorded}" "${HAZARD3_ULX3S_85F_SRAM_DUAL_PORT_RW}"
        profile_changed=1
    fi
    if [[ "${current_sram_write_buffer}" != "${HAZARD3_ULX3S_85F_SRAM_WRITE_BUFFER}" ]]; then
        printf 'ULX3S 85F SRAM write buffer changed: %s -> %s\n' \
            "${current_sram_write_buffer:-unrecorded}" "${HAZARD3_ULX3S_85F_SRAM_WRITE_BUFFER}"
        profile_changed=1
    fi
    if [[ "${current_registered_hits}" != "${HAZARD3_ULX3S_85F_REGISTERED_READ_HITS}" ]]; then
        printf 'ULX3S 85F registered cache hits changed: %s -> %s\n' \
            "${current_registered_hits:-unrecorded}" "${HAZARD3_ULX3S_85F_REGISTERED_READ_HITS}"
        profile_changed=1
    fi
    if [[ "${current_video_profile}" != "${VIDEO_PROFILE}" ]]; then
        printf 'ULX3S 85F HDMI profile changed: %s -> %s\n' \
            "${current_video_profile:-unrecorded}" "${VIDEO_PROFILE}"
        profile_changed=1
    fi
    if [[ "${current_sys_clock}" != "${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}" ]]; then
        printf 'ULX3S 85F system clock changed: %s -> %s MHz\n' \
            "${current_sys_clock:-unrecorded}" "${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}"
        profile_changed=1
    fi
    if [[ "${profile_changed}" == 1 ]]; then
        rm -f \
            "${NETLIST}" \
            "${CONFIG_OUTPUT}" \
            "${BITSTREAM_OUTPUT}" \
            "${SVF_OUTPUT}" \
            "${SEED_STAMP}" \
            "${SYNTH_LOG}" \
            "${SYNTH_DURATION_STAMP}"
    fi

    printf 'ULX3S 85F system clock: %s MHz (LFE5U-85F speed 6)\n' \
        "${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}"
    printf 'HDMI video profile: %s (extended modes=%s)\n' \
        "${VIDEO_PROFILE}" "${HAZARD3_HDMI_EXTENDED_MODES}"
    printf 'Registered cache-hit response: %s\n' "${HAZARD3_ULX3S_85F_REGISTERED_READ_HITS}"
    printf 'SRAM AHB write buffer: %s\n' "${HAZARD3_ULX3S_85F_SRAM_WRITE_BUFFER}"
    printf 'SRAM separate read/write ports: %s\n' "${HAZARD3_ULX3S_85F_SRAM_DUAL_PORT_RW}"
    printf 'SDRAM cache tag lookup pipeline: %s\n' "${HAZARD3_ULX3S_85F_CACHE_TAG_PIPELINE}"
    printf 'SDRAM tag RAM write mode: %s\n' "${HAZARD3_ULX3S_85F_TAG_RAM_MODE}"
    printf 'SDRAM cache AHB address pipeline: %s\n' "${HAZARD3_ULX3S_85F_CACHE_ADDR_PIPELINE}"
}

reuse_ulx3s_bitstream_if_allowed()
{
    local recorded_seed=""

    if [[ "${FORCE_BITSTREAM_REBUILD}" != 0 || ! -s "${BITSTREAM_OUTPUT}" ]]; then
        return
    fi
    if [[ -f "${SEED_STAMP}" ]]; then
        read -r recorded_seed < "${SEED_STAMP}" || true
    fi
    if [[ "${recorded_seed}" != "${NEXTPNR_SEED}" ]]; then
        printf 'ULX3S 85F seed changed: %s -> %s; rerouting.\n' \
            "${recorded_seed:-unrecorded}" "${NEXTPNR_SEED}"
        return
    fi
    if [[ "${NETLIST}" -nt "${BITSTREAM_OUTPUT}" ]]; then
        printf 'ULX3S 85F synthesized netlist is newer than the bitstream; rerouting.\n'
        return
    fi

    printf 'Reusing ULX3S 85F bitstream: %s (clock=%s MHz, seed=%s).\n' \
        "${BITSTREAM_OUTPUT}" "${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}" "${NEXTPNR_SEED}"
    stat -c 'bitstream: %n (modified %y, %s bytes)' -- "${BITSTREAM_OUTPUT}"
    printf 'Set FORCE_BITSTREAM_REBUILD=1 to reroute.\n'
    exit 0
}

prepare_ulx3s_12f_profile()
{
    local recorded_profile=""

    case "${HAZARD3_MEMORY_PROFILE}" in
    32m|64m)
        ;;
    *)
        echo "HAZARD3_MEMORY_PROFILE must be 32m or 64m for ULX3S 12F" >&2
        exit 1
        ;;
    esac

    if [[ -f "${SYNTH_PROFILE_STAMP}" ]]; then
        read -r recorded_profile < "${SYNTH_PROFILE_STAMP}" || true
    fi

    if [[ "${recorded_profile}" != "${HAZARD3_MEMORY_PROFILE}" ]]; then
        if [[ -n "${recorded_profile}" ]]; then
            printf 'ULX3S 12F SDRAM profile changed: %s -> %s\n' \
                "${recorded_profile}" "${HAZARD3_MEMORY_PROFILE}"
        else
            printf 'ULX3S 12F SDRAM profile is not recorded; rebuilding for %s.\n' \
                "${HAZARD3_MEMORY_PROFILE}"
        fi
        rm -f \
            "${NETLIST}" \
            "${CONFIG_OUTPUT}" \
            "${BITSTREAM_OUTPUT}" \
            "${SVF_OUTPUT}" \
            "${SEED_STAMP}" \
            "${SYNTH_LOG}"
    fi

    printf 'ULX3S 12F profile: compact 320x200, %s SDRAM\n' \
        "${HAZARD3_MEMORY_PROFILE}"
}

prepare_ulx4m_clock_profile()
{
    local recorded_profile=""

    case "${HAZARD3_ULX4M_SYS_CLK_MHZ}" in
    25|40|50)
        ;;
    *)
        echo "HAZARD3_ULX4M_SYS_CLK_MHZ must be 25, 40, or 50" >&2
        exit 1
        ;;
    esac

    if [[ -f "${SYNTH_PROFILE_STAMP}" ]]; then
        read -r recorded_profile < "${SYNTH_PROFILE_STAMP}" || true
    fi

    if [[ "${recorded_profile}" != "${HAZARD3_ULX4M_SYS_CLK_MHZ}" ]]; then
        if [[ "${SKIP_SYNTH}" == 1 ]]; then
            if [[ -n "${recorded_profile}" ]]; then
                printf 'ERROR: Frozen ULX4M-LD netlist system clock is %s MHz; requested %s MHz.\n' \
                    "${recorded_profile}" "${HAZARD3_ULX4M_SYS_CLK_MHZ}" >&2
            else
                printf 'ERROR: Frozen ULX4M-LD netlist system clock is not recorded; requested %s MHz.\n' \
                    "${HAZARD3_ULX4M_SYS_CLK_MHZ}" >&2
            fi
            echo "SKIP_SYNTH=1 will not delete or replace the existing synthesized netlist." >&2
            exit 1
        fi

        if [[ -n "${recorded_profile}" ]]; then
            printf 'ULX4M-LD system clock changed: %s MHz -> %s MHz\n' \
                "${recorded_profile}" "${HAZARD3_ULX4M_SYS_CLK_MHZ}"
        else
            printf 'ULX4M-LD system clock is not recorded; rebuilding for %s MHz.\n' \
                "${HAZARD3_ULX4M_SYS_CLK_MHZ}"
        fi
        rm -f \
            "${NETLIST}" \
            "${CONFIG_OUTPUT}" \
            "${BITSTREAM_OUTPUT}" \
            "${SVF_OUTPUT}" \
            "${SEED_STAMP}" \
            "${SYNTH_LOG}"
    fi

    printf 'ULX4M-LD system clock: %s MHz\n' "${HAZARD3_ULX4M_SYS_CLK_MHZ}"
}


validate_ulx4m_frozen_netlist()
{
    local recorded_litedram_cpu=""

    [[ -s "${NETLIST}" ]] || {
        echo "ERROR: Missing or empty frozen ULX4M-LD netlist: ${NETLIST}" >&2
        exit 1
    }

    if [[ ! -f "${LITEDRAM_CPU_STAMP}" ]]; then
        echo "ERROR: Frozen ULX4M-LD netlist LiteDRAM CPU is not recorded." >&2
        echo "Expected stamp: ${LITEDRAM_CPU_STAMP}" >&2
        echo "SKIP_SYNTH=1 cannot safely infer whether the existing netlist is SERV or VexRisc." >&2
        exit 1
    fi

    read -r recorded_litedram_cpu < "${LITEDRAM_CPU_STAMP}" || true
    if [[ "${recorded_litedram_cpu}" != "${ULX4M_LITEDRAM_CPU}" ]]; then
        printf 'ERROR: Frozen ULX4M-LD netlist LiteDRAM CPU is %s; requested %s.\n' \
            "${recorded_litedram_cpu:-<empty>}" "${ULX4M_LITEDRAM_CPU}" >&2
        echo "SKIP_SYNTH=1 will not delete or replace the existing synthesized netlist." >&2
        exit 1
    fi

    printf 'Using existing synthesized ULX4M-LD netlist; synthesis skipped.\n'
    printf 'ULX4M-LD frozen netlist SHA256: '
    sha256sum "${NETLIST}" | awk '{print $1}'
}

reuse_ulx3s_12f_bitstream_if_allowed()
{
    local recorded_seed=""

    if [[ -f "${SEED_STAMP}" ]]; then
        read -r recorded_seed < "${SEED_STAMP}" || true
    fi

    if [[ -s "${BITSTREAM_OUTPUT}" && "${FORCE_BITSTREAM_REBUILD}" == 0 ]]; then
        if [[ "${recorded_seed}" == "${NEXTPNR_SEED}" &&
              "${BITSTREAM_OUTPUT}" -nt "${NETLIST}" ]]; then
            printf 'Reusing existing ULX3S 12F bitstream built with seed %s and %s SDRAM profile.\n' \
                "${NEXTPNR_SEED}" "${HAZARD3_MEMORY_PROFILE}"
            stat -c '  %n (modified %y, %s bytes)' -- "${BITSTREAM_OUTPUT}"
            printf 'Set FORCE_BITSTREAM_REBUILD=1 to rebuild it.\n'
            exit 0
        fi

        if [[ -z "${recorded_seed}" ]]; then
            printf 'Existing ULX3S 12F bitstream has no seed stamp. Rebuilding with seed %s.\n' \
                "${NEXTPNR_SEED}"
        elif [[ "${recorded_seed}" != "${NEXTPNR_SEED}" ]]; then
            printf 'Existing ULX3S 12F bitstream used seed %s; requested seed is %s. Rebuilding.\n' \
                "${recorded_seed}" "${NEXTPNR_SEED}"
        else
            printf 'Synthesized ULX3S 12F netlist is newer than the existing bitstream. Rebuilding.\n'
        fi
    fi
}

reuse_ulx4m_bitstream_if_allowed()
{
    local recorded_seed=""
    local recorded_timingweight=""

    if [[ -f "${SEED_STAMP}" ]]; then
        read -r recorded_seed < "${SEED_STAMP}" || true
    fi
    if [[ -f "${TIMINGWEIGHT_STAMP}" ]]; then
        read -r recorded_timingweight < "${TIMINGWEIGHT_STAMP}" || true
    fi

    if [[ -s "${BITSTREAM_OUTPUT}" && "${FORCE_BITSTREAM_REBUILD}" == 0 ]]; then
        if [[ "${recorded_seed}" == "${NEXTPNR_SEED}" &&
              "${recorded_timingweight}" == "${NEXTPNR_HEAP_TIMINGWEIGHT}" &&
              "${BITSTREAM_OUTPUT}" -nt "${NETLIST}" ]]; then
            printf 'Reusing existing ULX4M-LD 85F bitstream built with seed %s and HeAP timingweight %s; nextpnr was not run.\n' \
                "${NEXTPNR_SEED}" "${NEXTPNR_HEAP_TIMINGWEIGHT}"
            stat -c '  %n (modified %y, %s bytes)' -- "${BITSTREAM_OUTPUT}"
            printf 'Set FORCE_BITSTREAM_REBUILD=1 to rebuild it.\n'
            exit 0
        fi

        if [[ -z "${recorded_seed}" ]]; then
            printf 'Existing ULX4M-LD bitstream has no seed stamp. Rebuilding with seed %s.\n' \
                "${NEXTPNR_SEED}"
        elif [[ "${recorded_seed}" != "${NEXTPNR_SEED}" ]]; then
            printf 'Existing ULX4M-LD bitstream used seed %s; requested seed is %s. Rebuilding.\n' \
                "${recorded_seed}" "${NEXTPNR_SEED}"
        elif [[ -z "${recorded_timingweight}" ]]; then
            printf 'Existing ULX4M-LD bitstream has no HeAP timingweight stamp. Rebuilding with timingweight %s.\n' \
                "${NEXTPNR_HEAP_TIMINGWEIGHT}"
        elif [[ "${recorded_timingweight}" != "${NEXTPNR_HEAP_TIMINGWEIGHT}" ]]; then
            printf 'Existing ULX4M-LD bitstream used HeAP timingweight %s; requested timingweight is %s. Rebuilding.\n' \
                "${recorded_timingweight}" "${NEXTPNR_HEAP_TIMINGWEIGHT}"
        else
            printf 'Synthesized ULX4M-LD netlist is newer than the existing bitstream. Rebuilding.\n'
        fi
    fi
}

run_synthesis()
{
    SYNTHESIS_RAN=0
    rm -f "${SYNTH_WORK_LOG}"

    case "${BOARD_ID}" in
    ulx3s-85f)
        if ! make -C "${HAZARD3_SYNTH}" -f "${MAKEFILE}" \
            CHIPNAME="${BUILD_DIR}/${FPGA_NAME}" \
            HAZARD3_ULX3S_85F_SYS_CLK_MHZ="${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}" \
            HAZARD3_ULX3S_85F_REGISTERED_READ_HITS="${HAZARD3_ULX3S_85F_REGISTERED_READ_HITS}" \
            HAZARD3_ULX3S_85F_SRAM_WRITE_BUFFER="${HAZARD3_ULX3S_85F_SRAM_WRITE_BUFFER}" \
            HAZARD3_ULX3S_85F_SRAM_DUAL_PORT_RW="${HAZARD3_ULX3S_85F_SRAM_DUAL_PORT_RW}" \
            HAZARD3_ULX3S_85F_CACHE_TAG_PIPELINE="${HAZARD3_ULX3S_85F_CACHE_TAG_PIPELINE}" \
            HAZARD3_ULX3S_85F_TAG_RAM_MODE="${HAZARD3_ULX3S_85F_TAG_RAM_MODE}" \
            HAZARD3_ULX3S_85F_CACHE_ADDR_PIPELINE="${HAZARD3_ULX3S_85F_CACHE_ADDR_PIPELINE}" \
            HAZARD3_HDMI_EXTENDED_MODES="${HAZARD3_HDMI_EXTENDED_MODES}" synth; then
            move_synth_log
            exit 1
        fi
        ;;
    ulx3s-12f)
        if ! make -C "${HAZARD3_SYNTH}" -f "${MAKEFILE}" \
            CHIPNAME="${BUILD_DIR}/${FPGA_NAME}" \
            HAZARD3_MEMORY_PROFILE="${HAZARD3_MEMORY_PROFILE}" \
            HAZARD3_HDMI_EXTENDED_MODES=0 synth; then
            move_synth_log
            exit 1
        fi
        ;;
    ulx4m-ld-85f)
        if ! DEFINES="${DEFINES:+${DEFINES} }HAZARD3_ULX4M_SYS_CLK_MHZ=${HAZARD3_ULX4M_SYS_CLK_MHZ}" \
            make -C "${HAZARD3_SYNTH}" -f "${MAKEFILE}" \
                CHIPNAME="${BUILD_DIR}/${FPGA_NAME}" \
                ULX4M_LITEDRAM_CPU="${ULX4M_LITEDRAM_CPU}" synth; then
            move_synth_log
            exit 1
        fi
        ;;
    *)
        if ! make -C "${HAZARD3_SYNTH}" -f "${MAKEFILE}" \
            CHIPNAME="${BUILD_DIR}/${FPGA_NAME}" synth; then
            move_synth_log
            exit 1
        fi
        ;;
    esac

    move_synth_log
    require_file "${NETLIST}"
    require_file "${SYNTH_LOG}"

    case "${BOARD_ID}" in
    ulx3s-85f)
        printf '%s\n' "${VIDEO_PROFILE}" > "${SYNTH_PROFILE_STAMP}"
        printf '%s\n' "${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}" > "${SYS_CLK_PROFILE_STAMP}"
        printf '%s\n' "${HAZARD3_ULX3S_85F_REGISTERED_READ_HITS}" > "${REGISTERED_HITS_PROFILE_STAMP}"
        printf '%s\n' "${HAZARD3_ULX3S_85F_SRAM_WRITE_BUFFER}" > "${SRAM_WRITE_BUFFER_PROFILE_STAMP}"
        printf '%s\n' "${HAZARD3_ULX3S_85F_SRAM_DUAL_PORT_RW}" > "${SRAM_DUAL_PORT_PROFILE_STAMP}"
        printf '%s\n' "${HAZARD3_ULX3S_85F_CACHE_TAG_PIPELINE}" > "${CACHE_TAG_PIPELINE_PROFILE_STAMP}"
        printf '%s\n' "${HAZARD3_ULX3S_85F_TAG_RAM_MODE}" > "${TAG_RAM_MODE_PROFILE_STAMP}"
        printf '%s\n' "${HAZARD3_ULX3S_85F_CACHE_ADDR_PIPELINE}" > "${CACHE_ADDR_PIPELINE_PROFILE_STAMP}"
        ;;
    ulx3s-12f)
        printf '%s\n' "${HAZARD3_MEMORY_PROFILE}" > "${SYNTH_PROFILE_STAMP}"
        ;;
    ulx4m-ld-85f)
        printf '%s\n' "${HAZARD3_ULX4M_SYS_CLK_MHZ}" > "${SYNTH_PROFILE_STAMP}"
        install -m 0644 "${LITEDRAM_CONFIG}" "${LITEDRAM_CONFIG_SNAPSHOT}"
        ;;
    esac
}

validate_ulx4m_synthesis()
{
    local ebr_used

    if [[ "${HAZARD3_ULX4M_SYS_CLK_MHZ}" == 25 ]]; then
        if grep -Eq \
            "Used module:[[:space:]]+\\\\pll_25_(40|50)$" \
            "${SYNTH_SOURCE_LOG}"; then
            echo "ERROR: ULX4M-LD 25 MHz profile unexpectedly synthesized a system PLL." >&2
            exit 1
        fi
    elif ! grep -Eq \
        "Used module:[[:space:]]+\\\\pll_25_${HAZARD3_ULX4M_SYS_CLK_MHZ}$" \
        "${SYNTH_SOURCE_LOG}"; then
        echo "ERROR: ULX4M-LD did not synthesize the requested ${HAZARD3_ULX4M_SYS_CLK_MHZ} MHz system PLL." >&2
        exit 1
    fi
    if ! grep -Fq \
        "Parameter \\CLK_MHZ = ${HAZARD3_ULX4M_SYS_CLK_MHZ}" \
        "${SYNTH_SOURCE_LOG}"; then
        echo "ERROR: ULX4M-LD example_soc CLK_MHZ does not match the requested system clock." >&2
        exit 1
    fi

    # ULX4M-LD cannot fit the extended 400x240/512x300 framebuffer alongside
    # LiteDRAM. Verify the synthesized hierarchy selected the standard 64-bank
    # framebuffer before running the much more expensive place-and-route stage.
    if ! grep -Fq \
        "ulx3s_frame_ram\\BANK_COUNT=s32'00000000000000000000000001000000" \
        "${SYNTH_SOURCE_LOG}"; then
        echo "ERROR: ULX4M-LD did not synthesize the standard 320x200 framebuffer." >&2
        echo "Expected ulx3s_frame_ram BANK_COUNT=64 (EXTENDED_VIDEO_MODES=0)." >&2
        echo "Check the Hazard3 commit pinned by third_party/Hazard3." >&2
        grep -F "ulx3s_frame_ram\\BANK_COUNT=" \
            "${SYNTH_SOURCE_LOG}" >&2 || true
        exit 1
    fi

    ebr_used="$(awk '$2 == "DP16KD" {used=$1} END {print used}' \
        "${SYNTH_SOURCE_LOG}")"
    if [[ -z "${ebr_used}" ]]; then
        echo "ERROR: Could not determine ULX4M-LD DP16KD usage from synth.log." >&2
        exit 1
    fi
    if (( ebr_used > 208 )); then
        echo "ERROR: ULX4M-LD synthesis uses ${ebr_used} DP16KD blocks; device limit is 208." >&2
        exit 1
    fi
    printf 'ULX4M-LD synthesis check: standard framebuffer, %s/208 DP16KD.\n' \
        "${ebr_used}"
}

validate_ulx3s_12f_synthesis()
{
    local ebr_used

    ebr_used="$(awk '$2 == "DP16KD" {used=$1} END {print used}' \
        "${SYNTH_SOURCE_LOG}")"
    if [[ -z "${ebr_used}" ]]; then
        echo "ERROR: Could not determine ULX3S 12F DP16KD usage from synth.log." >&2
        exit 1
    fi
    if (( ebr_used > 32 )); then
        echo "ERROR: ULX3S 12F synthesis uses ${ebr_used} DP16KD blocks; LFE5U-12F limit is 32." >&2
        echo "The 12F build must use the compact SDRAM scanout/cache profile before nextpnr." >&2
        exit 1
    fi

    # A full 85F-style frame RAM is a configuration error even if some future
    # optimization happened to squeeze its reported EBR usage. Catch it here
    # before starting nextpnr.
    if grep -Fq "ulx3s_frame_ram\BANK_COUNT=" "${SYNTH_SOURCE_LOG}"; then
        echo "ERROR: ULX3S 12F synthesized the full EBR framebuffer hierarchy." >&2
        echo "Expected ulx3s_hdmi_sdram_scanout selected by HAZARD3_ULX3S_12F." >&2
        grep -F "ulx3s_frame_ram\BANK_COUNT=" "${SYNTH_SOURCE_LOG}" >&2 || true
        exit 1
    fi

    printf 'ULX3S 12F synthesis check: compact profile, %s/32 DP16KD.\n' \
        "${ebr_used}"
}

validate_ulx3s_12f_system_timing()
{
    local timing_line

    timing_line="$(grep "Max frequency for clock.*clk_sys" "${PNR_LOG}" |
        tail -n 1)"
    if [[ -z "${timing_line}" ]]; then
        echo "ERROR: Could not find the final ULX3S 12F clk_sys timing result." >&2
        exit 1
    fi

    printf 'ULX3S 12F system timing: %s\n' "${timing_line}"
    if [[ "${timing_line}" != *"PASS at 40.00 MHz"* ]]; then
        echo "ERROR: ULX3S 12F clk_sys does not meet 40 MHz." >&2
        exit 1
    fi
}

# ULX3S seed reference from scripts/sweep.sh:
#
# |   Seed |          `clk_sys` |
# | -----: | -----------------: |
# | **178** | **55.89 MHz PASS** |
# |    185 |     55.11 MHz PASS |
# |    197 |     54.45 MHz PASS |
# |    112 |     54.32 MHz PASS |
# |    179 |     54.28 MHz PASS |
# |     46 |     54.27 MHz PASS |
# |    232 |     54.26 MHz PASS |
# |     26 |     54.22 MHz PASS |
# |     12 |     54.21 MHz PASS |
# |     64 |     53.82 MHz PASS |
#
# ULX4M-LD qualified route reference from the 40/60 MHz ablation:
#
# | Seed | HeAP timingweight | clk_sys | LiteDRAM | Result |
# | ---: | ----------------: | ------: | -------: | :----- |
# |    2 |                30 | 43.94   | 67.81    | PASS   |
#
# critexp=3 and tmg-ripup did not improve this seed over timingweight=30 alone.
# Keep the normal build on the simpler qualified route unless a new sweep shows
# a better setting for a changed netlist/toolchain.
#
# Manually maintained last-observed nextpnr routing durations (minutes).
# These are estimates, not timeouts. Actual durations vary with seed, netlist,
# speed grade, nextpnr version, and machine. Update after each measured run.
# Set 0 until a completed route duration is known (no ETA will be printed).
# ULX3S 85F: prior seed 11 took about 12 minutes.
# ULX3S 12F: no verified completed-route duration yet.
# ULX4M-LD 85F: prior seed 2 took about 8 minutes.
# Each value can also be overridden in the environment without editing this file.
ULX3S_85F_LAST_SEEN_ROUTE_MINUTES="${ULX3S_85F_LAST_SEEN_ROUTE_MINUTES:-12}"
ULX3S_12F_LAST_SEEN_ROUTE_MINUTES="${ULX3S_12F_LAST_SEEN_ROUTE_MINUTES:-5}"
ULX4M_LD_85F_LAST_SEEN_ROUTE_MINUTES="${ULX4M_LD_85F_LAST_SEEN_ROUTE_MINUTES:-8}"

PNR_TUNING_ARGS=()
ecp5_board_defaults "${BOARD_ID}"

case "${BOARD_ID}" in
ulx3s-85f)
    DISPLAY_NAME="ULX3S 85F"
    FPGA_NAME="fpga_ulx3s_85f"
    MAKEFILE="ULX3S.mk"
    LPF="${HAZARD3_SYNTH}/fpga_ulx3s.lpf"
    IDCODE="0x41113043"
    NEXTPNR_SEED="${NEXTPNR_SEED:-${ULX3S_85F_DEFAULT_NEXTPNR_SEED}}"
    LAST_SEEN_ROUTE_MINUTES="${ULX3S_85F_LAST_SEEN_ROUTE_MINUTES}"
    ecp5_pnr_device_profile "ulx3s-85f"
    HAZARD3_HDMI_EXTENDED_MODES="${HAZARD3_HDMI_EXTENDED_MODES:-0}"
    ecp5_ulx3s_85f_clock_profile
    SYNTH_PROFILE_STAMP="${BUILD_DIR}/fpga_ulx3s_85f.video-profile"
    SYS_CLK_PROFILE_STAMP="${BUILD_DIR}/fpga_ulx3s_85f.sys-clk-mhz"
    REGISTERED_HITS_PROFILE_STAMP="${BUILD_DIR}/fpga_ulx3s_85f.registered-read-hits"
    SRAM_WRITE_BUFFER_PROFILE_STAMP="${BUILD_DIR}/fpga_ulx3s_85f.sram-write-buffer"
    SRAM_DUAL_PORT_PROFILE_STAMP="${BUILD_DIR}/fpga_ulx3s_85f.sram-dual-port-rw"
    CACHE_TAG_PIPELINE_PROFILE_STAMP="${BUILD_DIR}/fpga_ulx3s_85f.cache-tag-pipeline"
    TAG_RAM_MODE_PROFILE_STAMP="${BUILD_DIR}/fpga_ulx3s_85f.tag-ram-mode"
    CACHE_ADDR_PIPELINE_PROFILE_STAMP="${BUILD_DIR}/fpga_ulx3s_85f.cache-addr-pipeline"
    MONITOR_SYS_CLK_STAMP="${BUILD_DIR}/ulx3s-85f/monitor-sys-clk-mhz"
    SYNTH_DURATION_STAMP="${BUILD_DIR}/fpga_ulx3s_85f.synth-seconds"
    SEED_STAMP="${BUILD_DIR}/fpga_ulx3s_85f.seed"
    ;;
ulx3s-12f)
    DISPLAY_NAME="ULX3S 12F"
    FPGA_NAME="fpga_ulx3s_12f"
    MAKEFILE="ULX3S_12F.mk"
    LPF="${HAZARD3_SYNTH}/fpga_ulx3s.lpf"
    IDCODE="0x21111043"
    NEXTPNR_SEED="${NEXTPNR_SEED:-${ECP5_DEFAULT_NEXTPNR_SEED}}"
    LAST_SEEN_ROUTE_MINUTES="${ULX3S_12F_LAST_SEEN_ROUTE_MINUTES}"
    ecp5_pnr_device_profile "ulx3s-12f"
    HAZARD3_MEMORY_PROFILE="${HAZARD3_MEMORY_PROFILE:-32m}"
    SYNTH_PROFILE_STAMP="${BUILD_DIR}/fpga_ulx3s_12f.memory-profile"
    SYNTH_DURATION_STAMP="${BUILD_DIR}/fpga_ulx3s_12f.synth-seconds"
    SEED_STAMP="${BUILD_DIR}/fpga_ulx3s_12f.seed"
    ;;
ulx4m-ld-85f)
    DISPLAY_NAME="ULX4M-LD 85F"
    FPGA_NAME="fpga_ulx4m_ld"
    MAKEFILE="ULX4M_LD_85F.mk"
    LPF="${HAZARD3_SYNTH}/fpga_ulx4m_ld.lpf"
    IDCODE="0x01113043"
    NEXTPNR_SEED="${NEXTPNR_SEED:-${ECP5_DEFAULT_NEXTPNR_SEED}}"
    LAST_SEEN_ROUTE_MINUTES="${ULX4M_LD_85F_LAST_SEEN_ROUTE_MINUTES}"
    NEXTPNR_HEAP_TIMINGWEIGHT="${NEXTPNR_HEAP_TIMINGWEIGHT:-${SWEEP_NEXTPNR_HEAP_TIMINGWEIGHT:-${ECP5_DEFAULT_NEXTPNR_HEAP_TIMINGWEIGHT}}}"
    if [[ ! "${NEXTPNR_HEAP_TIMINGWEIGHT}" =~ ^[1-9][0-9]*$ ]]; then
        echo "NEXTPNR_HEAP_TIMINGWEIGHT must be a positive integer." >&2
        exit 1
    fi
    # See also --placer-heap-timingweight setting in scripts/sweep-ecp5-common.sh
    PNR_TUNING_ARGS=(--placer-heap-timingweight "${NEXTPNR_HEAP_TIMINGWEIGHT}")
    ecp5_pnr_device_profile "ulx4m-ld-85f"
    LITEDRAM_DIR="${HAZARD3_ROOT}/example_soc/third_party/LiteDRAM"
    ULX4M_LITEDRAM_CPU="${ULX4M_LITEDRAM_CPU:-serv}"
    case "${ULX4M_LITEDRAM_CPU}" in
    serv|vexrisc)
        ;;
    *)
        echo "ULX4M_LITEDRAM_CPU must be serv or vexrisc" >&2
        exit 1
        ;;
    esac
    LITEDRAM_GENERATED_DIR="${LITEDRAM_DIR}/generated-${ULX4M_LITEDRAM_CPU}"
    LITEDRAM_CONFIG="${LITEDRAM_GENERATED_DIR}/litedram_ulx4m_cpu.yml"
    LITEDRAM_CONFIG_SNAPSHOT="${BUILD_DIR}/fpga_ulx4m_ld.litedram-config.yml"
    HAZARD3_ULX4M_SYS_CLK_MHZ="${HAZARD3_ULX4M_SYS_CLK_MHZ:-40}"
    SYNTH_PROFILE_STAMP="${BUILD_DIR}/fpga_ulx4m_ld.sys-clk-mhz"
    SYNTH_DURATION_STAMP="${BUILD_DIR}/fpga_ulx4m_ld.synth-seconds"
    LITEDRAM_CPU_STAMP="${BUILD_DIR}/fpga_ulx4m_ld.litedram-cpu"
    SEED_STAMP="${BUILD_DIR}/fpga_ulx4m_ld.seed"
    TIMINGWEIGHT_STAMP="${BUILD_DIR}/fpga_ulx4m_ld.heap-timingweight"
    ;;
*)
    echo "Unknown ECP5 board target: ${BOARD_ID:-<empty>}" >&2
    echo "Expected ulx3s-85f, ulx3s-12f, or ulx4m-ld-85f." >&2
    exit 2
    ;;
esac

# Validate before starting synthesis; only nonnegative whole minutes are valid.
if [[ ! "${LAST_SEEN_ROUTE_MINUTES}" =~ ^(0|[1-9][0-9]*)$ ]]; then
    printf 'ERROR: Last-seen route minutes for %s must be a nonnegative whole number.\n' \
        "${BOARD_ID}" >&2
    exit 1
fi

NETLIST="${BUILD_DIR}/${FPGA_NAME}.json"
SYNTH_WORK_LOG="${HAZARD3_SYNTH}/synth.log"
BITSTREAM_OUTPUT="${BUILD_DIR}/${FPGA_NAME}.bit"
CONFIG_OUTPUT="${BUILD_DIR}/${FPGA_NAME}.config"
SVF_OUTPUT="${BUILD_DIR}/${FPGA_NAME}.svf"
PNR_LOG="${BUILD_DIR}/${FPGA_NAME}.pnr.log"
SYNTH_LOG="${BUILD_DIR}/${FPGA_NAME}.synth.log"
SYNTH_SOURCE_LOG="${SYNTH_LOG}"
CONFIG_TEMP="${CONFIG_OUTPUT}.tmp.$$"
BITSTREAM_TEMP="${BITSTREAM_OUTPUT}.tmp.$$"
SVF_TEMP="${SVF_OUTPUT}.tmp.$$"

case "${ALLOW_TIMING_FAILURE}" in
0)
    timing_options=()
    ;;
1)
    if [[ "${BOARD_ID}" != "ulx4m-ld-85f" ]]; then
        echo "ALLOW_TIMING_FAILURE=1 is supported only for ULX4M-LD sweep experiments." >&2
        exit 1
    fi
    timing_options=(--timing-allow-fail)
    ;;
*)
    echo "ALLOW_TIMING_FAILURE must be 0 or 1" >&2
    exit 1
    ;;
esac

case "${FORCE_BITSTREAM_REBUILD}" in
0|1)
    ;;
*)
    echo "FORCE_BITSTREAM_REBUILD must be 0 or 1" >&2
    exit 1
    ;;
esac

case "${SKIP_SYNTH}" in
0|1)
    ;;
*)
    echo "SKIP_SYNTH must be 0 or 1" >&2
    exit 1
    ;;
esac

if [[ "${SKIP_SYNTH}" == 1 && "${BOARD_ID}" != "ulx4m-ld-85f" ]]; then
    echo "SKIP_SYNTH=1 is currently supported only for ulx4m-ld-85f." >&2
    exit 1
fi

mkdir -p "${BUILD_DIR}"

require_tool stat
require_tool nextpnr-ecp5
require_tool ecppack
require_file "${LPF}"

if [[ "${SKIP_SYNTH}" == 0 ]]; then
    require_tool make
    require_tool yosys
    require_file "${HAZARD3_SYNTH}/${MAKEFILE}"
else
    require_tool sha256sum
fi

if [[ "${BOARD_ID}" == "ulx4m-ld-85f" ]]; then
    require_tool grep
    require_tool awk
    if [[ "${SKIP_SYNTH}" == 0 ]]; then
        require_tool install
        require_file "${LITEDRAM_DIR}/litedram_ulx4m_cpu.v"
        require_file "${LITEDRAM_GENERATED_DIR}/litedram_ulx4m_cpu.v"
        require_file "${LITEDRAM_GENERATED_DIR}/litedram_ulx4m_cpu_rom.init"
        require_file "${LITEDRAM_GENERATED_DIR}/litedram_ulx4m_cpu_sram.init"
        require_file "${LITEDRAM_CONFIG}"
    fi
fi

if [[ "${BOARD_ID}" == "ulx3s-12f" ]]; then
    require_tool grep
    require_tool awk
    require_file "${HAZARD3_ROOT}/example_soc/soc/cache_tags_zero_12f.hex"
    require_file "${HAZARD3_ROOT}/example_soc/soc/hazard3-12f-bootstrap.hex"
fi

if [[ "${BOARD_ID}" == "ulx3s-85f" ]]; then
    prepare_ulx3s_video_profile
fi
if [[ "${BOARD_ID}" == "ulx3s-12f" ]]; then
    prepare_ulx3s_12f_profile
fi
if [[ "${BOARD_ID}" == "ulx4m-ld-85f" ]]; then
    prepare_ulx4m_clock_profile
fi

if [[ "${SKIP_SYNTH}" == 1 ]]; then
    validate_ulx4m_frozen_netlist
else
    synth_start_seconds="$(date +%s)"
    run_synthesis
    if [[ "${SYNTHESIS_RAN}" == 1 ]]; then
        printf '%s\n' "$(( $(date +%s) - synth_start_seconds ))" \
            > "${SYNTH_DURATION_STAMP}"
    fi
fi

if [[ "${BOARD_ID}" == "ulx3s-85f" ]]; then
    reuse_ulx3s_bitstream_if_allowed
fi
if [[ "${BOARD_ID}" == "ulx3s-12f" ]]; then
    validate_ulx3s_12f_synthesis
    reuse_ulx3s_12f_bitstream_if_allowed
fi
if [[ "${BOARD_ID}" == "ulx4m-ld-85f" ]]; then
    if [[ "${SKIP_SYNTH}" == 0 ]]; then
        validate_ulx4m_synthesis
    fi
    reuse_ulx4m_bitstream_if_allowed
fi

printf 'nextpnr seed: %s\n' "${NEXTPNR_SEED}"
if [[ "${BOARD_ID}" == "ulx4m-ld-85f" ]]; then
    printf 'nextpnr HeAP timingweight: %s\n' "${NEXTPNR_HEAP_TIMINGWEIGHT}"
fi
if [[ "${ALLOW_TIMING_FAILURE}" == 1 ]]; then
    printf 'WARNING: timing failure is allowed for this development build.\n' >&2
fi

cleanup_temporary_outputs()
{
    rm -f "${CONFIG_TEMP}" "${BITSTREAM_TEMP}" "${SVF_TEMP}"
}
trap cleanup_temporary_outputs EXIT
cleanup_temporary_outputs

(
    cd "${HAZARD3_SYNTH}"

    route_start_seconds="$(date +%s)"
    route_start_time="$(date '+%Y-%m-%d %H:%M:%S %Z')"
    printf 'Seed %s route start: %s\n' "${NEXTPNR_SEED}" "${route_start_time}"
    if [[ "${LAST_SEEN_ROUTE_MINUTES}" == 0 ]]; then
        printf 'Seed %s route expected completion: unknown (no last-seen duration for %s)\n' \
            "${NEXTPNR_SEED}" "${BOARD_ID}"
    else
        # GNU date converts epoch seconds back into the local date/time zone.
        route_expected_seconds="$((route_start_seconds + LAST_SEEN_ROUTE_MINUTES * 60))"
        route_expected_time="$(date -d "@${route_expected_seconds}" '+%Y-%m-%d %H:%M:%S %Z')"
        printf 'Seed %s route expected completion: %s (last seen: %s min)\n' \
            "${NEXTPNR_SEED}" "${route_expected_time}" "${LAST_SEEN_ROUTE_MINUTES}"
    fi

    if nextpnr-ecp5 \
        --seed "${NEXTPNR_SEED}" \
        --placer heap \
        "${PNR_TUNING_ARGS[@]}" \
        "${PNR_DEVICE_ARGS[@]}" \
        --lpf "${LPF}" \
        --json "${NETLIST}" \
        --textcfg "${CONFIG_TEMP}" \
        "${timing_options[@]}" \
        --quiet \
        --log "${PNR_LOG}"; then
        route_status=0
    else
        route_status=$?
    fi

    route_end_seconds="$(date +%s)"
    route_end_time="$(date '+%Y-%m-%d %H:%M:%S %Z')"
    route_seconds="$((route_end_seconds - route_start_seconds))"

    printf 'Seed %s route end:   %s\n' "${NEXTPNR_SEED}" "${route_end_time}"
    printf 'Seed %s route elapsed: %ss\n' "${NEXTPNR_SEED}" "${route_seconds}"

    if (( route_status != 0 )); then
        exit "${route_status}"
    fi

    if [[ "${BOARD_ID}" == "ulx3s-12f" ]]; then
        validate_ulx3s_12f_system_timing
    fi

    ecppack \
        --compress \
        --svf "${SVF_TEMP}" \
        --idcode "${IDCODE}" \
        "${CONFIG_TEMP}" \
        "${BITSTREAM_TEMP}"
)

# Promote a matched config/SVF/bitstream set only after both P&R and packaging
# succeed. The canonical P&R log intentionally records the latest attempt,
# including a failed one.
mv -f "${CONFIG_TEMP}" "${CONFIG_OUTPUT}"
mv -f "${SVF_TEMP}" "${SVF_OUTPUT}"
mv -f "${BITSTREAM_TEMP}" "${BITSTREAM_OUTPUT}"

if [[ -n "${SEED_STAMP:-}" ]]; then
    printf '%s\n' "${NEXTPNR_SEED}" > "${SEED_STAMP}"
fi
if [[ -n "${TIMINGWEIGHT_STAMP:-}" ]]; then
    printf '%s\n' "${NEXTPNR_HEAP_TIMINGWEIGHT}" > "${TIMINGWEIGHT_STAMP}"
fi

printf '%s bitstream: %s\n' "${DISPLAY_NAME}" "${BITSTREAM_OUTPUT}"
if [[ -n "${SEED_STAMP:-}" ]]; then
    printf '%s seed stamp: %s (seed %s)\n' \
        "${DISPLAY_NAME}" "${SEED_STAMP}" "${NEXTPNR_SEED}"
fi
if [[ -n "${TIMINGWEIGHT_STAMP:-}" ]]; then
    printf '%s HeAP timingweight stamp: %s (timingweight %s)\n' \
        "${DISPLAY_NAME}" "${TIMINGWEIGHT_STAMP}" "${NEXTPNR_HEAP_TIMINGWEIGHT}"
fi
