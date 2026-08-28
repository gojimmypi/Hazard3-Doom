# -----------------------------------------------------------------------------
# File:        hazard3-debug.gdb
# Path:        scripts/hazard3-debug.gdb
#
# Project:     Hazard3-Doom
# Purpose:     Configure GDB for source-level Hazard3-Doom monitor debugging
#              through OpenOCD.
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

# VisualGDB startup helper for the standalone Hazard3-Doom monitor.

set confirm off
set pagination off
set remotetimeout 30

# Hazard3 exposes three hardware breakpoint triggers and no hardware watchpoints.
set remote hardware-breakpoint-limit 3
set remote hardware-watchpoint-limit 0
set can-use-hw-watchpoints 0

define hazard3-start
    monitor halt
    load
    set $pc = _start
end

document hazard3-start
Halt Hazard3, load the monitor, set the entry point, and remain halted.
end
