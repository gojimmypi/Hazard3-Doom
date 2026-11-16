#!/bin/bash
# Shared nextpnr defaults for Hazard3-Doom ECP5 board profiles.
# Source this file from build and sweep scripts; do not execute it directly.
# Update the selected seed after a reproducible, timing-clean production build.
# These values depend on the synthesized netlist and nextpnr version.

ULX3S_12F_DEFAULT_NEXTPNR_SEED=151
ULX3S_12F_DEFAULT_NEXTPNR_HEAP_TIMINGWEIGHT=10
# Seed 11 closed timing at 25 MHz with the correct LFE5U-85F speed grade 6.
# All 40/50 MHz profiles need new timing qualification before release.
ULX3S_85F_DEFAULT_NEXTPNR_SEED=11
ULX3S_85F_DEFAULT_NEXTPNR_HEAP_TIMINGWEIGHT=10
ULX3S_85F_DEFAULT_SYS_CLK_MHZ=25

# Keep the physical system clock in sync across RTL, monitor and sweep flows.
ecp5_ulx3s_85f_clock_profile()
{
    HAZARD3_ULX3S_85F_SYS_CLK_MHZ="${HAZARD3_ULX3S_85F_SYS_CLK_MHZ:-${ULX3S_85F_DEFAULT_SYS_CLK_MHZ}}"
    case "${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}" in
    25|40|50) ;;
    *)
        echo "HAZARD3_ULX3S_85F_SYS_CLK_MHZ must be 25, 40, or 50." >&2
        return 1
        ;;
    esac

    # Keep the existing qualified 25 MHz datapath unchanged. For 40/50 MHz,
    # enable the cache's existing registered read-hit response by default.
    local default_registered_hits=0
    if [[ "${HAZARD3_ULX3S_85F_SYS_CLK_MHZ}" != 25 ]]; then
        default_registered_hits=1
    fi
    HAZARD3_ULX3S_85F_REGISTERED_READ_HITS="${HAZARD3_ULX3S_85F_REGISTERED_READ_HITS:-${default_registered_hits}}"
    case "${HAZARD3_ULX3S_85F_REGISTERED_READ_HITS}" in
    0|1) ;;
    *)
        echo "HAZARD3_ULX3S_85F_REGISTERED_READ_HITS must be 0 or 1." >&2
        return 1
        ;;
    esac

    # The 85F 128 KiB EBR SRAM uses the original write buffer by default.
    # Set 0 only to compare the existing no-buffer SRAM adapter implementation.
    HAZARD3_ULX3S_85F_SRAM_WRITE_BUFFER="${HAZARD3_ULX3S_85F_SRAM_WRITE_BUFFER:-1}"
    case "${HAZARD3_ULX3S_85F_SRAM_WRITE_BUFFER}" in
    0|1) ;;
    *)
        echo "HAZARD3_ULX3S_85F_SRAM_WRITE_BUFFER must be 0 or 1." >&2
        return 1
        ;;
    esac

    # Register the SDRAM cache tag lookup before the write/miss controls.
    # This costs one AHB wait cycle and requires registered read-hit responses.
    HAZARD3_ULX3S_85F_CACHE_TAG_PIPELINE="${HAZARD3_ULX3S_85F_CACHE_TAG_PIPELINE:-0}"
    case "${HAZARD3_ULX3S_85F_CACHE_TAG_PIPELINE}" in
    0|1) ;;
    *)
        echo "HAZARD3_ULX3S_85F_CACHE_TAG_PIPELINE must be 0 or 1." >&2
        return 1
        ;;
    esac
    if [[ "${HAZARD3_ULX3S_85F_CACHE_TAG_PIPELINE}" == 1 &&
          "${HAZARD3_ULX3S_85F_REGISTERED_READ_HITS}" != 1 ]]; then
        echo "CACHE_TAG_PIPELINE=1 requires REGISTERED_READ_HITS=1." >&2
        return 1
    fi

    # Registered cache-tag write-data and separate per-way RAM enables.
    # This specifically targets the long CPU -> tag RAM data input path.
    HAZARD3_ULX3S_85F_TAG_RAM_MODE="${HAZARD3_ULX3S_85F_TAG_RAM_MODE:-0}"
    case "${HAZARD3_ULX3S_85F_TAG_RAM_MODE}" in
    0|1|2) ;;
    *)
        echo "HAZARD3_ULX3S_85F_TAG_RAM_MODE must be 0, 1, or 2." >&2
        return 1
        ;;
    esac

    # Add an AHB wait cycle before reading the synchronous cache EBRs.
    # This prevents the live CPU address from directly reaching cache RAM pins.
    HAZARD3_ULX3S_85F_CACHE_ADDR_PIPELINE="${HAZARD3_ULX3S_85F_CACHE_ADDR_PIPELINE:-0}"
    case "${HAZARD3_ULX3S_85F_CACHE_ADDR_PIPELINE}" in
    0|1) ;;
    *)
        echo "HAZARD3_ULX3S_85F_CACHE_ADDR_PIPELINE must be 0 or 1." >&2
        return 1
        ;;
    esac
    if [[ "${HAZARD3_ULX3S_85F_CACHE_ADDR_PIPELINE}" == 1 &&
          "${HAZARD3_ULX3S_85F_REGISTERED_READ_HITS}" != 1 ]]; then
        echo "CACHE_ADDR_PIPELINE=1 requires REGISTERED_READ_HITS=1." >&2
        return 1
    fi

    # Experimental dual-port read/write EBR SRAM: opt-in, not qualified.
    HAZARD3_ULX3S_85F_SRAM_DUAL_PORT_RW="${HAZARD3_ULX3S_85F_SRAM_DUAL_PORT_RW:-0}"
    case "${HAZARD3_ULX3S_85F_SRAM_DUAL_PORT_RW}" in
    0|1) ;;
    *)
        echo "HAZARD3_ULX3S_85F_SRAM_DUAL_PORT_RW must be 0 or 1." >&2
        return 1
        ;;
    esac
    if [[ "${HAZARD3_ULX3S_85F_SRAM_DUAL_PORT_RW}" == 1 &&
          "${HAZARD3_ULX3S_85F_SRAM_WRITE_BUFFER}" != 1 ]]; then
        echo "SRAM_DUAL_PORT_RW=1 requires SRAM_WRITE_BUFFER=1." >&2
        return 1
    fi
}
ULX4M_LD_85F_DEFAULT_NEXTPNR_SEED=89
ULX4M_LD_85F_DEFAULT_NEXTPNR_HEAP_TIMINGWEIGHT=30

# Export the selected board's defaults into neutral variable names.
# The caller applies its own environment-variable override precedence.
ecp5_board_defaults()
{
    case "$1" in
    ulx3s-12f)
        ECP5_DEFAULT_NEXTPNR_SEED="${ULX3S_12F_DEFAULT_NEXTPNR_SEED}"
        ECP5_DEFAULT_NEXTPNR_HEAP_TIMINGWEIGHT="${ULX3S_12F_DEFAULT_NEXTPNR_HEAP_TIMINGWEIGHT}"
        ;;
    ulx3s-85f)
        ECP5_DEFAULT_NEXTPNR_SEED="${ULX3S_85F_DEFAULT_NEXTPNR_SEED}"
        ECP5_DEFAULT_NEXTPNR_HEAP_TIMINGWEIGHT="${ULX3S_85F_DEFAULT_NEXTPNR_HEAP_TIMINGWEIGHT}"
        ;;
    ulx4m-ld-85f)
        # Assigned for use by the sourcing script.
        # shellcheck disable=SC2034
        ECP5_DEFAULT_NEXTPNR_SEED="${ULX4M_LD_85F_DEFAULT_NEXTPNR_SEED}"
        # Assigned for use by the sourcing script.
        # shellcheck disable=SC2034
        ECP5_DEFAULT_NEXTPNR_HEAP_TIMINGWEIGHT="${ULX4M_LD_85F_DEFAULT_NEXTPNR_HEAP_TIMINGWEIGHT}"
        ;;
    *)
        printf 'Unknown ECP5 board profile: %s\n' "$1" >&2
        return 1
        ;;
    esac
}

# ECP5 nextpnr device options shared by local builds and seed sweeps.
# The device family stays board-specific; override speed/package only for
# experiments. Changing these options does not modify the installed FPGA.
ecp5_pnr_device_profile()
{
    local board_id="$1"
    local device_option default_speed
    case "${board_id}" in
    ulx3s-85f) device_option="--85k"; default_speed=6 ;;
    ulx3s-12f) device_option="--12k"; default_speed=6 ;;
    ulx4m-ld-85f) device_option="--um-85k"; default_speed=8 ;;
    *) echo "Unsupported ECP5 device profile: ${board_id}" >&2; return 1 ;;
    esac

    ECP5_PNR_SPEED_GRADE="${ECP5_PNR_SPEED_GRADE:-${default_speed}}"
    ECP5_PNR_PACKAGE="${ECP5_PNR_PACKAGE:-CABGA381}"
    if [[ ! "${ECP5_PNR_SPEED_GRADE}" =~ ^[1-9][0-9]*$ ]]; then
        echo "ECP5_PNR_SPEED_GRADE must be a positive integer." >&2
        return 1
    fi
    if [[ ! "${ECP5_PNR_PACKAGE}" =~ ^[A-Za-z0-9]+$ ]]; then
        echo "ECP5_PNR_PACKAGE must be an alphanumeric nextpnr package name." >&2
        return 1
    fi
    # This array is populated for the build/sweep script that sources this file.
    # ShellCheck cannot see the use across independently checked source files.
    # shellcheck disable=SC2034
    PNR_DEVICE_ARGS=("${device_option}" --speed "${ECP5_PNR_SPEED_GRADE}" --package "${ECP5_PNR_PACKAGE}")
}
