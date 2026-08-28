/* -----------------------------------------------------------------------------
 * File:        hazard3_sao.c
 * Path:        doom/hazard3_sao.c
 *
 * Project:     Hazard3-Doom
 * Purpose:     Implement the shared Hazard3 SAO peripheral register interface.
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

#include "hazard3_sao.h"

#define REG32(offset) \
    (*(volatile uint32_t*)(uintptr_t)(HAZARD3_SAO_REG_BASE + (offset)))

#define SAO_COMMAND REG32(0x00u)
#define SAO_STATUS  REG32(0x04u)
#define SAO_TXDATA  REG32(0x08u)
#define SAO_RXDATA  REG32(0x0cu)
#define SAO_CLKDIV  REG32(0x10u)
#define SAO_TIMEOUT REG32(0x14u)
#define SAO_GPIO    REG32(0x18u)
#define SAO_ID      REG32(0x20u)
#define SAO_VERSION REG32(0x24u)

#define SAO_CMD_START     1u
#define SAO_CMD_STOP      2u
#define SAO_CMD_WRITE     3u
#define SAO_CMD_READ_ACK  4u
#define SAO_CMD_READ_NACK 5u
#define SAO_CMD_RECOVER   6u
#define SAO_CMD_ABORT     7u

#define SAO_SOFTWARE_SPIN_LIMIT 4000000u

static int sao_wait_done(uint32_t* status_out)
{
    uint32_t status = 0u;
    uint32_t spins = SAO_SOFTWARE_SPIN_LIMIT;

    while (spins-- != 0u) {
        status = SAO_STATUS;
        if ((status & HAZARD3_SAO_STATUS_REJECTED) != 0u) {
            return HAZARD3_SAO_ERR_REJECTED;
        }
        if ((status & HAZARD3_SAO_STATUS_BUSY) == 0u &&
            (status & HAZARD3_SAO_STATUS_DONE) != 0u) {
            if (status_out != NULL) {
                *status_out = status;
            }
            if ((status & HAZARD3_SAO_STATUS_TIMEOUT) != 0u) {
                return HAZARD3_SAO_ERR_TIMEOUT;
            }
            return HAZARD3_SAO_OK;
        }
    }

    SAO_COMMAND = SAO_CMD_ABORT;
    return HAZARD3_SAO_ERR_TIMEOUT;
}

static int sao_command(uint32_t command, uint32_t* status_out)
{
    SAO_COMMAND = command;
    return sao_wait_done(status_out);
}

static int sao_start(void)
{
    return sao_command(SAO_CMD_START, NULL);
}

static int sao_stop(void)
{
    return sao_command(SAO_CMD_STOP, NULL);
}

static int sao_write_byte(uint8_t value)
{
    uint32_t status;
    int rc;

    SAO_TXDATA = value;
    rc = sao_command(SAO_CMD_WRITE, &status);
    if (rc != HAZARD3_SAO_OK) {
        return rc;
    }
    return (status & HAZARD3_SAO_STATUS_ACK) != 0u
        ? HAZARD3_SAO_OK : HAZARD3_SAO_ERR_NACK;
}

static int sao_read_byte(uint8_t* value, bool ack)
{
    int rc;

    if (value == NULL) {
        return HAZARD3_SAO_ERR_ARGUMENT;
    }

    rc = sao_command(ack ? SAO_CMD_READ_ACK : SAO_CMD_READ_NACK, NULL);
    if (rc == HAZARD3_SAO_OK) {
        *value = (uint8_t)SAO_RXDATA;
    }
    return rc;
}

uint32_t hazard3_sao_bridge_id(void)
{
    return SAO_ID;
}

uint32_t hazard3_sao_bridge_version(void)
{
    return SAO_VERSION;
}

void hazard3_sao_init(uint32_t sys_clk_hz, uint32_t i2c_hz)
{
    uint32_t divider;

    if (sys_clk_hz == 0u) {
        sys_clk_hz = 50000000u;
    }
    if (i2c_hz == 0u) {
        i2c_hz = 100000u;
    }

    divider = sys_clk_hz / (2u * i2c_hz);
    if (divider == 0u) {
        divider = 1u;
    } else if (divider > 0xffffu) {
        divider = 0xffffu;
    }

    SAO_CLKDIV = divider;
    SAO_TIMEOUT = sys_clk_hz / 100u; // 10 ms clock-stretch/bus timeout
    SAO_GPIO = 0u;
}

uint32_t hazard3_sao_status(void)
{
    return SAO_STATUS;
}

int hazard3_sao_recover(void)
{
    uint32_t status;
    int rc = sao_command(SAO_CMD_RECOVER, &status);

    if (rc != HAZARD3_SAO_OK) {
        return rc;
    }
    return (status & HAZARD3_SAO_STATUS_RECOVERED) != 0u
        ? HAZARD3_SAO_OK : HAZARD3_SAO_ERR_TIMEOUT;
}

int hazard3_sao_probe(uint8_t address)
{
    int rc;
    int stop_rc;

    if (address > 0x7fu) {
        return HAZARD3_SAO_ERR_ARGUMENT;
    }

    rc = sao_start();
    if (rc != HAZARD3_SAO_OK) {
        return rc;
    }

    rc = sao_write_byte((uint8_t)(address << 1));
    stop_rc = sao_stop();
    return rc == HAZARD3_SAO_OK ? stop_rc : rc;
}

size_t hazard3_sao_scan(uint8_t* addresses, size_t capacity)
{
    unsigned int address;
    size_t count = 0u;

    for (address = 0x08u; address <= 0x77u; ++address) {
        if (hazard3_sao_probe((uint8_t)address) == HAZARD3_SAO_OK) {
            if (addresses != NULL && count < capacity) {
                addresses[count] = (uint8_t)address;
            }
            ++count;
        }
    }
    return count;
}

int hazard3_sao_write(uint8_t address, const uint8_t* data, size_t length)
{
    size_t i;
    int rc;
    int stop_rc;

    if (address > 0x7fu || (length != 0u && data == NULL)) {
        return HAZARD3_SAO_ERR_ARGUMENT;
    }

    rc = sao_start();
    if (rc != HAZARD3_SAO_OK) {
        return rc;
    }

    rc = sao_write_byte((uint8_t)(address << 1));
    for (i = 0u; rc == HAZARD3_SAO_OK && i < length; ++i) {
        rc = sao_write_byte(data[i]);
    }

    stop_rc = sao_stop();
    return rc == HAZARD3_SAO_OK ? stop_rc : rc;
}

int hazard3_sao_read(uint8_t address, uint8_t* data, size_t length)
{
    size_t i;
    int rc;
    int stop_rc;

    if (address > 0x7fu || (length != 0u && data == NULL)) {
        return HAZARD3_SAO_ERR_ARGUMENT;
    }

    rc = sao_start();
    if (rc != HAZARD3_SAO_OK) {
        return rc;
    }

    rc = sao_write_byte((uint8_t)((address << 1) | 1u));
    for (i = 0u; rc == HAZARD3_SAO_OK && i < length; ++i) {
        rc = sao_read_byte(&data[i], i + 1u < length);
    }

    stop_rc = sao_stop();
    return rc == HAZARD3_SAO_OK ? stop_rc : rc;
}

int hazard3_sao_write_reg8(uint8_t address, uint8_t reg, uint8_t value)
{
    const uint8_t payload[2] = {reg, value};
    return hazard3_sao_write(address, payload, sizeof(payload));
}

int hazard3_sao_read_reg8(uint8_t address, uint8_t reg, uint8_t* value)
{
    int rc;
    int stop_rc;

    if (value == NULL || address > 0x7fu) {
        return HAZARD3_SAO_ERR_ARGUMENT;
    }

    rc = sao_start();
    if (rc != HAZARD3_SAO_OK) {
        return rc;
    }

    rc = sao_write_byte((uint8_t)(address << 1));
    if (rc == HAZARD3_SAO_OK) {
        rc = sao_write_byte(reg);
    }
    if (rc == HAZARD3_SAO_OK) {
        rc = sao_start();
    }
    if (rc == HAZARD3_SAO_OK) {
        rc = sao_write_byte((uint8_t)((address << 1) | 1u));
    }
    if (rc == HAZARD3_SAO_OK) {
        rc = sao_read_byte(value, false);
    }

    stop_rc = sao_stop();
    return rc == HAZARD3_SAO_OK ? stop_rc : rc;
}

void hazard3_sao_gpio_config(unsigned int gpio, bool output)
{
    uint32_t control = SAO_GPIO;

    if (gpio == 1u) {
        control = output ? control | (1u << 1) : control & ~(1u << 1);
    } else if (gpio == 2u) {
        control = output ? control | (1u << 3) : control & ~(1u << 3);
    }
    SAO_GPIO = control;
}

void hazard3_sao_gpio_write(unsigned int gpio, bool value)
{
    uint32_t control = SAO_GPIO;

    if (gpio == 1u) {
        control = value ? control | (1u << 0) : control & ~(1u << 0);
    } else if (gpio == 2u) {
        control = value ? control | (1u << 2) : control & ~(1u << 2);
    }
    SAO_GPIO = control;
}

bool hazard3_sao_gpio_read(unsigned int gpio)
{
    uint32_t status = SAO_STATUS;

    if (gpio == 1u) {
        return (status & HAZARD3_SAO_STATUS_GPIO1_IN) != 0u;
    }
    if (gpio == 2u) {
        return (status & HAZARD3_SAO_STATUS_GPIO2_IN) != 0u;
    }
    return false;
}
