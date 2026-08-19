#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
RTL_DIR="${ROOT_DIR}/third_party/Hazard3/example_soc/soc"

iverilog -g2012 -Wall -o "${SCRIPT_DIR}/tb_apb_sao_bridge.out" \
    "${RTL_DIR}/sao_i2c_engine.v" \
    "${RTL_DIR}/apb_sao_bridge.v" \
    "${SCRIPT_DIR}/tb_apb_sao_bridge.v"

vvp "${SCRIPT_DIR}/tb_apb_sao_bridge.out"
