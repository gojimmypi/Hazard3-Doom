/* -----------------------------------------------------------------------------
 * File:        hazard3_monitor_services.h
 * Path:        doom/hazard3_monitor_services.h
 *
 * Project:     Hazard3-Doom
 * Purpose:     Define the monitor-to-image ABI used by separately loaded
 *              Hazard3-Doom applications.
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

#ifndef HAZARD3_MONITOR_SERVICES_H
#define HAZARD3_MONITOR_SERVICES_H

#include <stddef.h>
#include <stdint.h>

#define HAZARD3_MONITOR_ABI_VERSION 3u

typedef struct hazard3_monitor_services {
    uint32_t abi_version;
    uint32_t struct_bytes;
    void (*console_putc)(uint8_t value);
    void (*console_puts)(const char* text);
    void (*console_put_hex32)(uint32_t value);
    int (*console_getc_nonblocking)(uint8_t* value);
    uint32_t (*ticks_ms)(void);
    void (*sleep_ms)(uint32_t milliseconds);
    void* (*sbrk)(ptrdiff_t increment);
    void (*memory_barrier)(void);
    uint32_t image_base;
    uint32_t image_limit;
    uint32_t heap_base;
    uint32_t heap_limit;
    uint32_t video_base;
    uint32_t video_limit;
    uint32_t wad_base;
    uint32_t wad_limit;
    uint32_t wad_bytes;
    const char* wad_name;
    uint32_t screen_base;
    uint32_t screen_bytes;
} hazard3_monitor_services_t;

#endif
