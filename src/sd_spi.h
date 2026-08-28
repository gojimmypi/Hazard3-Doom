/* -----------------------------------------------------------------------------
 * File:        sd_spi.h
 * Path:        src/sd_spi.h
 *
 * Project:     Hazard3-Doom
 * Purpose:     Declare the Hazard3-Doom SD-card SPI transport interface.
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

#ifndef HAZARD3_SD_SPI_H
#define HAZARD3_SD_SPI_H

#include <stdint.h>

typedef struct hazard3_sd_card {
    uint32_t initialized;
    uint32_t high_capacity;
    uint32_t ocr;
} hazard3_sd_card_t;

int hazard3_sd_init(hazard3_sd_card_t* card);
int hazard3_sd_read_block(const hazard3_sd_card_t* card, uint32_t lba,
    uint8_t* block512);
void hazard3_sd_print_status(const hazard3_sd_card_t* card);

#endif
