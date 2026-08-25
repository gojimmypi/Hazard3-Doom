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

#define H3DIV_WAD_TRACE_LIMIT 8u

static unsigned int h3div_wad_read_count;

static wad_file_t *W_StdC_OpenFile(char *path)
{
    stdc_wad_file_t *result;
    FILE *fstream;

    printf("H3DIV WAD open begin path=%s\n", path);
    fstream = fopen(path, "rb");

    if (fstream == NULL)
    {
        printf("H3DIV WAD open FAIL\n");
        return NULL;
    }

    printf("H3DIV WAD open PASS\n");

    // Hazard3 diagnostic A/B: the WAD is already resident in SDRAM and the
    // custom _lseek/_read backend is seekable. Disable newlib FILE buffering
    // and fseek read-ahead/seek optimization for this stream only.
    printf("H3DIV WAD setvbuf begin\n");
    if (setvbuf(fstream, NULL, _IONBF, 0) != 0)
    {
        printf("H3DIV WAD setvbuf FAIL\n");
        fclose(fstream);
        return NULL;
    }

    printf("H3DIV WAD setvbuf PASS\n");

    result = Z_Malloc(sizeof(stdc_wad_file_t), PU_STATIC, 0);
    result->wad.file_class = &stdc_wad_file;
    result->wad.mapped = NULL;
    printf("H3DIV WAD file-length begin\n");
    result->wad.length = M_FileLength(fstream);
    printf("H3DIV WAD file-length PASS\n");
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
    unsigned int trace_index;
    int trace;

    stdc_wad = (stdc_wad_file_t *) wad;
    trace_index = h3div_wad_read_count++;
    trace = trace_index < H3DIV_WAD_TRACE_LIMIT;

    if (trace)
    {
        printf("H3DIV WAD read=%u begin offset=%u bytes=%u\n",
               trace_index, offset, (unsigned int)buffer_len);
    }

    if (fseek(stdc_wad->fstream, offset, SEEK_SET) != 0)
    {
        if (trace)
        {
            printf("H3DIV WAD read=%u fseek FAIL\n", trace_index);
        }
        return 0;
    }

    if (trace)
    {
        printf("H3DIV WAD read=%u fseek PASS\n", trace_index);
    }

    result = fread(buffer, 1, buffer_len, stdc_wad->fstream);

    if (trace)
    {
        printf("H3DIV WAD read=%u fread=%u expected=%u\n",
               trace_index, (unsigned int)result,
               (unsigned int)buffer_len);
    }

    return result;
}

wad_file_class_t stdc_wad_file =
{
    W_StdC_OpenFile,
    W_StdC_CloseFile,
    W_StdC_Read,
};
