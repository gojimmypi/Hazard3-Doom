//
// Copyright(C) 1993-1996 Id Software, Inc.
// Copyright(C) 2005-2014 Simon Howard
//
// Diagnostic variant for Hazard3-Doom: force the in-memory WAD stdio stream
// unbuffered so every W_StdC_Read() fseek/fread pair reaches the underlying
// _lseek/_read implementation directly. This is intentionally test-only.
//

#include <stdio.h>
#include "m_misc.h"
#include "w_file.h"
#include "z_zone.h"

typedef struct
{
    wad_file_t wad;
    FILE *fstream;
} stdc_wad_file_t;

extern wad_file_class_t stdc_wad_file;

static wad_file_t *W_StdC_OpenFile(char *path)
{
    stdc_wad_file_t *result;
    FILE *fstream;

    fstream = fopen(path, "rb");

    if (fstream == NULL)
    {
        return NULL;
    }

    // Hazard3 diagnostic A/B: the WAD is already resident in SDRAM and the
    // custom _lseek/_read backend is seekable. Disable newlib FILE buffering
    // and fseek read-ahead/seek optimization for this stream only.
    if (setvbuf(fstream, NULL, _IONBF, 0) != 0)
    {
        fclose(fstream);
        return NULL;
    }

    result = Z_Malloc(sizeof(stdc_wad_file_t), PU_STATIC, 0);
    result->wad.file_class = &stdc_wad_file;
    result->wad.mapped = NULL;
    result->wad.length = M_FileLength(fstream);
    result->fstream = fstream;

    return &result->wad;
}

static void W_StdC_CloseFile(wad_file_t *wad)
{
    stdc_wad_file_t *stdc_wad;

    stdc_wad = (stdc_wad_file_t *) wad;

    fclose(stdc_wad->fstream);
    Z_Free(stdc_wad);
}

size_t W_StdC_Read(wad_file_t *wad, unsigned int offset,
                   void *buffer, size_t buffer_len)
{
    stdc_wad_file_t *stdc_wad;
    size_t result;

    stdc_wad = (stdc_wad_file_t *) wad;

    fseek(stdc_wad->fstream, offset, SEEK_SET);
    result = fread(buffer, 1, buffer_len, stdc_wad->fstream);

    return result;
}

wad_file_class_t stdc_wad_file =
{
    W_StdC_OpenFile,
    W_StdC_CloseFile,
    W_StdC_Read,
};
