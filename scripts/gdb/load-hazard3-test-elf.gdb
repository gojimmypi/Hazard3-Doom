# -----------------------------------------------------------------------------
# File:        load-hazard3-test-elf.gdb
# Path:        scripts/gdb/load-hazard3-test-elf.gdb
#
# Project:     Hazard3-Doom
# Purpose:     Load, verify, reset, and run the Hazard3 test or monitor ELF
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

monitor reset halt
file build/hazard3-boot-monitor.elf
load
compare-sections
monitor reset halt
continue
