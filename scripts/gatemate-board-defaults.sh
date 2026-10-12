#!/bin/bash
# Shared nextpnr defaults for Hazard3-Doom GateMate board profiles.
# Source this file from build and sweep scripts; do not execute it directly.
# These values depend on the synthesized netlist and nextpnr version.

# Selected from the 12 MHz sweep with HeAP beta 0.6 and OSS CAD Suite 2026-07-20.
ULX5M_GS_DEFAULT_NEXTPNR_SEED=101
ULX5M_GS_DEFAULT_NEXTPNR_HEAP_BETA=0.6

# Assign the selected board's defaults for use by the sourcing script.
# The caller applies its own environment-variable override precedence.
gatemate_board_defaults()
{
    case "$1" in
    ulx5m-gs)
        # shellcheck disable=SC2034
        GATEMATE_DEFAULT_NEXTPNR_SEED="${ULX5M_GS_DEFAULT_NEXTPNR_SEED}"
        # shellcheck disable=SC2034
        GATEMATE_DEFAULT_NEXTPNR_HEAP_BETA="${ULX5M_GS_DEFAULT_NEXTPNR_HEAP_BETA}"
        ;;
    *)
        printf 'Unknown GateMate board profile: %s\n' "$1" >&2
        return 1
        ;;
    esac
}
