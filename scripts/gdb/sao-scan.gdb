# -----------------------------------------------------------------------------
# File:        sao-scan.gdb
# Path:        scripts/gdb/sao-scan.gdb
#
# Project:     Hazard3-Doom
# Purpose:     Define a GDB command for scanning the SAO I2C address range
#              through the Hazard3 bridge.
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

# Define a reusable GDB command named sao-scan.
define sao-scan
    # End any transaction left active by an interrupted test.
    set {unsigned int}0x40009000 = 2
    # Start at the first normal 7-bit I2C address; reserved 0x00..0x07 are skipped.
    set $a = 0x08
    # Visit every normal 7-bit I2C address through 0x77.
    while $a <= 0x77
        # Generate an I2C START condition.
        set {unsigned int}0x40009000 = 1
        # Load TXDATA with the 8-bit write address for the current 7-bit address.
        set {unsigned int}0x40009008 = ($a << 1)
        # Transmit the address byte and sample ACK/NACK.
        set {unsigned int}0x40009000 = 3
        # Save bridge STATUS so ACK bit 2 can be tested.
        set $s = *(unsigned int *)0x40009004
        # Report only addresses that asserted ACK.
        if ($s & 4)
            # Print the discovered 7-bit address and complete STATUS value.
            printf "ACK: 0x%02x status=0x%08x\n", $a, $s
        # End the ACK-only output condition.
        end
        # Generate STOP so every probe leaves the bus idle.
        set {unsigned int}0x40009000 = 2
        # Advance to the next 7-bit I2C address.
        set $a = $a + 1
    # End the address scan loop.
    end
# End the reusable sao-scan command definition.
end

# Add GDB help text for the reusable sao-scan command.
document sao-scan
Scan normal 7-bit I2C addresses 0x08..0x77 through the Hazard3 SAO bridge.
Only responding addresses are printed.
end

# Run the scan immediately when this file is sourced; the sao-scan command remains available afterward.
sao-scan
