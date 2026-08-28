# -----------------------------------------------------------------------------
# File:        sao-probe.gdb
# Path:        scripts/gdb/sao-probe.gdb
#
# Project:     Hazard3-Doom
# Purpose:     Define a GDB command for probing one SAO I2C address through
#              the Hazard3 bridge.
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

# Define a reusable GDB command named sao-probe; pass one 7-bit address, for example: sao-probe 0x54.
define sao-probe
    # Copy the command argument into a readable local GDB convenience variable.
    set $addr = $arg0
    # End any transaction left active by an interrupted test.
    set {unsigned int}0x40009000 = 2
    # Generate an I2C START condition.
    set {unsigned int}0x40009000 = 1
    # Load TXDATA with the 8-bit write address derived from the supplied 7-bit address.
    set {unsigned int}0x40009008 = ($addr << 1)
    # Transmit the address byte and sample ACK/NACK.
    set {unsigned int}0x40009000 = 3
    # Save the resulting bridge STATUS value.
    set $s = *(unsigned int *)0x40009004
    # Print the address and STATUS value; ACK is bit 2 and NACK is bit 3.
    printf "probe 0x%02x status=0x%08x ACK=%u NACK=%u\n", $addr, $s, (($s >> 2) & 1), (($s >> 3) & 1)
    # Generate STOP to return SDA/SCL to the idle state.
    set {unsigned int}0x40009000 = 2
    # Read LINES after STOP; 0x0f means SDA/SCL/GPIO1/GPIO2 are all high.
    set $lines = *(unsigned int *)0x4000901c
    # Print the final physical-line sample.
    printf "lines=0x%08x\n", $lines
# End the reusable sao-probe command definition.
end

# Add GDB help text for the reusable sao-probe command.
document sao-probe
Probe one 7-bit I2C address through the Hazard3 SAO bridge.
Example: sao-probe 0x54
end
