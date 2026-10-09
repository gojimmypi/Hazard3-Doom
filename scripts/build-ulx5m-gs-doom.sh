#!/bin/bash
# -----------------------------------------------------------------------------
# Build the complete phase-1 ULX5M-GS Hazard3-Doom target.
#
# Phase 1 provides UART, LEDs, native 32 MiB SDR SDRAM, SD SPI, the resident
# monitor, and a 32 MiB Doom image. DVI output is intentionally not included.
# -----------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
BUILD_DIR="${ROOT_DIR}/build"
BOARD_BUILD_DIR="${BUILD_DIR}/ulx5m-gs"
BUILD_LOG="${BUILD_DIR}/build-ulx5m-gs-doom.log"
HAZARD3_ROOT="${HAZARD3_ROOT:-${ROOT_DIR}/third_party/Hazard3}"
SYNTH_DIR="${HAZARD3_ROOT}/example_soc/synth"
MONITOR_BUILD_DIR="${HAZARD3_BUILD_DIR:-${BOARD_BUILD_DIR}/monitor}"
DOOM_BUILD_DIR="${HAZARD3_DOOM_BUILD_DIR:-${BOARD_BUILD_DIR}/doom-image}"
FPGA_OUTPUT="${BUILD_DIR}/fpga_ulx5m_gs.bit"
MONITOR_OUTPUT="${MONITOR_BUILD_DIR}/hazard3-boot-monitor.elf"
MONITOR_BIN="${MONITOR_BUILD_DIR}/hazard3-boot-monitor.bin"
BOOT_HEX_WORK="${HAZARD3_ROOT}/example_soc/soc/hazard3-boot-monitor.hex"
BOOT_HEX_OUTPUT="${BOARD_BUILD_DIR}/hazard3-boot-monitor.hex"
SDCARD_DIR="${BOARD_BUILD_DIR}/sdcard"
DOOM_OUTPUT="${DOOM_BUILD_DIR}/hazard3-doom.h3img"
ULX5M_SYS_CLK_MHZ="${ULX5M_SYS_CLK_MHZ:-12}"

case "${ULX5M_SYS_CLK_MHZ}" in
12|20|25)
    ;;
*)
    echo "ULX5M_SYS_CLK_MHZ must be 12, 20 or 25" >&2
    exit 1
    ;;
esac
ULX5M_SYS_CLK_HZ="$((ULX5M_SYS_CLK_MHZ * 1000000))"

require_file()
{
    local path="$1"

    if [[ ! -f "${path}" ]]; then
        printf 'Missing required file: %s\n' "${path}" >&2
        exit 1
    fi
}

require_executable()
{
    local path="$1"

    if [[ ! -x "${path}" ]]; then
        printf 'Missing required executable: %s\n' "${path}" >&2
        exit 1
    fi
}

require_tool()
{
    local tool="$1"

    if ! command -v "${tool}" >/dev/null 2>&1; then
        printf 'Missing required tool: %s\n' "${tool}" >&2
        exit 1
    fi
}

mkdir -p "${BUILD_DIR}"
if command -v tee >/dev/null 2>&1; then
    exec > >(tee "${BUILD_LOG}") 2>&1
fi

if [[ -z "${TOOLCHAIN_PREFIX:-}" ]]; then
    for candidate in \
        riscv-none-elf- \
        riscv32-unknown-elf- \
        riscv64-unknown-elf-
    do
        if command -v "${candidate}gcc" >/dev/null 2>&1; then
            TOOLCHAIN_PREFIX="${candidate}"
            break
        fi
    done
fi

if [[ -z "${TOOLCHAIN_PREFIX:-}" && -x /opt/riscv/bin/riscv32-unknown-elf-gcc ]]; then
    TOOLCHAIN_PREFIX="/opt/riscv/bin/riscv32-unknown-elf-"
fi

if [[ -z "${TOOLCHAIN_PREFIX:-}" ]]; then
    echo "ERROR: RISC-V GCC toolchain not found on PATH" >&2
    echo "Set TOOLCHAIN_PREFIX to select another compatible installation." >&2
    exit 1
fi
export TOOLCHAIN_PREFIX

require_tool make
require_tool install
require_tool python3
require_tool yosys
require_tool nextpnr-himbaechel
require_tool gmpack
require_file "${SYNTH_DIR}/ULX5M_GS.mk"
require_executable "${HAZARD3_ROOT}/scripts/listfiles"
require_executable "${ROOT_DIR}/scripts/build.sh"
require_executable "${ROOT_DIR}/scripts/make-boot-hex.py"
require_executable "${ROOT_DIR}/scripts/build-ulx5m-gs-bitstream.sh"
require_executable "${ROOT_DIR}/doom/build-doom-image.sh"
require_file "${HAZARD3_ROOT}/example_soc/soc/cache_tags_zero_12f.hex"

printf 'ULX5M-GS phase-1 configuration: %s MHz, 32 MiB SDRAM, headless video\n' \
    "${ULX5M_SYS_CLK_MHZ}"
printf 'Building resident monitor...\n'
HAZARD3_BUILD_DIR="${MONITOR_BUILD_DIR}" \
HAZARD3_MEMORY_PROFILE=32m \
HAZARD3_SYS_CLK_HZ="${ULX5M_SYS_CLK_HZ}" \
    "${ROOT_DIR}/scripts/build.sh"

require_file "${MONITOR_OUTPUT}"
require_file "${MONITOR_BIN}"

printf '\nEmbedding the 64 KiB resident monitor image...\n'
mkdir -p "${BOARD_BUILD_DIR}"
"${ROOT_DIR}/scripts/make-boot-hex.py" \
    "${MONITOR_BIN}" "${BOOT_HEX_WORK}" --bytes 0x10000 --load-address 0x40
install -m 0644 "${BOOT_HEX_WORK}" "${BOOT_HEX_OUTPUT}"

printf '\nBuilding GateMate A1 bitstream...\n'
FORCE_BITSTREAM_REBUILD=1 \
HAZARD3_ROOT="${HAZARD3_ROOT}" \
ULX5M_SYS_CLK_MHZ="${ULX5M_SYS_CLK_MHZ}" \
    "${ROOT_DIR}/scripts/build-ulx5m-gs-bitstream.sh"
require_file "${FPGA_OUTPUT}"

printf '\nBuilding 32 MiB Doom image...\n'
HAZARD3_DOOM_BUILD_DIR="${DOOM_BUILD_DIR}" \
HAZARD3_MEMORY_PROFILE=32m \
    "${ROOT_DIR}/doom/build-doom-image.sh"
require_file "${DOOM_OUTPUT}"

mkdir -p "${SDCARD_DIR}"
install -m 0644 "${DOOM_OUTPUT}" "${SDCARD_DIR}/DOOM.IMG"
if [[ -n "${HAZARD3_DOOM_WAD:-}" ]]; then
    require_file "${HAZARD3_DOOM_WAD}"
    install -m 0644 "${HAZARD3_DOOM_WAD}" "${SDCARD_DIR}/DOOM.WAD"
fi

printf '\nULX5M-GS phase-1 build complete.\n'
printf '  Clock:    %s MHz\n' "${ULX5M_SYS_CLK_MHZ}"
printf '  FPGA:     %s\n' "${FPGA_OUTPUT}"
printf '  Monitor:  %s\n' "${MONITOR_OUTPUT}"
printf '  Doom:     %s\n' "${DOOM_OUTPUT}"
printf '  Boot HEX: %s\n' "${BOOT_HEX_OUTPUT}"
printf '  SD image: %s\n' "${SDCARD_DIR}/DOOM.IMG"
printf '  Log:      %s\n' "${BUILD_LOG}"
printf '\nProgram through the board DirtyJTAG interface with:\n\n'
printf '  openFPGALoader -c dirtyJtag %s\n\n' "${FPGA_OUTPUT}"
printf 'Then open the ULX5M serial connection at 115200 baud.\n'
printf 'The first expected milestone is the Hazard3 monitor prompt and passing SDRAM tests.\n'
printf 'DVI is intentionally deferred to phase 2.\n'
