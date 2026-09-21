# -----------------------------------------------------------------------------
# File:        load-ulx3s-12f-monitor.gdb
# Path:        scripts/gdb/load-ulx3s-12f-monitor.gdb
#
# Project:     Hazard3-Doom
# Purpose:     Load, verify, and run the monitor built for the ULX3S 12F target.
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
#   ./scripts/build-ulx3s-12f-doom.sh
# The 12F monitor is linked for external SDRAM, so use this board-specific ELF.

set confirm off
set pagination off
set remotetimeout 120
file build/ulx3s-12f/monitor/hazard3-boot-monitor.elf
target extended-remote localhost:3333
monitor halt
load
compare-sections
set $pc = _start
monitor resume
disconnect
