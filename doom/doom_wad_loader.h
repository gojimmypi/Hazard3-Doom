/* -----------------------------------------------------------------------------
 * File:        doom_wad_loader.h
 * Path:        doom/doom_wad_loader.h
 *
 * Project:     Hazard3-Doom
 * Purpose:     Declare the resident monitor interface for Doom IWAD loading and
 *              status.
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

#ifndef DOOM_WAD_LOADER_H
#define DOOM_WAD_LOADER_H

#include <stdint.h>

typedef int (*doom_wad_stream_read_fn)(void* context, void* buffer,
    uint32_t byte_count);

int doom_wad_loader_receive(void);
int doom_wad_loader_load_raw_stream(const char* file_name, uint32_t wad_bytes,
    doom_wad_stream_read_fn read_fn, void* context);
void doom_wad_loader_invalidate(void);
void doom_wad_loader_print_status(void);
int doom_wad_loader_is_loaded(void);
uint32_t doom_wad_loader_base(void);
uint32_t doom_wad_loader_bytes(void);
const char* doom_wad_loader_name(void);
uint32_t doom_wad_loader_lump_count(void);
uint32_t doom_wad_loader_directory_offset(void);

#endif
