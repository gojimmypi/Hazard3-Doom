# -----------------------------------------------------------------------------
# File:        CMakeLists.txt
# Path:        examples/esp32-sao-shared/main/CMakeLists.txt
#
# Project:     Hazard3-Doom
# Purpose:     Register the ESP32 SAO example application sources with ESP-IDF.
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

idf_component_register(
    SRCS
        "main.c"
        "sao_fpga_bridge.c"
    INCLUDE_DIRS
        "."
    PRIV_REQUIRES
        esp_driver_gpio
        esp_driver_uart
)
