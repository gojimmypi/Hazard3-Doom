#!/bin/bash
# -----------------------------------------------------------------------------
# File:        sweep-ulx3s-common.sh
# Path:        scripts/sweep-ulx3s-common.sh
#
# Project:     Hazard3-Doom
# Purpose:     Run fully routed ULX3S 12F/45F/85F nextpnr seed sweeps with a
#              shared driver and board-specific defaults.
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

# This is the shared implementation. The old per-board filenames are preserved
# as small wrappers so existing scripts, CI jobs, and user commands still work.
# A board ID selects the SoC/netlist configuration. ECP5_PNR_DEVICE separately
# selects the FPGA family and speed grade actually fitted to that board.
if (( $# < 1 )); then
    echo 'Usage: sweep-ulx3s-common.sh ulx3s-12f|ulx3s-45f|ulx3s-85f [SEEDS|--print-sweep-dir]' >&2
    exit 1
fi
SWEEP_ECP5_BOARD_ID="$1"
shift
case "${SWEEP_ECP5_BOARD_ID}" in
ulx3s-12f|ulx3s-45f|ulx3s-85f) ;;
*) echo "Unknown ULX3S sweep target: ${SWEEP_ECP5_BOARD_ID}" >&2; exit 1 ;;
esac

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# Keep the existing inventory warning behavior; never block normal sweeps.
"${SCRIPT_DIR}/inventory.sh" --check-file "${BASH_SOURCE[0]}" || true
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
HAZARD3_ROOT="${HAZARD3_ROOT:-${REPO_ROOT}/third_party/Hazard3}"
SYNTH_DIR="${HAZARD3_ROOT}/example_soc/synth"
BUILD_DIR="${REPO_ROOT}/build"
COMMON_SCRIPT="${SCRIPT_DIR}/sweep-ecp5-common.sh"
SWEEP_JOBS="${SWEEP_JOBS:-4}"
SWEEP_SKIP_SYNTH="${SWEEP_SKIP_SYNTH:-0}"
SWEEP_PREPARE_ONLY="${SWEEP_PREPARE_ONLY:-0}"
SWEEP_AUTO_BUILD_MONITOR="${SWEEP_AUTO_BUILD_MONITOR:-1}"
IS_COMPACT_ULX3S=0

# shellcheck source=scripts/ecp5-board-defaults.sh
source "${SCRIPT_DIR}/ecp5-board-defaults.sh"
# shellcheck source=scripts/sweep-ecp5-common.sh
source "${COMMON_SCRIPT}"
printf 'Include source: %s\n' "${COMMON_SCRIPT}" >&2

case "${SWEEP_ECP5_BOARD_ID}" in
ulx3s-45f)
    IS_COMPACT_ULX3S=1
    HAZARD3_MEMORY_PROFILE="${HAZARD3_MEMORY_PROFILE:-32m}"
    NETLIST="${BUILD_DIR}/fpga_ulx3s_45f.json"
    MAKEFILE="${SYNTH_DIR}/ULX3S_12F.mk"
    SYNTH_LOG="${BUILD_DIR}/fpga_ulx3s_45f.synth.log"
    SYNTH_PROFILE_STAMP="${BUILD_DIR}/fpga_ulx3s_45f.memory-profile"
    SYNTH_DURATION_STAMP="${BUILD_DIR}/fpga_ulx3s_45f.synth-seconds"
    BOARD_LABEL='ULX3S 45F (compact)'
    NETLIST_BASE='fpga_ulx3s_45f'
    EBR_CAPACITY=108
    ;;
ulx3s-12f)
    IS_COMPACT_ULX3S=1
    EBR_CAPACITY=32
    HAZARD3_MEMORY_PROFILE="${HAZARD3_MEMORY_PROFILE:-32m}"
    NETLIST="${BUILD_DIR}/fpga_ulx3s_12f.json"
    MAKEFILE="${SYNTH_DIR}/ULX3S_12F.mk"
    SYNTH_LOG="${BUILD_DIR}/fpga_ulx3s_12f.synth.log"
    SYNTH_PROFILE_STAMP="${BUILD_DIR}/fpga_ulx3s_12f.memory-profile"
    SYNTH_DURATION_STAMP="${BUILD_DIR}/fpga_ulx3s_12f.synth-seconds"
    BOARD_LABEL='ULX3S 12F'
    NETLIST_BASE='fpga_ulx3s_12f'
    ;;
ulx3s-85f)
    ecp5_ulx3s_85f_clock_profile
    HAZARD3_HDMI_EXTENDED_MODES="${HAZARD3_HDMI_EXTENDED_MODES:-0}"
    NETLIST="${BUILD_DIR}/fpga_ulx3s_85f.json"
    SYNTH_LOG="${BUILD_DIR}/fpga_ulx3s_85f.synth.log"
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
    BOARD_LABEL='ULX3S 85F'
    NETLIST_BASE='fpga_ulx3s_85f'
    ;;
esac
LPF="${SYNTH_DIR}/fpga_ulx3s.lpf"

ecp5_pnr_device_profile "${SWEEP_ECP5_BOARD_ID}"
sweep_ecp5_clock_targets
sweep_ecp5_init_tuning
TUNING_SUFFIX="$(sweep_ecp5_tuning_suffix)$(ecp5_pnr_device_suffix)"

if [[ "${IS_COMPACT_ULX3S}" == 1 ]]; then
    SWEEP_DIR="${BUILD_DIR}/${SWEEP_ECP5_BOARD_ID}-seed-sweep/${HAZARD3_MEMORY_PROFILE}${TUNING_SUFFIX}"
else
    case "${HAZARD3_HDMI_EXTENDED_MODES}" in
    0) VIDEO_PROFILE='vga640-standard' ;;
    1) VIDEO_PROFILE='vga640-extended' ;;
    *) echo 'HAZARD3_HDMI_EXTENDED_MODES must be 0 or 1.' >&2; exit 1 ;;
    esac
    SWEEP_DIR="${BUILD_DIR}/ulx3s-seed-sweep-${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}mhz-${VIDEO_PROFILE}-rh${HAZARD3_ULX3S_85F_REGISTERED_READ_HITS}-swb${HAZARD3_ULX3S_85F_SRAM_WRITE_BUFFER}-dp${HAZARD3_ULX3S_85F_SRAM_DUAL_PORT_RW}-tagp${HAZARD3_ULX3S_85F_CACHE_TAG_PIPELINE}-trm${HAZARD3_ULX3S_85F_TAG_RAM_MODE}-cap${HAZARD3_ULX3S_85F_CACHE_ADDR_PIPELINE}${TUNING_SUFFIX}"
fi
SWEEP_REL_DIR="${SWEEP_DIR#"${REPO_ROOT}"/}"

usage()
{
    cat >&2 <<EOF_USAGE
Usage: ./scripts/sweep-ecp5.sh ${SWEEP_ECP5_BOARD_ID} SEED [SEED ...]
       ./scripts/sweep-ecp5.sh ${SWEEP_ECP5_BOARD_ID} START-END
       ./scripts/sweep-ecp5.sh ${SWEEP_ECP5_BOARD_ID} --all

Route nextpnr seeds for the ${BOARD_LABEL} Hazard3-Doom build.
Seeds are positive signed 32-bit decimals; ranges may exceed 512 seeds.
--all uses 1-512 by default; SWEEP_ALL_SEED_LAST=N changes its last seed.
SWEEP_JOBS=N routes up to N seeds concurrently (default: 4).
ECP5_PNR_DEVICE=PART selects the installed FPGA (e.g. LFE5UM5G-85F-8).
ECP5_PNR_SPEED_GRADE=N overrides the default device's speed grade.
ECP5_PNR_PACKAGE=NAME selects the nextpnr package (default CABGA381).
SWEEP_SYS_TARGET_MHZ, SWEEP_VIDEO_TARGET_MHZ, SWEEP_TMDS_TARGET_MHZ
  are Fmax targets, not PLL controls. The 85F also enforces them for PASS.
  The compact 12F/45F profiles retain nextpnr-based PASS qualification.
SWEEP_SKIP_SYNTH=1 routes an already-frozen synthesized netlist.
SWEEP_ROUTE_TIMEOUT_SECONDS=N limits each route (default: 7200).
EOF_USAGE
    if [[ "${IS_COMPACT_ULX3S}" == 1 ]]; then
        cat >&2 <<'EOF_12F'
HAZARD3_MEMORY_PROFILE=32m|64m selects SDRAM memory (default: 32m).
The compact ULX3S 12F/45F system clock remains fixed at 40 MHz.
EOF_12F
    else
        cat >&2 <<'EOF_85F'
HAZARD3_ULX3S_85F_SYS_CLK_MHZ=25|40|50 selects the system clock.
HAZARD3_HDMI_EXTENDED_MODES=0|1 selects standard/extended HDMI.
HAZARD3_ULX3S_85F_REGISTERED_READ_HITS=0|1 selects cache-hit pipelining.
HAZARD3_ULX3S_85F_SRAM_WRITE_BUFFER=0|1 selects SRAM write buffering.
HAZARD3_ULX3S_85F_SRAM_DUAL_PORT_RW=0|1 selects experimental ports.
HAZARD3_ULX3S_85F_CACHE_TAG_PIPELINE=0|1 selects tag-hit pipelining.
HAZARD3_ULX3S_85F_TAG_RAM_MODE=0|1|2 selects tag-RAM mode.
HAZARD3_ULX3S_85F_CACHE_ADDR_PIPELINE=0|1 selects AHB address pipelining.
SWEEP_AUTO_BUILD_MONITOR=1 builds a matching 85F monitor when needed (default).
Set to 0 to require a previously prepared clock-matched monitor.
Frozen sweeps (SWEEP_SKIP_SYNTH=1) never rebuild the monitor.
EOF_85F
    fi
}

# Run ShellCheck as a warning, not a build gate. Developers can still run it
# directly for full diagnostics, while timing sweeps keep their current result.
MY_SHELLCHECK="${MY_SHELLCHECK:-shellcheck}"
if command -v "${MY_SHELLCHECK}" >/dev/null 2>&1; then
    if ! (cd -- "${REPO_ROOT}" && "${MY_SHELLCHECK}" -x scripts/sweep-ulx3s-common.sh); then
        echo "WARNING: ShellCheck reported issues in the shared ULX3S sweep script." >&2
    fi
else
    echo "${MY_SHELLCHECK} is not installed. Please install it if changes to this script have been made." >&2
fi

if (( $# == 1 )) && [[ "$1" == '--print-sweep-dir' ]]; then
    printf '%s\n' "${SWEEP_REL_DIR}"
    exit 0
fi
case "${SWEEP_SKIP_SYNTH}" in
0|1) ;;
*) echo 'SWEEP_SKIP_SYNTH must be 0 or 1.' >&2; exit 1 ;;
esac
case "${SWEEP_PREPARE_ONLY}" in
0|1) ;;
*) echo 'SWEEP_PREPARE_ONLY must be 0 or 1.' >&2; exit 1 ;;
esac
case "${SWEEP_AUTO_BUILD_MONITOR}" in
0|1) ;;
*) echo 'SWEEP_AUTO_BUILD_MONITOR must be 0 or 1.' >&2; exit 1 ;;
esac
if [[ ! "${SWEEP_JOBS}" =~ ^[1-9][0-9]*$ ]]; then
    printf 'Invalid SWEEP_JOBS: %s; expected a positive integer.\n' "${SWEEP_JOBS}" >&2
    exit 1
fi
if [[ "${IS_COMPACT_ULX3S}" == 1 ]]; then
    case "${HAZARD3_MEMORY_PROFILE}" in
    32m|64m) ;;
    *) echo 'HAZARD3_MEMORY_PROFILE must be 32m or 64m.' >&2; exit 1 ;;
    esac
    printf '%s sweep configuration: system clock=40 MHz, SDRAM profile=%s\n' "${BOARD_LABEL}" "${HAZARD3_MEMORY_PROFILE}"
else
    printf 'ULX3S 85F sweep configuration: system clock=%s MHz, HDMI profile=%s, extended modes=%s\n' \
        "${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}" "${VIDEO_PROFILE}" "${HAZARD3_HDMI_EXTENDED_MODES}"
fi

if [[ "${SWEEP_PREPARE_ONLY}" != '1' ]]; then
    if (( $# == 0 )); then
        usage
        exit 1
    fi
    sweep_ecp5_parse_seeds usage "$@"
    results_file="$(sweep_ecp5_results_filename "${SWEEP_DIR}")"
fi
sweep_ecp5_require_tool sha256sum
sweep_ecp5_require_tool awk
sweep_ecp5_require_tool grep
sweep_ecp5_require_tool sed
sweep_ecp5_require_file "${LPF}"
mkdir -p "${BUILD_DIR}"

# The 85F resident monitor embeds the selected system clock in its firmware.
# Local sweeps may switch clocks without running the full Doom/FPGA build.
# CI route jobs use SWEEP_SKIP_SYNTH=1 and must keep the frozen preload intact.
if [[ "${SWEEP_ECP5_BOARD_ID}" == 'ulx3s-85f' ]]; then
    monitor_sys_clock=""
    if [[ -f "${MONITOR_SYS_CLK_STAMP}" ]]; then
        read -r monitor_sys_clock < "${MONITOR_SYS_CLK_STAMP}" || true
    fi

    monitor_hex="${HAZARD3_ROOT}/example_soc/soc/hazard3-boot-monitor.hex"
    monitor_needs_build=0
    if [[ "${monitor_sys_clock}" != "${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}" ]]; then
        monitor_needs_build=1
    fi
    if [[ ! -s "${monitor_hex}" ]]; then
        monitor_needs_build=1
    fi

    if [[ "${monitor_needs_build}" == 1 ]]; then
        if [[ "${SWEEP_SKIP_SYNTH}" == 1 || "${SWEEP_AUTO_BUILD_MONITOR}" == 0 ]]; then
            printf 'ERROR: ULX3S 85F monitor preload clock is %s; requested %s MHz.\n' \
                "${monitor_sys_clock:-unrecorded}" "${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}" >&2
            printf 'The monitor is missing, mismatched, or unstamped.\n' >&2
            printf 'Prepare a clock-matched preload before frozen routing.\n' >&2
            exit 1
        fi

        printf 'Preparing ULX3S 85F monitor for %s MHz (previous: %s).\n' \
            "${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}" "${monitor_sys_clock:-unrecorded}"
        sweep_ecp5_require_tool python3
        sweep_ecp5_require_tool install
        sweep_ecp5_require_file "${SCRIPT_DIR}/build.sh"
        sweep_ecp5_require_file "${SCRIPT_DIR}/make-boot-hex.py"

        monitor_build_dir="${BUILD_DIR}/ulx3s-85f/monitor"
        monitor_binary="${monitor_build_dir}/hazard3-boot-monitor.bin"
        monitor_copy="${BUILD_DIR}/ulx3s-85f/hazard3-boot-monitor.hex"

        # Clear the stamp first so a failed firmware build cannot leave the
        # earlier clock profile falsely marked as current.
        rm -f "${MONITOR_SYS_CLK_STAMP}"
        HAZARD3_BUILD_DIR="${monitor_build_dir}" \
        HAZARD3_MEMORY_PROFILE=64m \
        HAZARD3_SYS_CLK_HZ="$((HAZARD3_ULX3S_85F_SYS_CLK_MHZ * 1000000))" \
            "${SCRIPT_DIR}/build.sh"
        if [[ ! -s "${monitor_binary}" ]]; then
            printf 'ERROR: Monitor build did not produce %s\n' "${monitor_binary}" >&2
            exit 1
        fi

        "${SCRIPT_DIR}/make-boot-hex.py" \
            "${monitor_binary}" "${monitor_hex}" \
            --bytes 0x10000 --load-address 0x40
        if [[ ! -s "${monitor_hex}" ]]; then
            printf 'ERROR: Monitor preload was not generated: %s\n' "${monitor_hex}" >&2
            exit 1
        fi
        mkdir -p "${BUILD_DIR}/ulx3s-85f"
        install -m 0644 "${monitor_hex}" "${monitor_copy}"
        printf '%s\n' "${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}" > "${MONITOR_SYS_CLK_STAMP}"
        printf 'ULX3S 85F monitor preload ready for %s MHz.\n' \
            "${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}"
    fi
fi

synthesis_seconds="NA"
if [[ -f "${SYNTH_DURATION_STAMP}" ]]; then
    read -r synthesis_seconds < "${SYNTH_DURATION_STAMP}" || true
fi
if [[ ! "${synthesis_seconds}" =~ ^[0-9]+$ ]]; then
    synthesis_seconds="NA"
fi

# Board-specific synthesis checks stay independent. The shared routing code
# below only runs after the proper board netlist has been validated.
if [[ "${IS_COMPACT_ULX3S}" == 1 ]]; then
    if [[ "${SWEEP_SKIP_SYNTH}" == "1" ]]; then
        recorded_profile=""
        if [[ -f "${SYNTH_PROFILE_STAMP}" ]]; then
            read -r recorded_profile < "${SYNTH_PROFILE_STAMP}" || true
        fi
        if [[ "${recorded_profile}" != "${HAZARD3_MEMORY_PROFILE}" ]]; then
            echo "Frozen ${BOARD_LABEL} netlist memory profile does not match requested ${HAZARD3_MEMORY_PROFILE}." >&2
            exit 1
        fi
        printf 'Using existing synthesized %s netlist; synthesis skipped.\n' "${BOARD_LABEL}"
    else
        sweep_ecp5_require_tool make
        sweep_ecp5_require_tool yosys
        sweep_ecp5_require_file "${MAKEFILE}"
        sweep_ecp5_require_file "${HAZARD3_ROOT}/example_soc/soc/cache_tags_zero_12f.hex"
        sweep_ecp5_require_file "${HAZARD3_ROOT}/example_soc/soc/hazard3-12f-bootstrap.hex"

        current_profile=""
        if [[ -f "${SYNTH_PROFILE_STAMP}" ]]; then
            read -r current_profile < "${SYNTH_PROFILE_STAMP}" || true
        fi
        if [[ "${current_profile}" != "${HAZARD3_MEMORY_PROFILE}" ]]; then
            rm -f \
                "${NETLIST}" \
                "${SYNTH_LOG}" \
                "${SYNTH_DURATION_STAMP}"
        fi

        printf '%s profile: compact 320x200, %s SDRAM\n' \
            "${BOARD_LABEL}" "${HAZARD3_MEMORY_PROFILE}"

        synth_start_seconds="$(date +%s)"
        sweep_ecp5_run_synthesis "${SYNTH_DIR}" "${SYNTH_LOG}" \
            -f ULX3S_12F.mk \
            CHIPNAME="${NETLIST%.json}" \
            HAZARD3_MEMORY_PROFILE="${HAZARD3_MEMORY_PROFILE}" \
            HAZARD3_HDMI_EXTENDED_MODES=0 synth
        if [[ "${SWEEP_SYNTHESIS_RAN}" == 1 ]]; then
            synthesis_seconds="$(( $(date +%s) - synth_start_seconds ))"
            printf '%s\n' "${synthesis_seconds}" > "${SYNTH_DURATION_STAMP}"
        else
            printf 'Synthesis reused the existing netlist; recorded duration remains %s.\n' \
                "${synthesis_seconds}"
        fi
        printf '%s\n' "${HAZARD3_MEMORY_PROFILE}" > "${SYNTH_PROFILE_STAMP}"
    fi

else
    if [[ "${SWEEP_SKIP_SYNTH}" == "1" ]]; then
        recorded_profile=""
        if [[ -f "${SYNTH_PROFILE_STAMP}" ]]; then
            read -r recorded_profile < "${SYNTH_PROFILE_STAMP}" || true
        fi
        recorded_sys_clock=""
        if [[ -f "${SYS_CLK_PROFILE_STAMP}" ]]; then
            read -r recorded_sys_clock < "${SYS_CLK_PROFILE_STAMP}" || true
        fi
        recorded_registered_hits=""
        recorded_sram_write_buffer=""
        recorded_sram_dual_port=""
        recorded_cache_tag_pipeline=""
        recorded_tag_ram_mode=""
        recorded_cache_addr_pipeline=""
        if [[ -f "${CACHE_TAG_PIPELINE_PROFILE_STAMP}" ]]; then
            read -r recorded_cache_tag_pipeline < "${CACHE_TAG_PIPELINE_PROFILE_STAMP}" || true
        fi
        if [[ -f "${TAG_RAM_MODE_PROFILE_STAMP}" ]]; then
            read -r recorded_tag_ram_mode < "${TAG_RAM_MODE_PROFILE_STAMP}" || true
        fi
        if [[ -f "${CACHE_ADDR_PIPELINE_PROFILE_STAMP}" ]]; then
            read -r recorded_cache_addr_pipeline < "${CACHE_ADDR_PIPELINE_PROFILE_STAMP}" || true
        fi
        if [[ -f "${REGISTERED_HITS_PROFILE_STAMP}" ]]; then
            read -r recorded_registered_hits < "${REGISTERED_HITS_PROFILE_STAMP}" || true
        fi
        if [[ -f "${SRAM_WRITE_BUFFER_PROFILE_STAMP}" ]]; then
            read -r recorded_sram_write_buffer < "${SRAM_WRITE_BUFFER_PROFILE_STAMP}" || true
        fi
        if [[ -f "${SRAM_DUAL_PORT_PROFILE_STAMP}" ]]; then
            read -r recorded_sram_dual_port < "${SRAM_DUAL_PORT_PROFILE_STAMP}" || true
        fi
        if [[ "${recorded_profile}" != "${VIDEO_PROFILE}" ||
              "${recorded_sys_clock}" != "${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}" ||
              "${recorded_registered_hits}" != "${HAZARD3_ULX3S_85F_REGISTERED_READ_HITS}" ||
              "${recorded_sram_write_buffer}" != "${HAZARD3_ULX3S_85F_SRAM_WRITE_BUFFER}" ||
              "${recorded_sram_dual_port}" != "${HAZARD3_ULX3S_85F_SRAM_DUAL_PORT_RW}" ||
              "${recorded_cache_tag_pipeline}" != "${HAZARD3_ULX3S_85F_CACHE_TAG_PIPELINE}" ||
              "${recorded_tag_ram_mode}" != "${HAZARD3_ULX3S_85F_TAG_RAM_MODE}" ||
              "${recorded_cache_addr_pipeline}" != "${HAZARD3_ULX3S_85F_CACHE_ADDR_PIPELINE}" ]]; then
            printf 'ERROR: Frozen ULX3S 85F netlist profile mismatch.\n' >&2
            printf '  Recorded: video=%s clk=%s rh=%s swb=%s dp=%s tagp=%s trm=%s cap=%s\n' \
                "${recorded_profile:-unrecorded}" "${recorded_sys_clock:-unrecorded}" \
                "${recorded_registered_hits:-unrecorded}" "${recorded_sram_write_buffer:-unrecorded}" \
                "${recorded_sram_dual_port:-unrecorded}" "${recorded_cache_tag_pipeline:-unrecorded}" \
                "${recorded_tag_ram_mode:-unrecorded}" "${recorded_cache_addr_pipeline:-unrecorded}" >&2
            printf '  Requested: video=%s clk=%s rh=%s swb=%s dp=%s tagp=%s trm=%s cap=%s\n' \
                "${VIDEO_PROFILE}" "${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}" \
                "${HAZARD3_ULX3S_85F_REGISTERED_READ_HITS}" "${HAZARD3_ULX3S_85F_SRAM_WRITE_BUFFER}" \
                "${HAZARD3_ULX3S_85F_SRAM_DUAL_PORT_RW}" "${HAZARD3_ULX3S_85F_CACHE_TAG_PIPELINE}" \
                "${HAZARD3_ULX3S_85F_TAG_RAM_MODE}" "${HAZARD3_ULX3S_85F_CACHE_ADDR_PIPELINE}" >&2
            exit 1
        fi
        printf 'Using existing synthesized ULX3S 85F netlist; synthesis skipped.\n'
    else
        sweep_ecp5_require_tool make
        sweep_ecp5_require_tool yosys

        current_profile=""
        if [[ -f "${SYNTH_PROFILE_STAMP}" ]]; then
            read -r current_profile < "${SYNTH_PROFILE_STAMP}" || true
        fi
        current_sys_clock=""
        if [[ -f "${SYS_CLK_PROFILE_STAMP}" ]]; then
            read -r current_sys_clock < "${SYS_CLK_PROFILE_STAMP}" || true
        fi
        current_registered_hits=""
        current_sram_write_buffer=""
        current_sram_dual_port=""
        current_cache_tag_pipeline=""
        current_tag_ram_mode=""
        current_cache_addr_pipeline=""
        if [[ -f "${CACHE_TAG_PIPELINE_PROFILE_STAMP}" ]]; then
            read -r current_cache_tag_pipeline < "${CACHE_TAG_PIPELINE_PROFILE_STAMP}" || true
        fi
        if [[ -f "${TAG_RAM_MODE_PROFILE_STAMP}" ]]; then
            read -r current_tag_ram_mode < "${TAG_RAM_MODE_PROFILE_STAMP}" || true
        fi
        if [[ -f "${CACHE_ADDR_PIPELINE_PROFILE_STAMP}" ]]; then
            read -r current_cache_addr_pipeline < "${CACHE_ADDR_PIPELINE_PROFILE_STAMP}" || true
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
        if [[ "${current_profile}" != "${VIDEO_PROFILE}" ||
              "${current_sys_clock}" != "${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}" ||
              "${current_registered_hits}" != "${HAZARD3_ULX3S_85F_REGISTERED_READ_HITS}" ||
              "${current_sram_write_buffer}" != "${HAZARD3_ULX3S_85F_SRAM_WRITE_BUFFER}" ||
              "${current_sram_dual_port}" != "${HAZARD3_ULX3S_85F_SRAM_DUAL_PORT_RW}" ||
              "${current_cache_tag_pipeline}" != "${HAZARD3_ULX3S_85F_CACHE_TAG_PIPELINE}" ||
              "${current_tag_ram_mode}" != "${HAZARD3_ULX3S_85F_TAG_RAM_MODE}" ||
              "${current_cache_addr_pipeline}" != "${HAZARD3_ULX3S_85F_CACHE_ADDR_PIPELINE}" ]]; then
            rm -f \
                "${NETLIST}" \
                "${SYNTH_LOG}" \
                "${SYNTH_DURATION_STAMP}"
        fi

        printf 'ULX3S 85F synthesis profile: %s MHz, HDMI %s (extended modes=%s)\n' \
            "${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}" "${VIDEO_PROFILE}" "${HAZARD3_HDMI_EXTENDED_MODES}"

        synth_start_seconds="$(date +%s)"
        sweep_ecp5_run_synthesis "${SYNTH_DIR}" "${SYNTH_LOG}" \
            -f ULX3S.mk \
            CHIPNAME="${BUILD_DIR}/fpga_ulx3s_85f" \
            HAZARD3_ULX3S_85F_SYS_CLK_MHZ="${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}" \
            HAZARD3_ULX3S_85F_REGISTERED_READ_HITS="${HAZARD3_ULX3S_85F_REGISTERED_READ_HITS}" \
            HAZARD3_ULX3S_85F_SRAM_WRITE_BUFFER="${HAZARD3_ULX3S_85F_SRAM_WRITE_BUFFER}" \
            HAZARD3_ULX3S_85F_SRAM_DUAL_PORT_RW="${HAZARD3_ULX3S_85F_SRAM_DUAL_PORT_RW}" \
            HAZARD3_ULX3S_85F_CACHE_TAG_PIPELINE="${HAZARD3_ULX3S_85F_CACHE_TAG_PIPELINE}" \
            HAZARD3_ULX3S_85F_TAG_RAM_MODE="${HAZARD3_ULX3S_85F_TAG_RAM_MODE}" \
            HAZARD3_ULX3S_85F_CACHE_ADDR_PIPELINE="${HAZARD3_ULX3S_85F_CACHE_ADDR_PIPELINE}" \
            HAZARD3_HDMI_EXTENDED_MODES="${HAZARD3_HDMI_EXTENDED_MODES}" synth
        if [[ "${SWEEP_SYNTHESIS_RAN}" == 1 ]]; then
            synthesis_seconds="$(( $(date +%s) - synth_start_seconds ))"
            printf '%s\n' "${synthesis_seconds}" > "${SYNTH_DURATION_STAMP}"
        else
            printf 'Synthesis reused the existing netlist; recorded duration remains %s.\n' \
                "${synthesis_seconds}"
        fi
        printf '%s\n' "${VIDEO_PROFILE}" > "${SYNTH_PROFILE_STAMP}"
        printf '%s\n' "${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}" > "${SYS_CLK_PROFILE_STAMP}"
        printf '%s\n' "${HAZARD3_ULX3S_85F_REGISTERED_READ_HITS}" > "${REGISTERED_HITS_PROFILE_STAMP}"
        printf '%s\n' "${HAZARD3_ULX3S_85F_SRAM_WRITE_BUFFER}" > "${SRAM_WRITE_BUFFER_PROFILE_STAMP}"
        printf '%s\n' "${HAZARD3_ULX3S_85F_SRAM_DUAL_PORT_RW}" > "${SRAM_DUAL_PORT_PROFILE_STAMP}"
        printf '%s\n' "${HAZARD3_ULX3S_85F_CACHE_TAG_PIPELINE}" > "${CACHE_TAG_PIPELINE_PROFILE_STAMP}"
        printf '%s\n' "${HAZARD3_ULX3S_85F_TAG_RAM_MODE}" > "${TAG_RAM_MODE_PROFILE_STAMP}"
        printf '%s\n' "${HAZARD3_ULX3S_85F_CACHE_ADDR_PIPELINE}" > "${CACHE_ADDR_PIPELINE_PROFILE_STAMP}"
    fi

fi

if [[ ! -s "${NETLIST}" ]]; then
    echo "Missing synthesized ${BOARD_LABEL} netlist: ${NETLIST}" >&2
    exit 1
fi
if [[ ! -s "${SYNTH_LOG}" ]]; then
    echo "Missing ${BOARD_LABEL} synthesis log: ${SYNTH_LOG}" >&2
    exit 1
fi

# The full 85F SoC currently uses more embedded RAM than a 45F provides.
# Validate the actual synthesized count rather than rejecting 45F outright:
# future reduced-resource 85F configurations may eventually fit.
if [[ "${ECP5_PNR_DEVICE%-*}" == LFE5U-45F ]]; then
    selected_ebr_used="$(awk '$2 == "DP16KD" {used=$1} END {print used}' "${SYNTH_LOG}")"
    if [[ -z "${selected_ebr_used}" ]]; then
        echo "ERROR: Could not determine DP16KD usage for ${ECP5_PNR_DEVICE}." >&2
        exit 1
    fi
    if (( selected_ebr_used > 108 )); then
        printf 'ERROR: Synthesized %s DP16KD blocks; %s provides only 108.\n' \
            "${selected_ebr_used}" "${ECP5_PNR_DEVICE}" >&2
        printf 'Try target=ulx3s-45f for the compact 45F SoC, or reduce the full 85F RTL EBR usage.\n' >&2
        exit 1
    fi
    printf 'Selected %s capacity check: %s/108 DP16KD.\n' \
        "${ECP5_PNR_DEVICE}" "${selected_ebr_used}"
fi

if [[ "${IS_COMPACT_ULX3S}" == 1 ]]; then
    ebr_used="$(awk '$2 == "DP16KD" {used=$1} END {print used}' "${SYNTH_LOG}")"
    if [[ -z "${ebr_used}" ]]; then
        echo "ERROR: Could not determine compact ULX3S DP16KD usage from synth.log." >&2
        exit 1
    fi
    if (( ebr_used > EBR_CAPACITY )); then
        printf 'ERROR: %s synthesis uses %s DP16KD blocks; device capacity is %s.\n' \
            "${BOARD_LABEL}" "${ebr_used}" "${EBR_CAPACITY}" >&2
        exit 1
    fi
    if grep -Fq "ulx3s_frame_ram\\BANK_COUNT=" "${SYNTH_LOG}"; then
        echo "ERROR: Compact ULX3S synthesized the full EBR framebuffer hierarchy." >&2
        exit 1
    fi
fi

netlist_sha256="$(sha256sum "${NETLIST}" | awk '{print $1}')"
mkdir -p "${SWEEP_DIR}"
{
    printf 'target=%s\n' "${SWEEP_ECP5_BOARD_ID}"
    printf 'device=%s\n' "${ECP5_PNR_DEVICE_OPTION#--}"
    printf 'fpga_part=%s\n' "${ECP5_PNR_DEVICE}"
    printf 'idcode=%s\n' "${ECP5_PNR_IDCODE}"
    printf 'speed=%s\n' "${ECP5_PNR_SPEED_GRADE}"
    printf 'package=%s\n' "${ECP5_PNR_PACKAGE}"
    printf 'full_route=1\n'
    if [[ "${IS_COMPACT_ULX3S}" == 1 ]]; then
        printf 'target_overrides_are_reporting_only=1\n'
    else
        printf 'target_overrides_are_reporting_only=0\n'
        printf 'target_overrides_change_physical_clocks=0\n'
    fi
    printf 'result_columns=seed,clk_sys_mhz,clk_video_mhz,clk_tmds_mhz,route_seconds,timing_status\n'
    if [[ "${IS_COMPACT_ULX3S}" == 1 ]]; then
        printf 'hazard3_memory_profile=%s\n' "${HAZARD3_MEMORY_PROFILE}"
        printf 'dp16kd_used=%s\n' "${ebr_used}"
    else
        printf 'video_profile=%s\n' "${VIDEO_PROFILE}"
        printf 'system_clock_mhz=%s\n' "${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}"
        printf 'registered_read_hits=%s\n' "${HAZARD3_ULX3S_85F_REGISTERED_READ_HITS}"
        printf 'sram_write_buffer=%s\n' "${HAZARD3_ULX3S_85F_SRAM_WRITE_BUFFER}"
        printf 'sram_dual_port_rw=%s\n' "${HAZARD3_ULX3S_85F_SRAM_DUAL_PORT_RW}"
        printf 'cache_tag_pipeline=%s\n' "${HAZARD3_ULX3S_85F_CACHE_TAG_PIPELINE}"
        printf 'tag_ram_mode=%s\n' "${HAZARD3_ULX3S_85F_TAG_RAM_MODE}"
        printf 'cache_addr_pipeline=%s\n' "${HAZARD3_ULX3S_85F_CACHE_ADDR_PIPELINE}"
    fi
    sweep_ecp5_write_tuning_metadata
    printf 'clk_sys_required_mhz=%s\n' "${SWEEP_SYS_TARGET_MHZ}"
    printf 'clk_video_required_mhz=%s\n' "${SWEEP_VIDEO_TARGET_MHZ}"
    printf 'clk_tmds_required_mhz=%s\n' "${SWEEP_TMDS_TARGET_MHZ}"
    printf 'synthesis_seconds=%s\n' "${synthesis_seconds}"
    printf 'netlist_sha256=%s\n' "${netlist_sha256}"
    printf 'netlist=%s.json\n' "${NETLIST_BASE}"
    printf 'generated_utc=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
} > "${SWEEP_DIR}/metadata.txt"

if [[ "${IS_COMPACT_ULX3S}" == 1 ]]; then
    printf '%s synthesis check: compact profile, %s/%s DP16KD.\n' \
        "${BOARD_LABEL}" "${ebr_used}" "${EBR_CAPACITY}"
fi
printf '%s synthesis duration: %s seconds\n' "${BOARD_LABEL}" "${synthesis_seconds}"
printf '%s routed sweep netlist SHA256: %s\n' "${BOARD_LABEL}" "${netlist_sha256}"
printf '%s routed sweep directory: %s\n' "${BOARD_LABEL}" "${SWEEP_DIR}"

if [[ "${SWEEP_PREPARE_ONLY}" == "1" ]]; then
    printf '%s frozen sweep netlist prepared; routing skipped.\n' "${BOARD_LABEL}"
    exit 0
fi

sweep_ecp5_require_tool nextpnr-ecp5
sweep_ecp5_require_tool timeout
sweep_ecp5_require_tool ecppack

run_seed()
{
    local seed="$1"
    local pnr_log="${SWEEP_DIR}/pnr-${seed}.log"
    local failed_log="${SWEEP_DIR}/pnr-${seed}-failed.log"
    local config="${SWEEP_DIR}/${NETLIST_BASE}-${seed}.config"
    local svf="${SWEEP_DIR}/${NETLIST_BASE}-${seed}.svf"
    local bit="${SWEEP_DIR}/${NETLIST_BASE}-${seed}.bit"
    local result="${SWEEP_DIR}/result-seed-${seed}.csv"
    local clk_sys clk_video clk_tmds sys_clock
    local route_start_seconds route_start_time
    local route_end_seconds route_end_time
    local route_seconds route_status
    local clk_sys_status clk_video_status clk_tmds_status timing_status

    printf '\nTrying %s nextpnr seed %s\n' "${BOARD_LABEL}" "${seed}"
    rm -f "${pnr_log}" "${failed_log}" "${config}" "${svf}" "${bit}" "${result}"

    route_start_seconds="$(date +%s)"
    route_start_time="$(date '+%Y-%m-%d %H:%M:%S %Z')"
    printf 'Seed %s route start: %s\n' "${seed}" "${route_start_time}"

    if sweep_ecp5_run_nextpnr \
        --seed "${seed}" \
        "${SWEEP_NEXTPNR_ARGS[@]}" \
        "${PNR_DEVICE_ARGS[@]}" \
        --lpf "${LPF}" \
        --json "${NETLIST}" \
        --textcfg "${config}" \
        --timing-allow-fail \
        --quiet \
        --log "${pnr_log}"; then
        route_status=0
    else
        route_status=$?
    fi

    route_end_seconds="$(date +%s)"
    route_end_time="$(date '+%Y-%m-%d %H:%M:%S %Z')"
    route_seconds="$((route_end_seconds - route_start_seconds))"

    printf 'Seed %s route end:   %s\n' "${seed}" "${route_end_time}"
    printf 'Seed %s route elapsed: %ss\n' "${seed}" "${route_seconds}"

    case "${route_status}" in
    0)
        ;;
    124|137)
        printf '%d,TIMEOUT,TIMEOUT,TIMEOUT,%s,TIMEOUT\n' \
            "${seed}" "${route_seconds}" > "${result}"
        rm -f "${config}" "${svf}" "${bit}"
        printf 'Seed %s: routing timed out after %ss (kill grace %ss, status %s).\n' \
            "${seed}" "${SWEEP_ROUTE_TIMEOUT_SECONDS}" \
            "${SWEEP_ROUTE_KILL_AFTER_SECONDS}" "${route_status}" >&2
        return 0
        ;;
    *)
        printf '%d,ERROR,ERROR,ERROR,%s,ERROR\n' "${seed}" "${route_seconds}" > "${result}"
        [[ -f "${pnr_log}" ]] && mv "${pnr_log}" "${failed_log}"
        rm -f "${config}" "${svf}" "${bit}"
        printf 'Seed %s: nextpnr route failed with status %s.\n' \
            "${seed}" "${route_status}" >&2
        return 1
        ;;
    esac

    # 85F 25 MHz uses an oscillator alias. 40/50 MHz use the system PLL.
    # The compact 12F/45F SoC uses its dedicated fixed 40 MHz system PLL.
    sys_clock="clk_sys"
    if [[ "${SWEEP_ECP5_BOARD_ID}" == 'ulx3s-85f' ]]; then
        if ! sys_clock="$(sweep_ecp5_ulx3s_85f_system_clock "${pnr_log}")"; then
            printf '%d,ERROR,ERROR,ERROR,%s,ERROR\n' "${seed}" "${route_seconds}" > "${result}"
            [[ -f "${pnr_log}" ]] && mv "${pnr_log}" "${failed_log}"
            rm -f "${config}" "${svf}" "${bit}"
            return 1
        fi
    fi
    clk_sys="$(sweep_ecp5_extract_clock "${pnr_log}" "${sys_clock}")"
    clk_video="$(sweep_ecp5_extract_clock "${pnr_log}" "clk_video_pix")"
    clk_tmds="$(sweep_ecp5_extract_clock "${pnr_log}" "clk_tmds_x5")"
    clk_sys_status="$(sweep_ecp5_extract_clock_status "${pnr_log}" "${sys_clock}")"
    clk_video_status="$(sweep_ecp5_extract_clock_status "${pnr_log}" "clk_video_pix")"
    clk_tmds_status="$(sweep_ecp5_extract_clock_status "${pnr_log}" "clk_tmds_x5")"

    # The 85F has additional physical-clock qualification checks. Preserve
    # the compact 12F/45F behavior, which uses nextpnr's clock PASS verdicts.
    timing_status="FAIL"
    if [[ "${clk_sys_status}" == 'PASS' &&
          "${clk_video_status}" == 'PASS' &&
          "${clk_tmds_status}" == 'PASS' ]]; then
        if [[ "${IS_COMPACT_ULX3S}" == 1 ]]; then
            timing_status="PASS"
        elif sweep_ecp5_clock_meets_target "${clk_sys}" "${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}" &&
             sweep_ecp5_clock_meets_target "${clk_video}" '25.00' &&
             sweep_ecp5_clock_meets_target "${clk_tmds}" '125.00' &&
             sweep_ecp5_clock_meets_target "${clk_sys}" "${SWEEP_SYS_TARGET_MHZ}" &&
             sweep_ecp5_clock_meets_target "${clk_video}" "${SWEEP_VIDEO_TARGET_MHZ}" &&
             sweep_ecp5_clock_meets_target "${clk_tmds}" "${SWEEP_TMDS_TARGET_MHZ}"; then
            timing_status="PASS"
        fi
    fi

    if ! ecppack \
        --compress \
        --svf "${svf}" \
        --idcode "${ECP5_PNR_IDCODE}" \
        "${config}" \
        "${bit}"; then
        printf '%d,%s,%s,%s,%s,PACK_ERROR\n' \
            "${seed}" "${clk_sys}" "${clk_video}" "${clk_tmds}" \
            "${route_seconds}" > "${result}"
        [[ -f "${pnr_log}" ]] && mv "${pnr_log}" "${failed_log}"
        rm -f "${config}" "${svf}" "${bit}"
        return 1
    fi

    printf '%d,%s,%s,%s,%s,%s\n' \
        "${seed}" "${clk_sys}" "${clk_video}" "${clk_tmds}" \
        "${route_seconds}" "${timing_status}" > "${result}"

    rm -f "${failed_log}" "${config}" "${svf}"
    if [[ "${IS_COMPACT_ULX3S}" == 1 ]]; then
        printf 'Seed %s: clk_sys=%s MHz, clk_video=%s MHz, clk_tmds=%s MHz, route=%ss, %s\n' \
            "${seed}" "${clk_sys}" "${clk_video}" "${clk_tmds}" \
            "${route_seconds}" "${timing_status}"
    else
        printf 'Seed %s: clk_sys=%s MHz (nextpnr: %s), clk_video=%s MHz, clk_tmds=%s MHz, route=%ss, %s\n' \
            "${seed}" "${clk_sys}" "${sys_clock}" "${clk_video}" "${clk_tmds}" \
            "${route_seconds}" "${timing_status}"
    fi
}


for seed in "${SWEEP_SEEDS[@]}"; do
    rm -f "${SWEEP_DIR}/result-seed-${seed}.csv"
done

printf 'Routing %d seed(s):' "${#SWEEP_SEEDS[@]}"
printf ' %s' "${SWEEP_SEEDS[@]}"
printf '\nConcurrent route jobs: %s\n' "${SWEEP_JOBS}"
printf 'Per-seed nextpnr timeout: %ss (+%ss kill grace)\n' \
    "${SWEEP_ROUTE_TIMEOUT_SECONDS}" "${SWEEP_ROUTE_KILL_AFTER_SECONDS}"

status=0
running=0
for seed in "${SWEEP_SEEDS[@]}"; do
    run_seed "${seed}" &
    running=$((running + 1))
    if (( running >= SWEEP_JOBS )); then
        wait -n || status=1
        running=$((running - 1))
    fi
done
while (( running > 0 )); do
    wait -n || status=1
    running=$((running - 1))
done

{
    printf 'seed,clk_sys_mhz,clk_video_mhz,clk_tmds_mhz,route_seconds,timing_status\n'
    for seed in "${SWEEP_SEEDS[@]}"; do
        result="${SWEEP_DIR}/result-seed-${seed}.csv"
        if [[ -f "${result}" ]]; then
            cat "${result}"
        else
            printf '%d,MISSING,MISSING,MISSING,MISSING,MISSING\n' "${seed}"
            status=1
        fi
    done
} > "${results_file}"

pass_count="$(awk -F, 'NR > 1 && $6 == "PASS" {count++} END {print count + 0}' "${results_file}")"
pass_seeds="$(awk -F, 'NR > 1 && $6 == "PASS" {if (s != "") s=s ", "; s=s $1} END {print s}' "${results_file}")"
timeout_count="$(awk -F, 'NR > 1 && $6 == "TIMEOUT" {count++} END {print count + 0}' "${results_file}")"
timeout_seeds="$(awk -F, 'NR > 1 && $6 == "TIMEOUT" {if (s != "") s=s ", "; s=s $1} END {print s}' "${results_file}")"
printf 'Timing-passing seeds: %s\n' "${pass_count}"

if [[ "${pass_seeds:-none}" != "none" ]]; then
    printf '\n------------- PASS -------------\n'
fi

printf 'Timing-passing seeds: %s\n' "${pass_seeds:-none}"

if [[ "${pass_seeds:-none}" != "none" ]]; then
    printf '\n--------------------------------\n'
fi

printf 'Timed-out seeds: %s\n' "${timeout_count}"
printf 'TIMEOUT seed values: %s\n' "${timeout_seeds:-none}"
printf 'Results: %s\n' "${results_file}"

if (( pass_count == 0 )); then
    printf 'ERROR: No timing-passing seeds; sweep failed. Results retained in %s\n' "${results_file}" >&2
    status=1
fi

exit "${status}"
