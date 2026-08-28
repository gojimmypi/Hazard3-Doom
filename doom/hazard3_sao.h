/* -----------------------------------------------------------------------------
 * File:        hazard3_sao.h
 * Path:        doom/hazard3_sao.h
 *
 * Project:     Hazard3-Doom
 * Purpose:     Define the shared Hazard3 SAO peripheral register interface and
 *              operations.
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

#ifndef HAZARD3_SAO_H
#define HAZARD3_SAO_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define HAZARD3_SAO_REG_BASE 0x40009000u
#define HAZARD3_SAO_BRIDGE_ID 0x53414f31u

#define HAZARD3_SAO_STATUS_BUSY       (1u << 0)
#define HAZARD3_SAO_STATUS_DONE       (1u << 1)
#define HAZARD3_SAO_STATUS_ACK        (1u << 2)
#define HAZARD3_SAO_STATUS_NACK       (1u << 3)
#define HAZARD3_SAO_STATUS_TIMEOUT    (1u << 4)
#define HAZARD3_SAO_STATUS_REJECTED   (1u << 5)
#define HAZARD3_SAO_STATUS_BUS_ACTIVE (1u << 6)
#define HAZARD3_SAO_STATUS_SDA        (1u << 7)
#define HAZARD3_SAO_STATUS_SCL        (1u << 8)
#define HAZARD3_SAO_STATUS_GPIO1_IN   (1u << 9)
#define HAZARD3_SAO_STATUS_GPIO2_IN   (1u << 10)
#define HAZARD3_SAO_STATUS_RECOVERED  (1u << 11)

enum hazard3_sao_result {
    HAZARD3_SAO_OK = 0,
    HAZARD3_SAO_ERR_TIMEOUT = -1,
    HAZARD3_SAO_ERR_NACK = -2,
    HAZARD3_SAO_ERR_REJECTED = -3,
    HAZARD3_SAO_ERR_ARGUMENT = -4
};

uint32_t hazard3_sao_bridge_id(void);
uint32_t hazard3_sao_bridge_version(void);
void hazard3_sao_init(uint32_t sys_clk_hz, uint32_t i2c_hz);
uint32_t hazard3_sao_status(void);
int hazard3_sao_recover(void);
int hazard3_sao_probe(uint8_t address);
size_t hazard3_sao_scan(uint8_t* addresses, size_t capacity);
int hazard3_sao_write(uint8_t address, const uint8_t* data, size_t length);
int hazard3_sao_read(uint8_t address, uint8_t* data, size_t length);
int hazard3_sao_write_reg8(uint8_t address, uint8_t reg, uint8_t value);
int hazard3_sao_read_reg8(uint8_t address, uint8_t reg, uint8_t* value);
void hazard3_sao_gpio_config(unsigned int gpio, bool output);
void hazard3_sao_gpio_write(unsigned int gpio, bool value);
bool hazard3_sao_gpio_read(unsigned int gpio);

#endif
