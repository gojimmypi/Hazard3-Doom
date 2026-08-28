/* -----------------------------------------------------------------------------
 * File:        w_file_stdc_hazard3.c
 * Path:        doom/w_file_stdc_hazard3.c
 *
 * Project:     Hazard3-Doom
 * Purpose:     Implement a DoomGeneric WAD backend for the monitor-provided
 *              memory-resident IWAD.
 *
 * Copyright (c) 2026 gojimmypi
 *
 * Licensed under the GNU General Public License, version 2 or later.
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 *
 * This software is provided WITHOUT ANY WARRANTY.
 * See LICENSES/GPL-2.0.txt for the complete license terms.
 * See LICENSING.md for project licensing policy and scope.
 * -------------------------------------------------------------------------- */

//
// DoomGeneric WAD backend for a monitor-provided, memory-resident IWAD.
//


#include <stdint.h>
#include <string.h>

#include "hazard3_platform.h"
#include "w_file.h"
#include "z_zone.h"

typedef struct
{
    wad_file_t wad;
} hazard3_wad_file_t;

extern wad_file_class_t stdc_wad_file;

static wad_file_t *W_StdC_OpenFile(char *path)
{
    hazard3_wad_file_t *result;

    (void)path;
    result = Z_Malloc(sizeof(*result), PU_STATIC, 0);
    result->wad.file_class = &stdc_wad_file;
    result->wad.mapped = (byte *)(uintptr_t)hazard3_wad_base();
    result->wad.length = hazard3_wad_bytes();

    return &result->wad;
}

static void W_StdC_CloseFile(wad_file_t *wad)
{
    Z_Free(wad);
}

static size_t W_StdC_Read(wad_file_t *wad, unsigned int offset,
                         void *buffer, size_t buffer_len)
{
    uint32_t wad_bytes = hazard3_wad_bytes();

    (void)wad;
    if (offset > wad_bytes || buffer_len > wad_bytes - offset)
    {
        return 0;
    }

    memcpy(buffer,
           (const void *)(uintptr_t)(hazard3_wad_base() + offset),
           buffer_len);
    return buffer_len;
}

wad_file_class_t stdc_wad_file =
{
    W_StdC_OpenFile,
    W_StdC_CloseFile,
    W_StdC_Read,
};
