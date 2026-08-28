/* -----------------------------------------------------------------------------
 * File:        sd_spi.c
 * Path:        src/sd_spi.c
 *
 * Project:     Hazard3-Doom
 * Purpose:     Implement the resident monitor SD-card SPI transport and block-
 *              read operations.
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

#include <stdint.h>

#include "sd_spi.h"
#include "doom/hazard3_platform.h"

#define SD_SPI_BASE        0x4000a000u
#define SD_SPI_CTRL        (*(volatile uint32_t *)(SD_SPI_BASE + 0x00u))
#define SD_SPI_CLKDIV      (*(volatile uint32_t *)(SD_SPI_BASE + 0x04u))
#define SD_SPI_DATA        (*(volatile uint32_t *)(SD_SPI_BASE + 0x08u))
#define SD_SPI_STATUS      (*(volatile uint32_t *)(SD_SPI_BASE + 0x0cu))

#define SD_SPI_STATUS_BUSY (1u << 0)
#define SD_SPI_CS_HIGH     1u
#define SD_SPI_CS_LOW      0u
#define SD_SPI_SLOW_DIV    124u
#define SD_SPI_FAST_DIV    1u

#define SD_CMD0            0u
#define SD_CMD8            8u
#define SD_CMD16           16u
#define SD_CMD17           17u
#define SD_CMD41           41u
#define SD_CMD55           55u
#define SD_CMD58           58u

#define SD_R1_IDLE         0x01u
#define SD_R1_ILLEGAL      0x04u
#define SD_DATA_TOKEN      0xfeu
#define SD_TIMEOUT_MS      1500u
#define SD_TOKEN_TIMEOUT_MS 500u

static uint8_t spi_transfer(uint8_t value)
{
    while ((SD_SPI_STATUS & SD_SPI_STATUS_BUSY) != 0u) {
    }
    SD_SPI_DATA = value;
    while ((SD_SPI_STATUS & SD_SPI_STATUS_BUSY) != 0u) {
    }
    return (uint8_t)SD_SPI_DATA;
}

static void deselect_card(void)
{
    SD_SPI_CTRL = SD_SPI_CS_HIGH;
    (void)spi_transfer(0xffu);
}

static void select_card(void)
{
    SD_SPI_CTRL = SD_SPI_CS_LOW;
}

static uint8_t command_crc(uint8_t command)
{
    if (command == SD_CMD0) {
        return 0x95u;
    }
    if (command == SD_CMD8) {
        return 0x87u;
    }
    return 0x01u;
}

static uint8_t command_begin(uint8_t command, uint32_t argument)
{
    uint8_t response = 0xffu;

    select_card();
    (void)spi_transfer(0xffu);
    (void)spi_transfer((uint8_t)(0x40u | command));
    (void)spi_transfer((uint8_t)(argument >> 24));
    (void)spi_transfer((uint8_t)(argument >> 16));
    (void)spi_transfer((uint8_t)(argument >> 8));
    (void)spi_transfer((uint8_t)argument);
    (void)spi_transfer(command_crc(command));

    for (uint32_t i = 0u; i < 16u; ++i) {
        response = spi_transfer(0xffu);
        if ((response & 0x80u) == 0u) {
            break;
        }
    }
    return response;
}

static uint8_t command_simple(uint8_t command, uint32_t argument)
{
    uint8_t response = command_begin(command, argument);
    deselect_card();
    return response;
}

static uint32_t read_be32(void)
{
    uint32_t value = (uint32_t)spi_transfer(0xffu) << 24;
    value |= (uint32_t)spi_transfer(0xffu) << 16;
    value |= (uint32_t)spi_transfer(0xffu) << 8;
    value |= (uint32_t)spi_transfer(0xffu);
    return value;
}

int hazard3_sd_init(hazard3_sd_card_t* card)
{
    uint32_t start;
    uint8_t response;
    uint32_t r7 = 0u;
    uint32_t ocr;
    int version2 = 0;

    if (card == (hazard3_sd_card_t*)0) {
        return 0;
    }

    card->initialized = 0u;
    card->high_capacity = 0u;
    card->ocr = 0u;

    SD_SPI_CTRL = SD_SPI_CS_HIGH;
    SD_SPI_CLKDIV = SD_SPI_SLOW_DIV;
    for (uint32_t i = 0u; i < 10u; ++i) {
        (void)spi_transfer(0xffu);
    }

    start = hazard3_ticks_ms();
    do {
        response = command_simple(SD_CMD0, 0u);
        if (response == SD_R1_IDLE) {
            break;
        }
    } while ((uint32_t)(hazard3_ticks_ms() - start) < SD_TIMEOUT_MS);

    if (response != SD_R1_IDLE) {
        hazard3_console_puts("SD: CMD0 failed r1=");
        hazard3_console_put_hex32(response);
        hazard3_console_puts("\r\n");
        return 0;
    }

    response = command_begin(SD_CMD8, 0x000001aau);
    if (response == SD_R1_IDLE) {
        r7 = read_be32();
        version2 = (r7 & 0xfffu) == 0x1aau;
    } else if ((response & SD_R1_ILLEGAL) != 0u) {
        version2 = 0;
    } else {
        deselect_card();
        hazard3_console_puts("SD: CMD8 failed r1=");
        hazard3_console_put_hex32(response);
        hazard3_console_puts("\r\n");
        return 0;
    }
    deselect_card();

    start = hazard3_ticks_ms();
    for (;;) {
        response = command_simple(SD_CMD55, 0u);
        if (response > SD_R1_IDLE) {
            break;
        }
        response = command_simple(SD_CMD41,
            version2 ? 0x40000000u : 0u);
        if (response == 0u) {
            break;
        }
        if ((uint32_t)(hazard3_ticks_ms() - start) >= SD_TIMEOUT_MS) {
            break;
        }
    }
    if (response != 0u) {
        hazard3_console_puts("SD: ACMD41 failed r1=");
        hazard3_console_put_hex32(response);
        hazard3_console_puts("\r\n");
        return 0;
    }

    response = command_begin(SD_CMD58, 0u);
    if (response != 0u) {
        deselect_card();
        hazard3_console_puts("SD: CMD58 failed r1=");
        hazard3_console_put_hex32(response);
        hazard3_console_puts("\r\n");
        return 0;
    }
    ocr = read_be32();
    deselect_card();

    card->ocr = ocr;
    card->high_capacity = (version2 && (ocr & 0x40000000u) != 0u) ? 1u : 0u;

    if (card->high_capacity == 0u) {
        response = command_simple(SD_CMD16, 512u);
        if (response != 0u) {
            hazard3_console_puts("SD: CMD16 failed r1=");
            hazard3_console_put_hex32(response);
            hazard3_console_puts("\r\n");
            return 0;
        }
    }

    SD_SPI_CLKDIV = SD_SPI_FAST_DIV;
    card->initialized = 1u;
    return 1;
}

int hazard3_sd_read_block(const hazard3_sd_card_t* card, uint32_t lba,
    uint8_t* block512)
{
    uint32_t argument;
    uint32_t start;
    uint8_t response;
    uint8_t token = 0xffu;

    if (card == (const hazard3_sd_card_t*)0 || block512 == (uint8_t*)0 ||
        card->initialized == 0u) {
        return 0;
    }

    argument = card->high_capacity != 0u ? lba : lba * 512u;
    response = command_begin(SD_CMD17, argument);
    if (response != 0u) {
        deselect_card();
        return 0;
    }

    start = hazard3_ticks_ms();
    do {
        token = spi_transfer(0xffu);
        if (token == SD_DATA_TOKEN) {
            break;
        }
    } while ((uint32_t)(hazard3_ticks_ms() - start) < SD_TOKEN_TIMEOUT_MS);

    if (token != SD_DATA_TOKEN) {
        deselect_card();
        return 0;
    }

    for (uint32_t i = 0u; i < 512u; ++i) {
        block512[i] = spi_transfer(0xffu);
    }
    (void)spi_transfer(0xffu);
    (void)spi_transfer(0xffu);
    deselect_card();
    return 1;
}

void hazard3_sd_print_status(const hazard3_sd_card_t* card)
{
    hazard3_console_puts("sd_initialized=");
    hazard3_console_puts(card != (const hazard3_sd_card_t*)0 &&
        card->initialized != 0u ? "YES" : "NO");
    if (card != (const hazard3_sd_card_t*)0) {
        hazard3_console_puts(" type=");
        hazard3_console_puts(card->high_capacity != 0u ? "SDHC/SDXC" : "SDSC");
        hazard3_console_puts(" ocr=");
        hazard3_console_put_hex32(card->ocr);
    }
    hazard3_console_puts("\r\n");
}
