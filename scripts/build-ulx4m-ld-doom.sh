#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
HAZARD3_ROOT="${HAZARD3_ROOT:-${ROOT_DIR}/third_party/Hazard3}"
SYNTH_DIR="${HAZARD3_ROOT}/example_soc/synth"
BOARD_BUILD_DIR="${ROOT_DIR}/build/ulx4m-ld"
MONITOR_BUILD_DIR="${HAZARD3_BUILD_DIR:-${ROOT_DIR}/build}"
DOOM_BUILD_DIR="${HAZARD3_DOOM_BUILD_DIR:-${ROOT_DIR}/build/doom-image}"
FPGA_SOURCE="${SYNTH_DIR}/fpga_ulx4m_ld.bit"
FPGA_OUTPUT="${BOARD_BUILD_DIR}/fpga_ulx4m_ld.bit"
MONITOR_OUTPUT="${MONITOR_BUILD_DIR}/hazard3-boot-monitor.elf"
DOOM_OUTPUT="${DOOM_BUILD_DIR}/hazard3-doom.h3d"
LITEDRAM_DIR="${HAZARD3_ROOT}/example_soc/third_party/LiteDRAM/generated"

# Run shellcheck to ensure this is a good script.
# Specify the executable shell checker you want to use:
MY_SHELLCHECK="shellcheck"

# Check if the executable is available in the PATH
if command -v "$MY_SHELLCHECK" >/dev/null 2>&1; then
    # Run your command here
    shellcheck "$0" || exit 1
else
    echo "$MY_SHELLCHECK is not installed. Please install it if changes to this script have been made."
fi

require_file()
{
    local path="$1"

    [[ -f "${path}" ]] || {
        echo "Missing required file: ${path}" >&2
        echo "Initialize Hazard3 or set HAZARD3_ROOT correctly." >&2
        exit 1
    }
}

require_executable()
{
    local path="$1"

    [[ -x "${path}" ]] || {
        echo "Missing required executable: ${path}" >&2
        echo "Initialize Hazard3 or set HAZARD3_ROOT correctly." >&2
        exit 1
    }
}

require_tool()
{
    local tool="$1"

    command -v "${tool}" >/dev/null 2>&1 || {
        echo "Missing required tool: ${tool}" >&2
        exit 1
    }
}

require_tool make
require_file "${SYNTH_DIR}/ULX4M_LD_85F.mk"
require_file "${HAZARD3_ROOT}/scripts/synth_ecp5.mk"
require_executable "${HAZARD3_ROOT}/scripts/listfiles"
require_executable "${ROOT_DIR}/scripts/build-ulx4m-ld-bitstream.sh"
require_file "${HAZARD3_ROOT}/example_soc/libfpga/common/reset_sync.v"
require_file "${LITEDRAM_DIR}/litedram_ulx4m_cpu.v"
require_file "${LITEDRAM_DIR}/litedram_ulx4m_cpu_rom.init"
require_file "${LITEDRAM_DIR}/litedram_ulx4m_cpu_sram.init"
require_executable "${ROOT_DIR}/scripts/build.sh"
require_executable "${ROOT_DIR}/doom/build-doom-image.sh"

printf 'Building the Hazard3 ULX4M-LD 85F FPGA target...\n'
HAZARD3_ROOT="${HAZARD3_ROOT}" \
    "${ROOT_DIR}/scripts/build-ulx4m-ld-bitstream.sh"

mkdir -p "${BOARD_BUILD_DIR}"
require_file "${FPGA_SOURCE}"
cp "${FPGA_SOURCE}" "${FPGA_OUTPUT}"

printf '\nBuilding the shared 50 MHz monitor with the 64 MiB map...\n'
HAZARD3_BUILD_DIR="${MONITOR_BUILD_DIR}" \
HAZARD3_MEMORY_PROFILE=64m \
HAZARD3_SYS_CLK_HZ=50000000 \
    "${ROOT_DIR}/scripts/build.sh"

printf '\nBuilding the shared 64 MiB Doom image...\n'
HAZARD3_DOOM_BUILD_DIR="${DOOM_BUILD_DIR}" \
HAZARD3_MEMORY_PROFILE=64m \
    "${ROOT_DIR}/doom/build-doom-image.sh"

require_file "${FPGA_OUTPUT}"
require_file "${MONITOR_OUTPUT}"
require_file "${DOOM_OUTPUT}"

printf '\nULX4M-LD 85F Doom build complete.\n'
printf '  FPGA:    %s\n' "${FPGA_OUTPUT}"
printf '  Monitor: %s\n' "${MONITOR_OUTPUT}"
printf '  Doom:    %s\n' "${DOOM_OUTPUT}"
