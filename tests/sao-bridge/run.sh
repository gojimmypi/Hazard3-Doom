#!/bin/bash
# -----------------------------------------------------------------------------
# File:        run.sh
# Path:        tests/sao-bridge/run.sh
#
# Project:     Hazard3-Doom
# Purpose:     Build and run the SAO APB bridge RTL testbench.
#
# Copyright (c) 2026 gojimmypi
#
# Licensed under the Apache License, Version 2.0.
#
# SPDX-License-Identifier: Apache-2.0
#
# This software is provided under the terms of the applicable license.
# See LICENSES/Apache-2.0.txt for the complete license terms.
# See LICENSING.md for project licensing policy and scope.
# -----------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
RTL_DIR="${ROOT_DIR}/third_party/Hazard3/example_soc/soc"

iverilog -g2012 -Wall -o "${SCRIPT_DIR}/tb_apb_sao_bridge.out" \
    "${RTL_DIR}/sao_i2c_engine.v" \
    "${RTL_DIR}/apb_sao_bridge.v" \
    "${SCRIPT_DIR}/tb_apb_sao_bridge.v"

vvp "${SCRIPT_DIR}/tb_apb_sao_bridge.out"
