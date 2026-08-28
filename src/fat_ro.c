/* -----------------------------------------------------------------------------
 * File:        fat_ro.c
 * Path:        src/fat_ro.c
 *
 * Project:     Hazard3-Doom
 * Purpose:     Implement the minimal read-only FAT16/FAT32 filesystem support
 *              used for SD boot.
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

#include <stdint.h>

#include "fat_ro.h"
#include "doom/hazard3_platform.h"

#define FAT_TYPE_16 16u
#define FAT_TYPE_32 32u
#define FAT_ATTR_LONG_NAME 0x0fu
#define FAT_ATTR_VOLUME_ID 0x08u
#define FAT_ATTR_DIRECTORY 0x10u

static uint16_t read_le16(const uint8_t* p)
{
    return (uint16_t)((uint16_t)p[0] | ((uint16_t)p[1] << 8));
}

static uint32_t read_le32(const uint8_t* p)
{
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) |
        ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static int is_power_of_two(uint32_t value)
{
    return value != 0u && (value & (value - 1u)) == 0u;
}

static int read_sector(hazard3_fat_fs_t* fs, uint32_t lba,
    const uint8_t** sector)
{
    if (fs->cache_valid == 0u || fs->cache_lba != lba) {
        if (!hazard3_sd_read_block(fs->card, lba, fs->cache)) {
            return 0;
        }
        fs->cache_lba = lba;
        fs->cache_valid = 1u;
    }
    *sector = fs->cache;
    return 1;
}

static int looks_like_boot_sector(const uint8_t* sector)
{
    uint32_t spc = sector[13];
    uint32_t fats = sector[16];
    return read_le16(sector + 11) == 512u &&
        is_power_of_two(spc) && spc <= 128u &&
        read_le16(sector + 14) != 0u &&
        (fats == 1u || fats == 2u) &&
        sector[510] == 0x55u && sector[511] == 0xaau;
}

static int parse_boot_sector(hazard3_fat_fs_t* fs, uint32_t partition_lba,
    const uint8_t* bpb)
{
    uint32_t reserved = read_le16(bpb + 14);
    uint32_t fats = bpb[16];
    uint32_t root_entries = read_le16(bpb + 17);
    uint32_t total_sectors = read_le16(bpb + 19);
    uint32_t fat_sectors = read_le16(bpb + 22);
    uint32_t data_sectors;
    uint32_t root_dir_sectors;
    uint32_t first_data_relative;
    uint32_t cluster_count;

    if (read_le16(bpb + 11) != 512u || !is_power_of_two(bpb[13]) ||
        bpb[13] > 128u || reserved == 0u || (fats != 1u && fats != 2u)) {
        return 0;
    }
    if (total_sectors == 0u) {
        total_sectors = read_le32(bpb + 32);
    }
    if (fat_sectors == 0u) {
        fat_sectors = read_le32(bpb + 36);
    }
    if (total_sectors == 0u || fat_sectors == 0u) {
        return 0;
    }

    root_dir_sectors = ((root_entries * 32u) + 511u) / 512u;
    first_data_relative = reserved + fats * fat_sectors + root_dir_sectors;
    if (first_data_relative >= total_sectors) {
        return 0;
    }
    data_sectors = total_sectors - first_data_relative;
    cluster_count = data_sectors / bpb[13];

    if (cluster_count < 4085u) {
        hazard3_console_puts("SD FAT: FAT12 is not supported\r\n");
        return 0;
    }

    fs->partition_lba = partition_lba;
    fs->fat_lba = partition_lba + reserved;
    fs->data_lba = partition_lba + first_data_relative;
    fs->root_dir_sectors = root_dir_sectors;
    fs->sectors_per_fat = fat_sectors;
    fs->sectors_per_cluster = bpb[13];
    fs->cluster_count = cluster_count;

    if (cluster_count < 65525u) {
        fs->fat_type = FAT_TYPE_16;
        fs->root_lba = partition_lba + reserved + fats * fat_sectors;
        fs->root_cluster = 0u;
    } else {
        fs->fat_type = FAT_TYPE_32;
        fs->root_lba = 0u;
        fs->root_cluster = read_le32(bpb + 44) & 0x0fffffffu;
        if (fs->root_cluster < 2u) {
            return 0;
        }
    }
    return 1;
}

static uint32_t cluster_lba(const hazard3_fat_fs_t* fs, uint32_t cluster)
{
    return fs->data_lba + (cluster - 2u) * fs->sectors_per_cluster;
}

static int cluster_is_eoc(const hazard3_fat_fs_t* fs, uint32_t cluster)
{
    return fs->fat_type == FAT_TYPE_16 ? cluster >= 0xfff8u :
        cluster >= 0x0ffffff8u;
}

static int next_cluster(hazard3_fat_fs_t* fs, uint32_t cluster,
    uint32_t* next)
{
    const uint8_t* sector;
    uint32_t offset;
    uint32_t lba;
    uint32_t within;
    uint32_t value;

    if (fs->fat_type == FAT_TYPE_16) {
        offset = cluster * 2u;
    } else {
        offset = cluster * 4u;
    }
    lba = fs->fat_lba + offset / 512u;
    within = offset & 511u;
    if (!read_sector(fs, lba, &sector)) {
        return 0;
    }
    value = fs->fat_type == FAT_TYPE_16 ? read_le16(sector + within) :
        read_le32(sector + within) & 0x0fffffffu;
    if (value < 2u || cluster_is_eoc(fs, value)) {
        return 0;
    }
    *next = value;
    return 1;
}

static int name_matches(const uint8_t* entry, const char name83[11])
{
    for (uint32_t i = 0u; i < 11u; ++i) {
        if (entry[i] != (uint8_t)name83[i]) {
            return 0;
        }
    }
    return 1;
}

static int entry_to_file(hazard3_fat_fs_t* fs, const uint8_t* entry,
    hazard3_fat_file_t* file)
{
    uint32_t cluster = read_le16(entry + 26);
    if (fs->fat_type == FAT_TYPE_32) {
        cluster |= (uint32_t)read_le16(entry + 20) << 16;
        cluster &= 0x0fffffffu;
    }
    file->fs = fs;
    file->first_cluster = cluster;
    file->current_cluster = cluster;
    file->current_cluster_index = 0u;
    file->size = read_le32(entry + 28);
    file->position = 0u;
    return file->size == 0u || cluster >= 2u;
}

static int inspect_directory_sector(hazard3_fat_fs_t* fs, uint32_t lba,
    const char name83[11], hazard3_fat_file_t* file, int* end_of_directory)
{
    const uint8_t* sector;
    if (!read_sector(fs, lba, &sector)) {
        return 0;
    }
    for (uint32_t offset = 0u; offset < 512u; offset += 32u) {
        const uint8_t* entry = sector + offset;
        uint8_t first = entry[0];
        uint8_t attr = entry[11];
        if (first == 0x00u) {
            *end_of_directory = 1;
            return 1;
        }
        if (first == 0xe5u || attr == FAT_ATTR_LONG_NAME ||
            (attr & (FAT_ATTR_VOLUME_ID | FAT_ATTR_DIRECTORY)) != 0u) {
            continue;
        }
        if (name_matches(entry, name83)) {
            *end_of_directory = 2;
            return entry_to_file(fs, entry, file);
        }
    }
    return 1;
}

int hazard3_fat_mount(hazard3_fat_fs_t* fs, hazard3_sd_card_t* card)
{
    const uint8_t* sector;
    uint32_t partition_lba = 0u;

    if (fs == (hazard3_fat_fs_t*)0 || card == (hazard3_sd_card_t*)0 ||
        card->initialized == 0u) {
        return 0;
    }

    fs->card = card;
    fs->cache_valid = 0u;
    fs->fat_type = 0u;

    if (!read_sector(fs, 0u, &sector)) {
        return 0;
    }
    if (looks_like_boot_sector(sector)) {
        partition_lba = 0u;
    } else {
        if (sector[510] != 0x55u || sector[511] != 0xaau) {
            return 0;
        }
        partition_lba = read_le32(sector + 446u + 8u);
        if (partition_lba == 0u || !read_sector(fs, partition_lba, &sector) ||
            !looks_like_boot_sector(sector)) {
            return 0;
        }
    }

    return parse_boot_sector(fs, partition_lba, sector);
}

int hazard3_fat_open_83(hazard3_fat_fs_t* fs, const char name83[11],
    hazard3_fat_file_t* file)
{
    int state = 0;

    if (fs == (hazard3_fat_fs_t*)0 || file == (hazard3_fat_file_t*)0 ||
        fs->fat_type == 0u) {
        return 0;
    }

    if (fs->fat_type == FAT_TYPE_16) {
        for (uint32_t sector_index = 0u;
            sector_index < fs->root_dir_sectors && state == 0;
            ++sector_index) {
            if (!inspect_directory_sector(fs, fs->root_lba + sector_index,
                name83, file, &state)) {
                return 0;
            }
        }
        return state == 2;
    }

    {
        uint32_t cluster = fs->root_cluster;
        for (uint32_t guard = 0u; guard <= fs->cluster_count; ++guard) {
            uint32_t base = cluster_lba(fs, cluster);
            for (uint32_t s = 0u; s < fs->sectors_per_cluster; ++s) {
                if (!inspect_directory_sector(fs, base + s, name83, file,
                    &state)) {
                    return 0;
                }
                if (state != 0) {
                    return state == 2;
                }
            }
            if (!next_cluster(fs, cluster, &cluster)) {
                break;
            }
        }
    }
    return 0;
}

static int seek_current_cluster(hazard3_fat_file_t* file,
    uint32_t target_index)
{
    if (target_index < file->current_cluster_index) {
        file->current_cluster = file->first_cluster;
        file->current_cluster_index = 0u;
    }
    while (file->current_cluster_index < target_index) {
        uint32_t next;
        if (!next_cluster(file->fs, file->current_cluster, &next)) {
            return 0;
        }
        file->current_cluster = next;
        ++file->current_cluster_index;
    }
    return 1;
}

int hazard3_fat_read(hazard3_fat_file_t* file, void* buffer,
    uint32_t byte_count)
{
    uint8_t* out = (uint8_t*)buffer;
    uint32_t cluster_bytes;

    if (file == (hazard3_fat_file_t*)0 || out == (uint8_t*)0 ||
        file->position > file->size ||
        byte_count > file->size - file->position) {
        return 0;
    }

    cluster_bytes = file->fs->sectors_per_cluster * 512u;
    while (byte_count != 0u) {
        const uint8_t* sector;
        uint32_t cluster_index = file->position / cluster_bytes;
        uint32_t within_cluster = file->position % cluster_bytes;
        uint32_t sector_index = within_cluster / 512u;
        uint32_t within_sector = within_cluster & 511u;
        uint32_t chunk = 512u - within_sector;
        uint32_t remaining_file = file->size - file->position;

        if (chunk > byte_count) {
            chunk = byte_count;
        }
        if (chunk > remaining_file) {
            chunk = remaining_file;
        }
        if (!seek_current_cluster(file, cluster_index) ||
            !read_sector(file->fs,
                cluster_lba(file->fs, file->current_cluster) + sector_index,
                &sector)) {
            return 0;
        }
        for (uint32_t i = 0u; i < chunk; ++i) {
            out[i] = sector[within_sector + i];
        }
        out += chunk;
        file->position += chunk;
        byte_count -= chunk;
    }
    return 1;
}

void hazard3_fat_print_status(const hazard3_fat_fs_t* fs)
{
    hazard3_console_puts("fat_type=");
    if (fs == (const hazard3_fat_fs_t*)0 || fs->fat_type == 0u) {
        hazard3_console_puts("NONE\r\n");
        return;
    }
    hazard3_console_puts(fs->fat_type == FAT_TYPE_32 ? "FAT32" : "FAT16");
    hazard3_console_puts(" partition_lba=");
    hazard3_console_put_hex32(fs->partition_lba);
    hazard3_console_puts(" sectors_per_cluster=");
    hazard3_console_put_hex32(fs->sectors_per_cluster);
    hazard3_console_puts("\r\n");
}
