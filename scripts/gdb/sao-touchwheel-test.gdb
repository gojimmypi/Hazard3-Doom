# -----------------------------------------------------------------------------
# File:        sao-touchwheel-test.gdb
# Path:        scripts/gdb/sao-touchwheel-test.gdb
#
# Project:     Hazard3-Doom
# Purpose:     Exercise TouchwheelSAO reads, writes, and status LED control
#              through the Hazard3 bridge from GDB.
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

# This test targets the TouchwheelSAO at 7-bit I2C address 0x54.
# It reads register 0x00 (touch position), writes register 0x0e (status LED) to 1,
# reads register 0x0e back, and leaves the status LED on as a visible write test.

# End any transaction left active by an interrupted test.
set {unsigned int}0x40009000 = 2
# Generate START for the register-position write phase of the read transaction.
set {unsigned int}0x40009000 = 1
# Load the TouchwheelSAO write address: 0x54 << 1 = 0xa8.
set {unsigned int}0x40009008 = 0xa8
# Transmit the write address and require the TouchwheelSAO to ACK.
set {unsigned int}0x40009000 = 3
# Save STATUS after the device address.
set $s = *(unsigned int *)0x40009004
# Print the address-phase STATUS for diagnostics.
printf "read position: address status=0x%08x\n", $s
# Select register 0x00, the TouchwheelSAO touch-position register.
set {unsigned int}0x40009008 = 0x00
# Transmit the register index.
set {unsigned int}0x40009000 = 3
# Generate a repeated START before changing to read direction.
set {unsigned int}0x40009000 = 1
# Load the TouchwheelSAO read address: (0x54 << 1) | 1 = 0xa9.
set {unsigned int}0x40009008 = 0xa9
# Transmit the read address.
set {unsigned int}0x40009000 = 3
# Read one byte and finish that byte with NACK because no additional bytes are requested.
set {unsigned int}0x40009000 = 5
# Capture RXDATA low byte as the current touch position.
set $position = (*(unsigned int *)0x4000900c) & 0xff
# Print touch position; 0 means no touch and 1..255 represents angular position.
printf "Touchwheel position register 0x00 = 0x%02x (%u)\n", $position, $position
# Generate STOP to finish the register read transaction.
set {unsigned int}0x40009000 = 2

# Generate START for a visible register-write test.
set {unsigned int}0x40009000 = 1
# Load the TouchwheelSAO write address 0xa8.
set {unsigned int}0x40009008 = 0xa8
# Transmit the write address.
set {unsigned int}0x40009000 = 3
# Select register 0x0e, which controls the TouchwheelSAO status LED.
set {unsigned int}0x40009008 = 0x0e
# Transmit the status-LED register index.
set {unsigned int}0x40009000 = 3
# Load value 1 to turn the status LED on.
set {unsigned int}0x40009008 = 0x01
# Transmit the new register value.
set {unsigned int}0x40009000 = 3
# Save STATUS after the data byte so the write ACK can be seen.
set $s = *(unsigned int *)0x40009004
# Print the final write STATUS; ACK bit 2 should be set.
printf "write status LED=1: status=0x%08x\n", $s
# Generate STOP to commit/end the write transaction.
set {unsigned int}0x40009000 = 2

# Generate START to read register 0x0e back for verification.
set {unsigned int}0x40009000 = 1
# Load the TouchwheelSAO write address so its current register can be selected.
set {unsigned int}0x40009008 = 0xa8
# Transmit the write address.
set {unsigned int}0x40009000 = 3
# Select register 0x0e again.
set {unsigned int}0x40009008 = 0x0e
# Transmit the register index.
set {unsigned int}0x40009000 = 3
# Generate repeated START for the read phase.
set {unsigned int}0x40009000 = 1
# Load the TouchwheelSAO read address 0xa9.
set {unsigned int}0x40009008 = 0xa9
# Transmit the read address.
set {unsigned int}0x40009000 = 3
# Read the single register byte and finish it with NACK.
set {unsigned int}0x40009000 = 5
# Capture RXDATA low byte as the status-LED register readback.
set $led_status = (*(unsigned int *)0x4000900c) & 0xff
# Print the readback; expected value is 0x01.
printf "Touchwheel status LED register 0x0e readback = 0x%02x\n", $led_status
# Generate STOP and return the I2C bus to idle.
set {unsigned int}0x40009000 = 2
# Read the physical line state after the complete test.
set $lines = *(unsigned int *)0x4000901c
# Print final line state; 0x0000000f is the expected idle value in this setup.
printf "final lines=0x%08x\n", $lines
