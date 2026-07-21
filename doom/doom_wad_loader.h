#ifndef DOOM_WAD_LOADER_H
#define DOOM_WAD_LOADER_H

#include <stdint.h>

int doom_wad_loader_receive(void);
void doom_wad_loader_invalidate(void);
void doom_wad_loader_print_status(void);
int doom_wad_loader_is_loaded(void);
uint32_t doom_wad_loader_base(void);
uint32_t doom_wad_loader_bytes(void);
const char* doom_wad_loader_name(void);
uint32_t doom_wad_loader_lump_count(void);
uint32_t doom_wad_loader_directory_offset(void);

#endif
