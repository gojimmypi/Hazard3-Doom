#ifndef HAZARD3_FAT_RO_H
#define HAZARD3_FAT_RO_H

#include <stdint.h>

#include "sd_spi.h"

typedef struct hazard3_fat_fs {
    hazard3_sd_card_t* card;
    uint32_t partition_lba;
    uint32_t fat_lba;
    uint32_t data_lba;
    uint32_t root_lba;
    uint32_t root_cluster;
    uint32_t root_dir_sectors;
    uint32_t sectors_per_fat;
    uint32_t sectors_per_cluster;
    uint32_t cluster_count;
    uint32_t fat_type;
    uint32_t cache_lba;
    uint32_t cache_valid;
    uint8_t cache[512];
} hazard3_fat_fs_t;

typedef struct hazard3_fat_file {
    hazard3_fat_fs_t* fs;
    uint32_t first_cluster;
    uint32_t current_cluster;
    uint32_t current_cluster_index;
    uint32_t size;
    uint32_t position;
} hazard3_fat_file_t;

int hazard3_fat_mount(hazard3_fat_fs_t* fs, hazard3_sd_card_t* card);
int hazard3_fat_open_83(hazard3_fat_fs_t* fs, const char name83[11],
    hazard3_fat_file_t* file);
int hazard3_fat_read(hazard3_fat_file_t* file, void* buffer,
    uint32_t byte_count);
void hazard3_fat_print_status(const hazard3_fat_fs_t* fs);

#endif
