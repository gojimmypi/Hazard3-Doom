/* -----------------------------------------------------------------------------
 * File:        doom_image_loader.h
 * Path:        doom/doom_image_loader.h
 *
 * Project:     Hazard3-Doom
 * Purpose:     Declare the resident monitor interface for Hazard3-Doom executable
 *              image loading.
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

#ifndef DOOM_IMAGE_LOADER_H
#define DOOM_IMAGE_LOADER_H

#include <stdint.h>

typedef int (*doom_image_stream_read_fn)(void* context, void* buffer,
    uint32_t byte_count);

int doom_image_loader_receive(void);
int doom_image_loader_load_stream(doom_image_stream_read_fn read_fn,
    void* context);
int doom_image_loader_launch(void);
void doom_image_loader_invalidate(void);
void doom_image_loader_print_status(void);
uint32_t doom_image_loader_receive_runs(void);
uint32_t doom_image_loader_receive_failures(void);
uint32_t doom_image_loader_launch_runs(void);
uint32_t doom_image_loader_launch_failures(void);
int doom_image_loader_is_loaded(void);

#endif
