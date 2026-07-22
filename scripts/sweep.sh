#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
HAZARD3_ROOT="${HAZARD3_ROOT:-${REPO_ROOT}/third_party/Hazard3}"
HAZARD3_SYNTH="${HAZARD3_ROOT}/example_soc/synth"
ULX3S_SEED_SWEEP_DIR="${REPO_ROOT}/build/ulx3s-seed-sweep"

mkdir -p "${ULX3S_SEED_SWEEP_DIR}"

# |   Seed |          `clk_sys` |
# | -----: | -----------------: |
# | **56** | **51.92 MHz PASS** |
# |    173 |     50.45 MHz PASS |
# |     76 |     50.40 MHz PASS |
# |     46 |     50.33 MHz PASS |
# |     33 |     50.31 MHz PASS |
# |    205 |     50.25 MHz PASS |
# |    201 |     50.16 MHz PASS |
# |     13 |     47.54 MHz      |
# | 809026061346936167   | 46.92 MHz |
# | 13174890808159154548 | 46.83 MHz |

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

for NEXTPNR_SEED in {14..260}
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
