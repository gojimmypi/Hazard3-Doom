/* -----------------------------------------------------------------------------
 * File:        doom_image_format.h
 * Path:        doom/doom_image_format.h
 *
 * Project:     Hazard3-Doom
 * Purpose:     Define the Hazard3-Doom executable image header and in-memory
 *              image format.
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

#ifndef DOOM_IMAGE_FORMAT_H
#define DOOM_IMAGE_FORMAT_H

#include <stdint.h>

#include "hazard3_memory_map.h"

#define HAZARD3_DOOM_IMAGE_MAGIC          0x31443348u /* "H3D1" */
#define HAZARD3_DOOM_IMAGE_FORMAT_VERSION 1u
#define HAZARD3_DOOM_IMAGE_HEADER_BYTES   64u
#define HAZARD3_DOOM_IMAGE_FLAG_CRC32     (1u << 0)

typedef struct hazard3_doom_image_header {
    uint32_t magic;
    uint32_t header_bytes;
    uint32_t format_version;
    uint32_t flags;
    uint32_t load_address;
    uint32_t image_bytes;
    uint32_t entry_address;
    uint32_t bss_address;
    uint32_t bss_bytes;
    uint32_t payload_crc32;
    uint32_t reserved[6];
} hazard3_doom_image_header_t;

typedef char hazard3_doom_image_header_size_must_be_64_bytes[
    sizeof(hazard3_doom_image_header_t) == HAZARD3_DOOM_IMAGE_HEADER_BYTES ? 1 : -1];

#endif
