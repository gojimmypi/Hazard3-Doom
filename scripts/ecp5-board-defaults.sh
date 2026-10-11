#!/bin/bash
# Shared nextpnr defaults for Hazard3-Doom ECP5 board profiles.
# Source this file from build and sweep scripts; do not execute it directly.
# Update the selected seed after a reproducible, timing-clean production build.
# These values depend on the synthesized netlist and nextpnr version.

ULX3S_12F_DEFAULT_NEXTPNR_SEED=82
ULX3S_12F_DEFAULT_NEXTPNR_HEAP_TIMINGWEIGHT=10
ULX3S_85F_DEFAULT_NEXTPNR_SEED=232
ULX3S_85F_DEFAULT_NEXTPNR_HEAP_TIMINGWEIGHT=10
ULX4M_LD_85F_DEFAULT_NEXTPNR_SEED=8
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
