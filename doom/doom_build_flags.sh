#!/bin/bash

# Shared build flags for the Hazard3 Doom image and size probe.
#
# GCC 12.2.0 has an internal compiler error with the earlier -O3 plus
# Zba/Zbb/Zbs experiment. Performance-R5 uses the conservative RV32IMA ISA at
# -O2. The main speedups come from the shared 50 MHz Hazard3 clock, the 64 KiB
# cache, and direct block-RAM frame presentation without per-frame DDR traffic.

# Run ShellCheck to ensure this is a good script.
# Specify the executable shell checker you want to use:
MY_SHELLCHECK="shellcheck"

# Check if the executable is available in the PATH.
if command -v "${MY_SHELLCHECK}" >/dev/null 2>&1; then
    "${MY_SHELLCHECK}" -x "${BASH_SOURCE[0]}" >&2 || exit 1
else
    printf '%s\n' \
        "${MY_SHELLCHECK} is not installed. Please install it if changes to this script have been made." \
        >&2
fi

if [[ -z "${DOOMGENERIC_DIR:-}" || -z "${SCRIPT_DIR:-}" ]]; then
    echo "doom_build_flags.sh must be sourced after SCRIPT_DIR and DOOMGENERIC_DIR are set" >&2
    return 1
fi


memory_profile="${HAZARD3_MEMORY_PROFILE:-64m}"
case "${memory_profile}" in
64m)
    DOOM_MEMORY_PROFILE_FLAGS=()
    ;;
32m)
    DOOM_MEMORY_PROFILE_FLAGS=(-DHAZARD3_SDRAM_32MB)
    ;;
*)
    echo "Unsupported HAZARD3_MEMORY_PROFILE: ${memory_profile} (use 64m or 32m)" >&2
    return 1
    ;;
esac

DOOM_ARCH_FLAGS=(
    -march=rv32ima_zicsr_zifencei
    -mabi=ilp32
)

# This array is consumed by scripts that source this file.
# shellcheck disable=SC2034
DOOM_COMMON_COMPILE_FLAGS=(
    "${DOOM_ARCH_FLAGS[@]}"
    "${DOOM_MEMORY_PROFILE_FLAGS[@]}"
    -mcmodel=medany
    -mno-relax
    -O2
    -g3
    -ffunction-sections
    -fdata-sections
    -fno-common
    -fno-pic
    -fno-pie
    -msmall-data-limit=0
    -D_DEFAULT_SOURCE
    -DNORMALUNIX
    -DLINUX
    -DSNDSERV
    -DDOOMGENERIC_RESX=320
    -DDOOMGENERIC_RESY=200
    -DCMAP256
    -DDOOMGENERIC_EXTERNAL_SCREENBUFFER
    -DHAZARD3_SHARED_SCREENBUFFER
    -I"${DOOMGENERIC_DIR}"
    -I"${SCRIPT_DIR}"
)

# This array is consumed by scripts that source this file.
# shellcheck disable=SC2034
DOOM_UPSTREAM_WARNING_FLAGS=(
    -Wall
    -Wextra
    -Wno-unused-parameter
    -Wno-unused-but-set-parameter
    -Wno-unused-variable
    -Wno-unused-const-variable
    -Wno-sign-compare
    -Wno-missing-field-initializers
    -Wno-implicit-fallthrough
    -Wno-enum-conversion
    -Wno-type-limits
    -Wno-format
    -Wno-absolute-value
)

# This array is consumed by scripts that source this file.
# shellcheck disable=SC2034
DOOM_PORT_WARNING_FLAGS=(
    -Wall
    -Wextra
    -Werror
)

# This array is consumed by scripts that source this file.
# shellcheck disable=SC2034
DOOM_LINK_FLAGS=(
    "${DOOM_ARCH_FLAGS[@]}"
    -mcmodel=medany
    -mno-relax
    -nostartfiles
    -no-pie
    "-Wl,--no-relax"
)
