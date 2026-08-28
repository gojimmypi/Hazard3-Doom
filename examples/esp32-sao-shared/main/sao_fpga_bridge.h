/* -----------------------------------------------------------------------------
 * File:        sao_fpga_bridge.h
 * Path:        examples/esp32-sao-shared/main/sao_fpga_bridge.h
 *
 * Project:     Hazard3-Doom
 * Purpose:     Declare the ESP32-to-FPGA SAO proxy protocol and client API.
 *
 * Copyright (c) 2026 gojimmypi
 *
 * Licensed under the Apache License, Version 2.0.
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * This software is provided under the terms of the applicable license.
 * See LICENSES/Apache-2.0.txt for the complete license terms.
 * See LICENSING.md for project licensing policy and scope.
 * -------------------------------------------------------------------------- */

#ifndef SAO_FPGA_BRIDGE_H
#define SAO_FPGA_BRIDGE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define SAO_FPGA_PROTOCOL_VERSION 0x21u

typedef enum {
    SAO_FPGA_OK = 0,
    SAO_FPGA_ERR_NACK = -1,
    SAO_FPGA_ERR_TIMEOUT = -2,
    SAO_FPGA_ERR_BUSY = -3,
    SAO_FPGA_ERR_BAD_COMMAND = -4,
    SAO_FPGA_ERR_BAD_FRAME = -5,
    SAO_FPGA_ERR_UART = -6,
    SAO_FPGA_ERR_ARGUMENT = -7,
    SAO_FPGA_ERR_PROTOCOL = -8
} sao_fpga_result_t;

sao_fpga_result_t sao_fpga_bridge_init(void);
sao_fpga_result_t sao_fpga_info(uint8_t *protocol_version);
sao_fpga_result_t sao_fpga_recover(void);
sao_fpga_result_t sao_fpga_probe(uint8_t address);
sao_fpga_result_t sao_fpga_read_reg8(uint8_t address, uint8_t reg, uint8_t *value);
sao_fpga_result_t sao_fpga_write_reg8(uint8_t address, uint8_t reg, uint8_t value);
size_t sao_fpga_scan(uint8_t *addresses, size_t capacity);
const char *sao_fpga_result_name(sao_fpga_result_t result);

#ifdef __cplusplus
}
#endif

#endif
