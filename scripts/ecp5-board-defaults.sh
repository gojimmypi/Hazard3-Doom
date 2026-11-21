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

# FPGA device selection for all local builds and seed sweeps.
#
# Board ID chooses the SoC RTL, memory profile, pins and clocks. The FPGA part
# chooses the nextpnr timing model and ecppack IDCODE. These are independent:
# a board may ship with a different, pin-compatible ECP5 family or speed grade.
# Always use the exact chip marking. A faster timing model cannot qualify a
# design for a slower or otherwise different chip.
#
# ECP5_PNR_DEVICE accepts a full family/capacity/speed identifier, for example
# LFE5UM5G-85F-8. Omit it or set board-default to keep the board baseline.
# The older ECP5_PNR_SPEED_GRADE override remains supported for SAME-family
# experiments; when specifying a full part, its suffix determines the grade.
ecp5_pnr_device_profile()
{
    local board_id="$1"
    local default_family default_speed selected_family selected_speed

    case "${board_id}" in
    ulx3s-12f)
        default_family="LFE5U-12F"
        default_speed=6
        ;;
    ulx3s-85f)
        default_family="LFE5U-85F"
        default_speed=6
        ;;
    ulx4m-ld-85f)
        default_family="LFE5UM-85F"
        default_speed=8
        ;;
    *)
        printf 'Unsupported ECP5 board: %s\n' "${board_id}" >&2
        return 1
        ;;
    esac

    ECP5_PNR_DEFAULT_DEVICE="${default_family}-${default_speed}"
    ECP5_PNR_PACKAGE="${ECP5_PNR_PACKAGE:-CABGA381}"
    if [[ ! "${ECP5_PNR_PACKAGE}" =~ ^[A-Za-z0-9]+$ ]]; then
        echo "ECP5_PNR_PACKAGE must be an alphanumeric nextpnr package name." >&2
        return 1
    fi

    if [[ -z "${ECP5_PNR_DEVICE:-}" || "${ECP5_PNR_DEVICE}" == board-default ]]; then
        # Legacy speed-only override retains the established board family.
        selected_speed="${ECP5_PNR_SPEED_GRADE:-${default_speed}}"
        ECP5_PNR_DEVICE="${default_family}-${selected_speed}"
    else
        selected_speed="${ECP5_PNR_DEVICE##*-}"
        # Do not silently accept conflicting family+grade inputs.
        if [[ -n "${ECP5_PNR_SPEED_GRADE:-}" &&
              "${ECP5_PNR_SPEED_GRADE}" != "${selected_speed}" ]]; then
            printf 'ECP5_PNR_SPEED_GRADE=%s conflicts with ECP5_PNR_DEVICE=%s\n' \
                "${ECP5_PNR_SPEED_GRADE}" "${ECP5_PNR_DEVICE}" >&2
            return 1
        fi
    fi

    # 45F ULX3S boards can use either existing SoC profile. The compact
    # 12F profile is the practical starting point: the full 85F RTL may exceed
    # the 45F's 108 EBR blocks (checked separately after synthesis).
    # ULX4M is still restricted to its supported 85F families.
    case "${board_id}:${ECP5_PNR_DEVICE}" in
    ulx3s-12f:LFE5U-12F-[678]|ulx3s-12f:LFE5U-45F-[678]) ;;
    ulx3s-85f:LFE5U-45F-[678]|ulx3s-85f:LFE5U-85F-[678]|ulx3s-85f:LFE5UM-85F-[678]|ulx3s-85f:LFE5UM5G-85F-8) ;;
    ulx4m-ld-85f:LFE5U-85F-[678]|ulx4m-ld-85f:LFE5UM-85F-[678]|ulx4m-ld-85f:LFE5UM5G-85F-8) ;;
    *)
        printf 'Unsupported FPGA part %s for board %s.\n' \
            "${ECP5_PNR_DEVICE}" "${board_id}" >&2
        return 1
        ;;
    esac

    ECP5_PNR_SPEED_GRADE="${selected_speed}"
    selected_family="${ECP5_PNR_DEVICE%-*}"
    case "${selected_family}" in
    LFE5U-12F)
        ECP5_PNR_DEVICE_OPTION="--12k"
        # Assigned for scripts that source this file (ShellCheck cannot see those readers).
        # shellcheck disable=SC2034
        ECP5_PNR_IDCODE="0x21111043"
        ;;
    LFE5U-45F)
        ECP5_PNR_DEVICE_OPTION="--45k"
        # Assigned for scripts that source this file (ShellCheck cannot see those readers).
        # shellcheck disable=SC2034
        ECP5_PNR_IDCODE="0x41112043"
        ;;
    LFE5U-85F)
        ECP5_PNR_DEVICE_OPTION="--85k"
        # Assigned for scripts that source this file (ShellCheck cannot see those readers).
        # shellcheck disable=SC2034
        ECP5_PNR_IDCODE="0x41113043"
        ;;
    LFE5UM-85F)
        ECP5_PNR_DEVICE_OPTION="--um-85k"
        # Assigned for scripts that source this file (ShellCheck cannot see those readers).
        # shellcheck disable=SC2034
        ECP5_PNR_IDCODE="0x01113043"
        ;;
    LFE5UM5G-85F)
        ECP5_PNR_DEVICE_OPTION="--um5g-85k"
        # Assigned for scripts that source this file (ShellCheck cannot see those readers).
        # shellcheck disable=SC2034
        ECP5_PNR_IDCODE="0x81113043"
        ;;
    esac

    # Read by the independently ShellCheck-checked build and sweep scripts.
    # shellcheck disable=SC2034
    PNR_DEVICE_ARGS=("${ECP5_PNR_DEVICE_OPTION}" --speed "${ECP5_PNR_SPEED_GRADE}" --package "${ECP5_PNR_PACKAGE}")
}

# Keep existing output paths for each board's original family at any grade;
# distinguish a different family explicitly so results can never overlap.
ecp5_pnr_device_suffix()
{
    local default_family="${ECP5_PNR_DEFAULT_DEVICE%-*}"
    local selected_family="${ECP5_PNR_DEVICE%-*}"
    local default_speed="${ECP5_PNR_DEFAULT_DEVICE##*-}"

    if [[ "${selected_family}" != "${default_family}" ]]; then
        printf -- '-%s-%s\n' "${ECP5_PNR_DEVICE}" "${ECP5_PNR_PACKAGE}"
    elif [[ "${ECP5_PNR_SPEED_GRADE}" != "${default_speed}" ||
            "${ECP5_PNR_PACKAGE}" != CABGA381 ]]; then
        printf -- '-speed%s-%s\n' "${ECP5_PNR_SPEED_GRADE}" "${ECP5_PNR_PACKAGE}"
    fi
}
