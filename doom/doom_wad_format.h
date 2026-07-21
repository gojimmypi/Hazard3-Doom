#ifndef DOOM_WAD_FORMAT_H
#define DOOM_WAD_FORMAT_H

#include <stdint.h>

#include "doom_image_format.h"

#define HAZARD3_DOOM_WAD_MAGIC          0x31573348u /* "H3W1" */
#define HAZARD3_DOOM_WAD_FORMAT_VERSION 1u
#define HAZARD3_DOOM_WAD_HEADER_BYTES   64u
#define HAZARD3_DOOM_WAD_FLAG_CRC32     (1u << 0)
#define HAZARD3_DOOM_WAD_NAME_BYTES     16u

typedef struct hazard3_doom_wad_header {
    uint32_t magic;
    uint32_t header_bytes;
    uint32_t format_version;
    uint32_t flags;
    uint32_t load_address;
    uint32_t wad_bytes;
    uint32_t payload_crc32;
    uint32_t reserved0;
    char file_name[HAZARD3_DOOM_WAD_NAME_BYTES];
    uint32_t reserved[4];
} hazard3_doom_wad_header_t;

typedef char hazard3_doom_wad_header_size_must_be_64_bytes[
    sizeof(hazard3_doom_wad_header_t) == HAZARD3_DOOM_WAD_HEADER_BYTES ? 1 : -1];

#endif
