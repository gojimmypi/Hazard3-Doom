/* -----------------------------------------------------------------------------
 * File:        sao_console.h
 * Path:        src/sao_console.h
 *
 * Project:     Hazard3-Doom
 * Purpose:     Declare the resident monitor SAO console command interface.
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

#ifndef HAZARD3_SAO_CONSOLE_H
#define HAZARD3_SAO_CONSOLE_H

#include <stdint.h>

#define HAZARD3_SAO_CONSOLE_NOT_CONSUMED 0
#define HAZARD3_SAO_CONSOLE_CONSUMED     1
#define HAZARD3_SAO_CONSOLE_STATUS       2

typedef void (*hazard3_sao_console_putc_fn)(uint8_t value);
typedef void (*hazard3_sao_console_puts_fn)(const char* text);

void hazard3_sao_console_init(
    hazard3_sao_console_putc_fn putc_fn,
    hazard3_sao_console_puts_fn puts_fn,
    uint32_t sys_clk_hz);

void hazard3_sao_console_print_help(void);
int hazard3_sao_console_feed(uint8_t received);

#endif
