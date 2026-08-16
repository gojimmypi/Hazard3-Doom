#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
HAZARD3_ROOT="${HAZARD3_ROOT:-${REPO_ROOT}/third_party/Hazard3}"
HAZARD3_SYNTH="${HAZARD3_ROOT}/example_soc/synth"
ULX3S_SEED_SWEEP_DIR="${REPO_ROOT}/build/ulx3s-seed-sweep"

mkdir -p "${ULX3S_SEED_SWEEP_DIR}"

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

# The cold-boot FPGA netlist includes the resident monitor EBR image. Build
# that image once before sweeping seeds so every P&R run uses the same netlist.
MONITOR_BUILD_DIR="${REPO_ROOT}/build/monitor/ulx3s-64m"
MONITOR_BIN="${MONITOR_BUILD_DIR}/hazard3-test.bin"
BOOT_HEX="${HAZARD3_ROOT}/example_soc/soc/hazard3_boot.hex"

HAZARD3_BUILD_DIR="${MONITOR_BUILD_DIR}" \
HAZARD3_MEMORY_PROFILE=64m \
HAZARD3_SYS_CLK_HZ=50000000 \
    "${SCRIPT_DIR}/build.sh"

"${SCRIPT_DIR}/make-boot-hex.py" \
    "${MONITOR_BIN}" "${BOOT_HEX}" --bytes 0x10000 --load-address 0x40

# Seed results are intentionally not embedded here; the SAO+ESP32+SD cold-boot
# netlist requires a fresh sweep before selecting a new default seed.

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

for NEXTPNR_SEED in {1..260}
do
    printf '\nTrying nextpnr seed %s\n' "${NEXTPNR_SEED}"

    if FORCE_BITSTREAM_REBUILD=1 \
        HAZARD3_ROOT="${HAZARD3_ROOT}" \
        NEXTPNR_SEED="${NEXTPNR_SEED}" \
        "${SCRIPT_DIR}/build-ulx3s-85f-bitstream.sh"
    then
        cp "${HAZARD3_SYNTH}/pnr.log" \
            "${ULX3S_SEED_SWEEP_DIR}/pnr-${NEXTPNR_SEED}.log"

        cp "${HAZARD3_SYNTH}/fpga_ulx3s.bit" \
            "${ULX3S_SEED_SWEEP_DIR}/fpga_ulx3s-${NEXTPNR_SEED}.bit"

        grep 'Max frequency for clock' \
            "${ULX3S_SEED_SWEEP_DIR}/pnr-${NEXTPNR_SEED}.log"
    else
        printf 'Seed %s failed\n' "${NEXTPNR_SEED}" >&2

        if [[ -f "${HAZARD3_SYNTH}/pnr.log" ]]; then
            cp "${HAZARD3_SYNTH}/pnr.log" \
                "${ULX3S_SEED_SWEEP_DIR}/pnr-${NEXTPNR_SEED}-failed.log"
        fi
    fi
done |& tee "${ULX3S_SEED_SWEEP_DIR}/summary.log"
