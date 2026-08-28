# -----------------------------------------------------------------------------
# File:        sao-touchwheel-led-off.gdb
# Path:        scripts/gdb/sao-touchwheel-led-off.gdb
#
# Project:     Hazard3-Doom
# Purpose:     Turn off the TouchwheelSAO status LED through the Hazard3 SAO
#              bridge from GDB.
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

# End any transaction left active by an interrupted test.
set {unsigned int}0x40009000 = 2
# Generate START for the TouchwheelSAO register write.
set {unsigned int}0x40009000 = 1
# Load the TouchwheelSAO write address 0xa8.
set {unsigned int}0x40009008 = 0xa8
# Transmit the device address.
set {unsigned int}0x40009000 = 3
# Select status-LED register 0x0e.
set {unsigned int}0x40009008 = 0x0e
# Transmit the register index.
set {unsigned int}0x40009000 = 3
# Load zero to turn the status LED off.
set {unsigned int}0x40009008 = 0x00
# Transmit the zero value.
set {unsigned int}0x40009000 = 3
# Read STATUS so ACK/NACK of the data byte is visible.
x/wx 0x40009004
# Generate STOP and release the bus.
set {unsigned int}0x40009000 = 2
# Read physical line state after STOP.
x/wx 0x4000901c
