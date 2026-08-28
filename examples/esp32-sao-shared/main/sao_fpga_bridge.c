/* -----------------------------------------------------------------------------
 * File:        sao_fpga_bridge.c
 * Path:        examples/esp32-sao-shared/main/sao_fpga_bridge.c
 *
 * Project:     Hazard3-Doom
 * Purpose:     Implement the ESP32 UART client for the FPGA SAO transaction
 *              proxy.
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

#include "sao_fpga_bridge.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "driver/uart.h"
#include "esp_err.h"
#include "freertos/FreeRTOS.h"

#define SAO_UART_PORT       UART_NUM_2
#define SAO_UART_TX_GPIO    17
#define SAO_UART_RX_GPIO    16
#define SAO_UART_BAUD       115200
#define SAO_UART_RX_BUFFER  256
#define SAO_UART_TIMEOUT_MS 250

#define REQ_SYNC0 0xa5u
#define REQ_SYNC1 0x5au
#define RSP_SYNC0 0x5au
#define RSP_SYNC1 0xa5u

#define CMD_INFO    0x01u
#define CMD_RECOVER 0x02u
#define CMD_PROBE   0x03u
#define CMD_READ8   0x04u
#define CMD_WRITE8  0x05u

#define STATUS_OK        0x00u
#define STATUS_NACK      0x01u
#define STATUS_TIMEOUT   0x02u
#define STATUS_BUSY      0x03u
#define STATUS_BAD_CMD   0x04u
#define STATUS_BAD_FRAME 0x05u

#define FRAME_SIZE 7u

typedef struct {
    uint8_t status;
    uint8_t command;
    uint8_t address;
    uint8_t value;
} bridge_response_t;

static uint8_t frame_xor(const uint8_t *data, size_t length)
{
    uint8_t value = 0u;
    size_t i;

    for (i = 0u; i < length; ++i) {
        value ^= data[i];
    }
    return value;
}

static sao_fpga_result_t read_exact(uint8_t *data, size_t length, TickType_t timeout)
{
    TickType_t start = xTaskGetTickCount();
    size_t received = 0u;

    while (received < length) {
        TickType_t elapsed = xTaskGetTickCount() - start;
        TickType_t remaining;
        int count;

        if (elapsed >= timeout) {
            return SAO_FPGA_ERR_UART;
        }
        remaining = timeout - elapsed;
        count = uart_read_bytes(
            SAO_UART_PORT,
            data + received,
            length - received,
            remaining
        );
        if (count < 0) {
            return SAO_FPGA_ERR_UART;
        }
        received += (size_t)count;
    }

    return SAO_FPGA_OK;
}

static sao_fpga_result_t receive_response(
    uint8_t expected_command,
    uint8_t expected_address,
    bridge_response_t *response)
{
    uint8_t frame[FRAME_SIZE];
    uint8_t byte = 0u;
    bool have_sync0 = false;
    TickType_t timeout = pdMS_TO_TICKS(SAO_UART_TIMEOUT_MS);
    TickType_t start = xTaskGetTickCount();

    if (response == NULL) {
        return SAO_FPGA_ERR_ARGUMENT;
    }

    for (;;) {
        TickType_t elapsed = xTaskGetTickCount() - start;
        TickType_t remaining;
        int count;

        if (elapsed >= timeout) {
            return SAO_FPGA_ERR_UART;
        }
        remaining = timeout - elapsed;
        count = uart_read_bytes(SAO_UART_PORT, &byte, 1u, remaining);
        if (count < 0) {
            return SAO_FPGA_ERR_UART;
        }
        if (count == 0) {
            continue;
        }

        if (!have_sync0) {
            have_sync0 = byte == RSP_SYNC0;
            continue;
        }
        if (byte == RSP_SYNC1) {
            frame[0] = RSP_SYNC0;
            frame[1] = RSP_SYNC1;
            break;
        }
        have_sync0 = byte == RSP_SYNC0;
    }

    if (read_exact(&frame[2], FRAME_SIZE - 2u, timeout) != SAO_FPGA_OK) {
        return SAO_FPGA_ERR_UART;
    }
    if (frame_xor(frame, FRAME_SIZE - 1u) != frame[FRAME_SIZE - 1u]) {
        return SAO_FPGA_ERR_BAD_FRAME;
    }
    if (frame[3] != expected_command || frame[4] != expected_address) {
        return SAO_FPGA_ERR_PROTOCOL;
    }

    response->status = frame[2];
    response->command = frame[3];
    response->address = frame[4];
    response->value = frame[5];

    switch (response->status) {
    case STATUS_OK:
        return SAO_FPGA_OK;
    case STATUS_NACK:
        return SAO_FPGA_ERR_NACK;
    case STATUS_TIMEOUT:
        return SAO_FPGA_ERR_TIMEOUT;
    case STATUS_BUSY:
        return SAO_FPGA_ERR_BUSY;
    case STATUS_BAD_CMD:
        return SAO_FPGA_ERR_BAD_COMMAND;
    case STATUS_BAD_FRAME:
        return SAO_FPGA_ERR_BAD_FRAME;
    default:
        return SAO_FPGA_ERR_PROTOCOL;
    }
}

static sao_fpga_result_t transact(
    uint8_t command,
    uint8_t address,
    uint8_t reg,
    uint8_t value,
    bridge_response_t *response)
{
    uint8_t frame[FRAME_SIZE];
    int written;

    frame[0] = REQ_SYNC0;
    frame[1] = REQ_SYNC1;
    frame[2] = command;
    frame[3] = address;
    frame[4] = reg;
    frame[5] = value;
    frame[6] = frame_xor(frame, FRAME_SIZE - 1u);

    written = uart_write_bytes(SAO_UART_PORT, frame, FRAME_SIZE);
    if (written != (int)FRAME_SIZE) {
        return SAO_FPGA_ERR_UART;
    }
    if (uart_wait_tx_done(
            SAO_UART_PORT,
            pdMS_TO_TICKS(SAO_UART_TIMEOUT_MS)) != ESP_OK) {
        return SAO_FPGA_ERR_UART;
    }

    return receive_response(command, address, response);
}

sao_fpga_result_t sao_fpga_bridge_init(void)
{
    const uart_config_t config = {
        .baud_rate = SAO_UART_BAUD,
        .data_bits = UART_DATA_8_BITS,
        .parity = UART_PARITY_DISABLE,
        .stop_bits = UART_STOP_BITS_1,
        .flow_ctrl = UART_HW_FLOWCTRL_DISABLE,
        .rx_flow_ctrl_thresh = 0,
        .source_clk = UART_SCLK_APB,
    };
    esp_err_t err;

    err = uart_driver_install(
        SAO_UART_PORT,
        SAO_UART_RX_BUFFER,
        0,
        0,
        NULL,
        0
    );
    if (err != ESP_OK && err != ESP_ERR_INVALID_STATE) {
        return SAO_FPGA_ERR_UART;
    }
    if (uart_param_config(SAO_UART_PORT, &config) != ESP_OK) {
        return SAO_FPGA_ERR_UART;
    }
    if (uart_set_pin(
            SAO_UART_PORT,
            SAO_UART_TX_GPIO,
            SAO_UART_RX_GPIO,
            UART_PIN_NO_CHANGE,
            UART_PIN_NO_CHANGE) != ESP_OK) {
        return SAO_FPGA_ERR_UART;
    }

    uart_flush_input(SAO_UART_PORT);
    return SAO_FPGA_OK;
}

sao_fpga_result_t sao_fpga_info(uint8_t *protocol_version)
{
    bridge_response_t response;
    sao_fpga_result_t result = transact(CMD_INFO, 0u, 0u, 0u, &response);

    if (result == SAO_FPGA_OK && protocol_version != NULL) {
        *protocol_version = response.value;
    }
    return result;
}

sao_fpga_result_t sao_fpga_recover(void)
{
    bridge_response_t response;
    return transact(CMD_RECOVER, 0u, 0u, 0u, &response);
}

sao_fpga_result_t sao_fpga_probe(uint8_t address)
{
    bridge_response_t response;

    if (address > 0x7fu) {
        return SAO_FPGA_ERR_ARGUMENT;
    }
    return transact(CMD_PROBE, address, 0u, 0u, &response);
}

sao_fpga_result_t sao_fpga_read_reg8(uint8_t address, uint8_t reg, uint8_t *value)
{
    bridge_response_t response;
    sao_fpga_result_t result;

    if (address > 0x7fu || value == NULL) {
        return SAO_FPGA_ERR_ARGUMENT;
    }

    result = transact(CMD_READ8, address, reg, 0u, &response);
    if (result == SAO_FPGA_OK) {
        *value = response.value;
    }
    return result;
}

sao_fpga_result_t sao_fpga_write_reg8(uint8_t address, uint8_t reg, uint8_t value)
{
    bridge_response_t response;

    if (address > 0x7fu) {
        return SAO_FPGA_ERR_ARGUMENT;
    }
    return transact(CMD_WRITE8, address, reg, value, &response);
}

size_t sao_fpga_scan(uint8_t *addresses, size_t capacity)
{
    unsigned int address;
    size_t count = 0u;

    for (address = 0x08u; address <= 0x77u; ++address) {
        if (sao_fpga_probe((uint8_t)address) == SAO_FPGA_OK) {
            if (addresses != NULL && count < capacity) {
                addresses[count] = (uint8_t)address;
            }
            ++count;
        }
    }
    return count;
}

const char *sao_fpga_result_name(sao_fpga_result_t result)
{
    switch (result) {
    case SAO_FPGA_OK:
        return "OK";
    case SAO_FPGA_ERR_NACK:
        return "NACK";
    case SAO_FPGA_ERR_TIMEOUT:
        return "TIMEOUT";
    case SAO_FPGA_ERR_BUSY:
        return "BUSY";
    case SAO_FPGA_ERR_BAD_COMMAND:
        return "BAD_COMMAND";
    case SAO_FPGA_ERR_BAD_FRAME:
        return "BAD_FRAME";
    case SAO_FPGA_ERR_UART:
        return "UART";
    case SAO_FPGA_ERR_ARGUMENT:
        return "ARGUMENT";
    case SAO_FPGA_ERR_PROTOCOL:
        return "PROTOCOL";
    default:
        return "UNKNOWN";
    }
}
