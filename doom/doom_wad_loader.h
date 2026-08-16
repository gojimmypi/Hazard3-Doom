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
