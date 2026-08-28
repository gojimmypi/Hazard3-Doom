/* -----------------------------------------------------------------------------
 * File:        main.c
 * Path:        examples/esp32-sao-shared/main/main.c
 *
 * Project:     Hazard3-Doom
 * Purpose:     Demonstrate ESP32 access to the ULX3S SAO bus through the FPGA
 *              transaction proxy.
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

#include <inttypes.h>
#include <stddef.h>
#include <stdint.h>

#include "driver/gpio.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#include "sao_fpga_bridge.h"

static const char *TAG = "sao_shared";

#define TOUCHWHEEL_ADDRESS 0x54u
#define TOUCHWHEEL_POSITION_REG 0x00u
#define TOUCHWHEEL_STATUS_LED_REG 0x0eu


static void release_sd_socket_pins(void)
{
    const gpio_config_t config = {
        .pin_bit_mask = (1ULL << GPIO_NUM_2) |
            (1ULL << GPIO_NUM_13) |
            (1ULL << GPIO_NUM_14) |
            (1ULL << GPIO_NUM_15),
        .mode = GPIO_MODE_INPUT,
        .pull_up_en = GPIO_PULLUP_DISABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_DISABLE,
    };

    /*
     * ULX3S connects the onboard micro-SD socket to both the FPGA and these
     * ESP32 GPIOs. Hazard3 owns the card in the combined FPGA image, so the
     * ESP32 must not electrically drive CLK/CMD/D0/D3.
     */
    ESP_ERROR_CHECK(gpio_config(&config));
}

static void log_result(const char *operation, sao_fpga_result_t result)
{
    if (result == SAO_FPGA_OK) {
        ESP_LOGI(TAG, "%s: OK", operation);
    } else {
        ESP_LOGE(TAG, "%s: %s (%d)", operation,
                 sao_fpga_result_name(result), (int)result);
    }
}

void app_main(void)
{
    uint8_t protocol_version = 0u;
    uint8_t position = 0u;
    uint8_t led_value = 0u;
    uint8_t addresses[16];
    size_t count;
    size_t i;
    sao_fpga_result_t result;

    release_sd_socket_pins();

    result = sao_fpga_bridge_init();
    if (result != SAO_FPGA_OK) {
        log_result("bridge init", result);
        return;
    }

    /*
     * The ESP32 is often flashed while an FPGA passthrough image is loaded.
     * Wait until the shared-SAO FPGA image is configured rather than assuming
     * it is already present when the ESP32 application starts.
     */
    for (;;) {
        result = sao_fpga_info(&protocol_version);
        if (result == SAO_FPGA_OK) {
            break;
        }
        vTaskDelay(pdMS_TO_TICKS(250));
    }

    ESP_LOGI(TAG, "FPGA SAO UART protocol %u.%u",
             (unsigned)(protocol_version >> 4),
             (unsigned)(protocol_version & 0x0fu));

    result = sao_fpga_recover();
    log_result("I2C recover", result);

    ESP_LOGI(TAG, "Scanning SAO I2C bus...");
    count = sao_fpga_scan(addresses, sizeof(addresses));
    ESP_LOGI(TAG, "%u device(s) found", (unsigned)count);
    for (i = 0u; i < count && i < sizeof(addresses); ++i) {
        ESP_LOGI(TAG, "  ACK 0x%02X", addresses[i]);
    }

    result = sao_fpga_read_reg8(
        TOUCHWHEEL_ADDRESS,
        TOUCHWHEEL_POSITION_REG,
        &position
    );
    if (result == SAO_FPGA_OK) {
        ESP_LOGI(TAG, "Touchwheel position: 0x%02X (%u)",
                 position, (unsigned)position);
    } else {
        log_result("Touchwheel position read", result);
        return;
    }

    /* Same visible write/readback test already used from Hazard3/GDB. */
    result = sao_fpga_write_reg8(
        TOUCHWHEEL_ADDRESS,
        TOUCHWHEEL_STATUS_LED_REG,
        0x01u
    );
    log_result("Touchwheel status LED on", result);
    if (result == SAO_FPGA_OK) {
        result = sao_fpga_read_reg8(
            TOUCHWHEEL_ADDRESS,
            TOUCHWHEEL_STATUS_LED_REG,
            &led_value
        );
        if (result == SAO_FPGA_OK) {
            ESP_LOGI(TAG, "Touchwheel LED readback: 0x%02X", led_value);
        } else {
            log_result("Touchwheel LED readback", result);
        }
    }

    vTaskDelay(pdMS_TO_TICKS(1000));

    /* Restore the LED to off before leaving the example. */
    result = sao_fpga_write_reg8(
        TOUCHWHEEL_ADDRESS,
        TOUCHWHEEL_STATUS_LED_REG,
        0x00u
    );
    log_result("Touchwheel status LED off", result);
}
