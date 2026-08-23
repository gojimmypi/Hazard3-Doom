#!/bin/bash
#
# Copyright (c) 2026 gojimmypi
# SPDX-License-Identifier: Apache-2.0
#
# file: scripts/build-ecp5-bitstream-common.sh
#
# Shared ECP5 synthesis/place-and-route flow for Hazard3-Doom board wrappers.
# Board-specific behavior is selected by the first argument.

set -euo pipefail

BOARD_ID="${1:-}"
shift || true

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
HAZARD3_ROOT="${HAZARD3_ROOT:-${REPO_ROOT}/third_party/Hazard3}"
HAZARD3_SYNTH="${HAZARD3_ROOT}/example_soc/synth"
BUILD_DIR="${REPO_ROOT}/build"
ALLOW_TIMING_FAILURE="${ALLOW_TIMING_FAILURE:-0}"
FORCE_BITSTREAM_REBUILD="${FORCE_BITSTREAM_REBUILD:-0}"

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

    if [[ -f "${SEED_STAMP}" ]]; then
        read -r recorded_seed < "${SEED_STAMP}" || true
    fi

    if [[ -s "${BITSTREAM_OUTPUT}" && "${FORCE_BITSTREAM_REBUILD}" == 0 ]]; then
        if [[ "${recorded_seed}" == "${NEXTPNR_SEED}" &&
              "${BITSTREAM_OUTPUT}" -nt "${NETLIST}" ]]; then
            printf 'Reusing existing ULX4M-LD 85F bitstream built with seed %s; nextpnr was not run.\n' \
                "${NEXTPNR_SEED}"
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
    esac
}

validate_ulx4m_synthesis()
{
    local ebr_used

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
# ULX4M-LD seed reference from scripts/sweep-ulx4m-ld.sh:
#
# No seed met both the 50.00 MHz clk_sys and 75.01 MHz LiteDRAM targets.
#
# | Rank | Seed | clk_sys | LiteDRAM | Video | TMDS   | Result |
# | ---: | ---: | ------: | -------: | ----: | -----: | :----- |
# |    1 |  163 | 44.10   | 66.55    | 61.80 | 319.59 | FAIL   |
# |    2 |  232 | 43.58   | 67.41    | 62.37 | 332.78 | FAIL   |
# |    3 |  200 | 43.44   | 65.71    | 58.96 | 321.03 | FAIL   |
# |    4 |  247 | 43.00   | 65.47    | 62.29 | 307.13 | FAIL   |
# |    5 |   20 | 42.97   | 64.49    | 61.15 | 313.28 | FAIL   |
# |    6 |  181 | 42.96   | 65.96    | 66.25 | 334.22 | FAIL   |
# |    7 |   50 | 42.77   | 67.61    | 60.94 | 302.66 | FAIL   |
# |    8 |  204 | 42.71   | 65.60    | 69.78 | 321.85 | FAIL   |
# |    9 |   17 | 42.66   | 68.88    | 69.68 | 318.67 | FAIL   |
# |   10 |   22 | 42.55   | 70.32    | 66.18 | 285.06 | FAIL   |
#
case "${BOARD_ID}" in
ulx3s-85f)
    DISPLAY_NAME="ULX3S 85F"
    FPGA_NAME="fpga_ulx3s"
    MAKEFILE="ULX3S.mk"
    LPF="${HAZARD3_SYNTH}/fpga_ulx3s.lpf"
    IDCODE="0x41113043"
    NEXTPNR_SEED="${NEXTPNR_SEED:-55}"
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
    NEXTPNR_SEED="${NEXTPNR_SEED:-55}"
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
    NEXTPNR_SEED="${NEXTPNR_SEED:-232}"
    PNR_DEVICE_ARGS=(--um-85k --speed 8 --package CABGA381)
    LITEDRAM_DIR="${HAZARD3_ROOT}/example_soc/third_party/LiteDRAM/generated"
    SEED_STAMP="${BUILD_DIR}/fpga_ulx4m_ld.seed"
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

mkdir -p "${BUILD_DIR}"

require_tool stat
require_tool make
require_tool yosys
require_tool nextpnr-ecp5
require_tool ecppack
require_file "${HAZARD3_SYNTH}/${MAKEFILE}"
require_file "${LPF}"

if [[ "${BOARD_ID}" == "ulx4m-ld-85f" ]]; then
    require_tool grep
    require_tool awk
    require_file "${LITEDRAM_DIR}/litedram_ulx4m_cpu.v"
    require_file "${LITEDRAM_DIR}/litedram_ulx4m_cpu_rom.init"
    require_file "${LITEDRAM_DIR}/litedram_ulx4m_cpu_sram.init"
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

run_synthesis

if [[ "${BOARD_ID}" == "ulx3s-12f" ]]; then
    validate_ulx3s_12f_synthesis
    reuse_ulx3s_12f_bitstream_if_allowed
fi
if [[ "${BOARD_ID}" == "ulx4m-ld-85f" ]]; then
    validate_ulx4m_synthesis
    reuse_ulx4m_bitstream_if_allowed
fi

printf 'nextpnr seed: %s\n' "${NEXTPNR_SEED}"
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

    nextpnr-ecp5 \
        --seed "${NEXTPNR_SEED}" \
        --placer heap \
        "${PNR_DEVICE_ARGS[@]}" \
        --lpf "${LPF}" \
        --json "${NETLIST}" \
        --textcfg "${CONFIG_TEMP}" \
        "${timing_options[@]}" \
        --quiet \
        --log "${PNR_LOG}"

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
