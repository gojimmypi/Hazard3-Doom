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

set -euo pipefail

# Default nextpnr routing settings. Keep these together so board defaults are
# easy to find and update after timing sweeps. NEXTPNR_SEED still overrides the
# selected board seed when provided by the caller. ULX4M-LD also accepts
# NEXTPNR_HEAP_TIMINGWEIGHT as an override for its qualified HeAP timing weight.
#
# Seeds are both yosys and nextpnr version-specific:
#   yosys --version && nextpnr-ecp5 --version
#   Yosys 0.67 (git sha1 2d1509d1b, Release, GNU /usr/bin/c++ 11.4.0)
#   "nextpnr-ecp5" -- Next Generation Place and Route (Version nextpnr-0.10-95-gddc6c8c8)
ULX3S_85F_DEFAULT_NEXTPNR_SEED=11
ULX3S_12F_DEFAULT_NEXTPNR_SEED=82
ULX4M_LD_85F_DEFAULT_NEXTPNR_SEED=1
ULX4M_LD_85F_DEFAULT_NEXTPNR_HEAP_TIMINGWEIGHT=30

BOARD_ID="${1:-}"
shift || true

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
HAZARD3_ROOT="${HAZARD3_ROOT:-${REPO_ROOT}/third_party/Hazard3}"
HAZARD3_SYNTH="${HAZARD3_ROOT}/example_soc/synth"
BUILD_DIR="${REPO_ROOT}/build"
ALLOW_TIMING_FAILURE="${ALLOW_TIMING_FAILURE:-0}"
FORCE_BITSTREAM_REBUILD="${FORCE_BITSTREAM_REBUILD:-0}"
SKIP_SYNTH="${SKIP_SYNTH:-0}"

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

copy_synth_log()
{
    if [[ -f "${SYNTH_SOURCE_LOG}" ]]; then
        cp "${SYNTH_SOURCE_LOG}" "${SYNTH_LOG}"
    fi
}

prepare_ulx3s_video_profile()
{
    local current_video_profile=""

    case "${HAZARD3_HDMI_EXTENDED_MODES}" in
    0)
        VIDEO_PROFILE="standard"
        ;;
    1)
        VIDEO_PROFILE="extended"
        ;;
    *)
        echo "HAZARD3_HDMI_EXTENDED_MODES must be 0 or 1" >&2
        exit 1
        ;;
    esac

    if [[ -f "${SYNTH_PROFILE_STAMP}" ]]; then
        read -r current_video_profile < "${SYNTH_PROFILE_STAMP}" || true
    fi

    if [[ "${current_video_profile}" != "${VIDEO_PROFILE}" ]]; then
        if [[ -n "${current_video_profile}" ]]; then
            printf 'HDMI video profile changed: %s -> %s\n' \
                "${current_video_profile}" "${VIDEO_PROFILE}"
        else
            printf 'HDMI video profile is not recorded; rebuilding for %s mode.\n' \
                "${VIDEO_PROFILE}"
        fi
        rm -f \
            "${NETLIST}" \
            "${CONFIG_OUTPUT}" \
            "${BITSTREAM_OUTPUT}" \
            "${SVF_OUTPUT}" \
            "${HAZARD3_SYNTH}/${FPGA_NAME}.config" \
            "${HAZARD3_SYNTH}/${FPGA_NAME}.bit" \
            "${HAZARD3_SYNTH}/${FPGA_NAME}.svf"
    fi

    printf 'HDMI video profile: %s (extended modes=%s)\n' \
        "${VIDEO_PROFILE}" "${HAZARD3_HDMI_EXTENDED_MODES}"
}

reuse_ulx3s_bitstream_if_allowed()
{
    if [[ -s "${BITSTREAM_OUTPUT}" && "${FORCE_BITSTREAM_REBUILD}" == 0 ]]; then
        printf '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n'
        printf 'Reusing existing ULX3S 85F bitstream in %s\n' "${BITSTREAM_OUTPUT}"
        printf 'nextpnr was not run!!!\n'
        stat -c 'bitstream:  %n (modified %y, %s bytes)' -- "${BITSTREAM_OUTPUT}"
        printf 'Set FORCE_BITSTREAM_REBUILD=1 to rebuild it.\n'
        printf '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n'
        exit 0
    fi
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
            "${HAZARD3_SYNTH}/${FPGA_NAME}.config" \
            "${HAZARD3_SYNTH}/${FPGA_NAME}.bit" \
            "${HAZARD3_SYNTH}/${FPGA_NAME}.svf"
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
            "${HAZARD3_SYNTH}/${FPGA_NAME}.config" \
            "${HAZARD3_SYNTH}/${FPGA_NAME}.bit" \
            "${HAZARD3_SYNTH}/${FPGA_NAME}.svf"
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
    case "${BOARD_ID}" in
    ulx3s-85f)
        if ! make -C "${HAZARD3_SYNTH}" -f "${MAKEFILE}" \
            HAZARD3_HDMI_EXTENDED_MODES="${HAZARD3_HDMI_EXTENDED_MODES}" synth; then
            copy_synth_log
            exit 1
        fi
        ;;
    ulx3s-12f)
        if ! make -C "${HAZARD3_SYNTH}" -f "${MAKEFILE}" \
            HAZARD3_MEMORY_PROFILE="${HAZARD3_MEMORY_PROFILE}" \
            HAZARD3_HDMI_EXTENDED_MODES=0 synth; then
            copy_synth_log
            exit 1
        fi
        ;;
    ulx4m-ld-85f)
        if ! DEFINES="${DEFINES:+${DEFINES} }HAZARD3_ULX4M_SYS_CLK_MHZ=${HAZARD3_ULX4M_SYS_CLK_MHZ}" \
            make -C "${HAZARD3_SYNTH}" -f "${MAKEFILE}" \
                ULX4M_LITEDRAM_CPU="${ULX4M_LITEDRAM_CPU}" synth; then
            copy_synth_log
            exit 1
        fi
        ;;
    *)
        if ! make -C "${HAZARD3_SYNTH}" -f "${MAKEFILE}" synth; then
            copy_synth_log
            exit 1
        fi
        ;;
    esac

    require_file "${NETLIST}"
    require_file "${SYNTH_SOURCE_LOG}"
    copy_synth_log

    case "${BOARD_ID}" in
    ulx3s-85f)
        printf '%s\n' "${VIDEO_PROFILE}" > "${SYNTH_PROFILE_STAMP}"
        ;;
    ulx3s-12f)
        printf '%s\n' "${HAZARD3_MEMORY_PROFILE}" > "${SYNTH_PROFILE_STAMP}"
        ;;
    ulx4m-ld-85f)
        printf '%s\n' "${HAZARD3_ULX4M_SYS_CLK_MHZ}" > "${SYNTH_PROFILE_STAMP}"
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
PNR_TUNING_ARGS=()

case "${BOARD_ID}" in
ulx3s-85f)
    DISPLAY_NAME="ULX3S 85F"
    FPGA_NAME="fpga_ulx3s"
    MAKEFILE="ULX3S.mk"
    LPF="${HAZARD3_SYNTH}/fpga_ulx3s.lpf"
    IDCODE="0x41113043"
    NEXTPNR_SEED="${NEXTPNR_SEED:-${ULX3S_85F_DEFAULT_NEXTPNR_SEED}}"
    PNR_DEVICE_ARGS=(--um5g-85k --package CABGA381)
    HAZARD3_HDMI_EXTENDED_MODES="${HAZARD3_HDMI_EXTENDED_MODES:-1}"
    SYNTH_PROFILE_STAMP="${HAZARD3_SYNTH}/fpga_ulx3s.video-profile"
    ;;
ulx3s-12f)
    DISPLAY_NAME="ULX3S 12F"
    FPGA_NAME="fpga_ulx3s_12f"
    MAKEFILE="ULX3S_12F.mk"
    LPF="${HAZARD3_SYNTH}/fpga_ulx3s.lpf"
    IDCODE="0x21111043"
    NEXTPNR_SEED="${NEXTPNR_SEED:-${ULX3S_12F_DEFAULT_NEXTPNR_SEED}}"
    PNR_DEVICE_ARGS=(--12k --speed 6 --package CABGA381)
    HAZARD3_MEMORY_PROFILE="${HAZARD3_MEMORY_PROFILE:-32m}"
    SYNTH_PROFILE_STAMP="${HAZARD3_SYNTH}/fpga_ulx3s_12f.memory-profile"
    SEED_STAMP="${BUILD_DIR}/fpga_ulx3s_12f.seed"
    ;;
ulx4m-ld-85f)
    DISPLAY_NAME="ULX4M-LD 85F"
    FPGA_NAME="fpga_ulx4m_ld"
    MAKEFILE="ULX4M_LD_85F.mk"
    LPF="${HAZARD3_SYNTH}/fpga_ulx4m_ld.lpf"
    IDCODE="0x01113043"
    NEXTPNR_SEED="${NEXTPNR_SEED:-${ULX4M_LD_85F_DEFAULT_NEXTPNR_SEED}}"
    NEXTPNR_HEAP_TIMINGWEIGHT="${NEXTPNR_HEAP_TIMINGWEIGHT:-${SWEEP_NEXTPNR_HEAP_TIMINGWEIGHT:-${ULX4M_LD_85F_DEFAULT_NEXTPNR_HEAP_TIMINGWEIGHT}}}"
    if [[ ! "${NEXTPNR_HEAP_TIMINGWEIGHT}" =~ ^[1-9][0-9]*$ ]]; then
        echo "NEXTPNR_HEAP_TIMINGWEIGHT must be a positive integer." >&2
        exit 1
    fi
    PNR_TUNING_ARGS=(--placer-heap-timingweight "${NEXTPNR_HEAP_TIMINGWEIGHT}")
    PNR_DEVICE_ARGS=(--um-85k --speed 8 --package CABGA381)
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
    HAZARD3_ULX4M_SYS_CLK_MHZ="${HAZARD3_ULX4M_SYS_CLK_MHZ:-40}"
    SYNTH_PROFILE_STAMP="${HAZARD3_SYNTH}/fpga_ulx4m_ld.sys-clk-mhz"
    LITEDRAM_CPU_STAMP="${HAZARD3_SYNTH}/fpga_ulx4m_ld.litedram-cpu"
    SEED_STAMP="${BUILD_DIR}/fpga_ulx4m_ld.seed"
    TIMINGWEIGHT_STAMP="${BUILD_DIR}/fpga_ulx4m_ld.heap-timingweight"
    ;;
*)
    echo "Unknown ECP5 board target: ${BOARD_ID:-<empty>}" >&2
    echo "Expected ulx3s-85f, ulx3s-12f, or ulx4m-ld-85f." >&2
    exit 2
    ;;
esac

NETLIST="${HAZARD3_SYNTH}/${FPGA_NAME}.json"
SYNTH_SOURCE_LOG="${HAZARD3_SYNTH}/synth.log"
BITSTREAM_OUTPUT="${BUILD_DIR}/${FPGA_NAME}.bit"
CONFIG_OUTPUT="${BUILD_DIR}/${FPGA_NAME}.config"
SVF_OUTPUT="${BUILD_DIR}/${FPGA_NAME}.svf"
PNR_LOG="${BUILD_DIR}/${FPGA_NAME}.pnr.log"
SYNTH_LOG="${BUILD_DIR}/${FPGA_NAME}.synth.log"
CONFIG_TEMP="${CONFIG_OUTPUT}.tmp.$$"
BITSTREAM_TEMP="${BITSTREAM_OUTPUT}.tmp.$$"
SVF_TEMP="${SVF_OUTPUT}.tmp.$$"

case "${ALLOW_TIMING_FAILURE}" in
0)
    timing_options=()
    ;;
1)
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
        require_file "${LITEDRAM_DIR}/litedram_ulx4m_cpu.v"
        require_file "${LITEDRAM_GENERATED_DIR}/litedram_ulx4m_cpu.v"
        require_file "${LITEDRAM_GENERATED_DIR}/litedram_ulx4m_cpu_rom.init"
        require_file "${LITEDRAM_GENERATED_DIR}/litedram_ulx4m_cpu_sram.init"
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
    reuse_ulx3s_bitstream_if_allowed
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
    run_synthesis
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

# Remove only obsolete integration P&R artifacts from the Hazard3 synth tree.
rm -f \
    "${HAZARD3_SYNTH}/${FPGA_NAME}.config" \
    "${HAZARD3_SYNTH}/${FPGA_NAME}.bit" \
    "${HAZARD3_SYNTH}/${FPGA_NAME}.svf" \
    "${HAZARD3_SYNTH}/pnr.log"

printf '%s bitstream: %s\n' "${DISPLAY_NAME}" "${BITSTREAM_OUTPUT}"
if [[ -n "${SEED_STAMP:-}" ]]; then
    printf '%s seed stamp: %s (seed %s)\n' \
        "${DISPLAY_NAME}" "${SEED_STAMP}" "${NEXTPNR_SEED}"
fi
if [[ -n "${TIMINGWEIGHT_STAMP:-}" ]]; then
    printf '%s HeAP timingweight stamp: %s (timingweight %s)\n' \
        "${DISPLAY_NAME}" "${TIMINGWEIGHT_STAMP}" "${NEXTPNR_HEAP_TIMINGWEIGHT}"
fi
