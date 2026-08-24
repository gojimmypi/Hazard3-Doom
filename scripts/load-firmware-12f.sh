#!/bin/bash
# Load the ULX3S 12F SDRAM-resident monitor after FPGA configuration.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
ELF="${1:-${ROOT_DIR}/build/ulx3s-12f/monitor/hazard3-boot-monitor.elf}"
echo "Loading: "
ls -al ${ELF}
exec "${SCRIPT_DIR}/load-firmware.sh" "${ELF}"
