# -----------------------------------------------------------------------------
# File:        CMakeLists.txt
# Path:        examples/esp32-sao-shared/CMakeLists.txt
#
# Project:     Hazard3-Doom
# Purpose:     Define the ESP-IDF project build for the shared ULX3S ESP32/FPGA
#              SAO example.
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

cmake_minimum_required(VERSION 3.16)

include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(ulx3s_sao_shared)
