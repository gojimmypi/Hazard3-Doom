# -----------------------------------------------------------------------------
# File:        load-ulx4m-ld-85f-monitor.gdb
# Path:        scripts/gdb/load-ulx4m-ld-85f-monitor.gdb
#
# Project:     Hazard3-Doom
# Purpose:     Load, verify, and run the monitor built for ULX4M-LD 85F.
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
# Run from the Hazard3-Doom repository root with OpenOCD already listening on
# localhost:3333. Build the matching target first with:
#   ./scripts/build-ulx4m-ld-doom.sh
# This intentionally uses the board-scoped monitor from the same build as the
# FPGA image so clock, memory-map, and loader-protocol settings stay matched.

set confirm off
set pagination off
set remotetimeout 120
file build/ulx4m-ld/monitor/hazard3-boot-monitor.elf
target extended-remote localhost:3333
monitor halt
load
compare-sections
set $pc = _start
monitor resume
disconnect
