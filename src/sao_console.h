/* SPDX-License-Identifier: Apache-2.0 */
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
