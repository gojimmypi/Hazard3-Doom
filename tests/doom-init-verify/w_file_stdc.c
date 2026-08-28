/* -----------------------------------------------------------------------------
 * File:        w_file_stdc.c
 * Path:        tests/doom-init-verify/w_file_stdc.c
 *
 * Project:     Hazard3-Doom
 * Purpose:     Expose the memory-resident IWAD to diagnostic Doom code without
 *              newlib stdio caching.
 *
 * Hazard3-Doom modifications: Copyright (c) 2026 gojimmypi
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
// Copyright(C) 1993-1996 Id Software, Inc.
// Copyright(C) 2005-2014 Simon Howard
//
// Diagnostic variant for Hazard3-Doom: expose the already memory-resident WAD
// as mapped data, bypassing both newlib stdio and the redundant Zone lump cache.
//

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "hazard3_platform.h"
#include "m_misc.h"
#include "w_file.h"
#include "z_zone.h"

typedef struct
{
    wad_file_t wad;
} stdc_wad_file_t;

extern wad_file_class_t stdc_wad_file;

#define H3DIV_DOOM1_TEXTURE1_BYTES 9234u
#define H3DIV_DOOM1_TEXTURE1_FNV1A 0x7bfce9c1u

static uint32_t H3DIV_Fnv1aSource(const volatile uint8_t *data, size_t size)
{
    uint32_t hash = 2166136261u;

    while (size-- != 0u)
    {
        hash ^= *data++;
        hash *= 16777619u;
    }

    return hash;
}

static uint32_t H3DIV_Fnv1aBuffer(const uint8_t *data, size_t size)
{
    uint32_t hash = 2166136261u;

    while (size-- != 0u)
    {
        hash ^= *data++;
        hash *= 16777619u;
    }

    return hash;
}

static wad_file_t *W_StdC_OpenFile(char *path)
{
    stdc_wad_file_t *result;

    result = Z_Malloc(sizeof(stdc_wad_file_t), PU_STATIC, 0);
    result->wad.file_class = &stdc_wad_file;
    result->wad.mapped = (byte *)(uintptr_t)hazard3_wad_base();
    result->wad.length = hazard3_wad_bytes();

    printf("H3DIV WAD direct open path=%s bytes=%u\n",
           path, (unsigned int)result->wad.length);

    return &result->wad;
}

static void W_StdC_CloseFile(wad_file_t *wad)
{
    Z_Free(wad);
}

size_t W_StdC_Read(wad_file_t *wad, unsigned int offset,
                   void *buffer, size_t buffer_len)
{
    uint32_t wad_bytes = hazard3_wad_bytes();
    const volatile uint8_t *source;
    uint32_t source_hash = 0u;
    uint32_t destination_hash;
    size_t first_mismatch = buffer_len;
    size_t index;

    (void)wad;
    if (offset > wad_bytes || buffer_len > wad_bytes - offset)
    {
        return 0;
    }

    source = (const volatile uint8_t *)(uintptr_t)(hazard3_wad_base() + offset);
    if (buffer_len == H3DIV_DOOM1_TEXTURE1_BYTES)
    {
        source_hash = H3DIV_Fnv1aSource(source, buffer_len);
    }

    memcpy(buffer, (const void *)source, buffer_len);

    if (buffer_len == H3DIV_DOOM1_TEXTURE1_BYTES)
    {
        const uint8_t *destination = buffer;

        destination_hash = H3DIV_Fnv1aBuffer(destination, buffer_len);
        for (index = 0u; index < buffer_len; ++index)
        {
            if (destination[index] != source[index])
            {
                first_mismatch = index;
                break;
            }
        }

        printf("H3DIV TEXTURE1 transport offset=%08x bytes=%u source=%08x destination=%08x expected=%08x first=%u\n",
               offset, (unsigned int)buffer_len, source_hash,
               destination_hash, H3DIV_DOOM1_TEXTURE1_FNV1A,
               (unsigned int)first_mismatch);
    }

    return buffer_len;
}

wad_file_class_t stdc_wad_file =
{
    W_StdC_OpenFile,
    W_StdC_CloseFile,
    W_StdC_Read,
};
