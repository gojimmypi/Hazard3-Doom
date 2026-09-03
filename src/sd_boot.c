/* -----------------------------------------------------------------------------
 * File:        sd_boot.c
 * Path:        src/sd_boot.c
 *
 * Project:     Hazard3-Doom
 * Purpose:     Coordinate SD-card mounting and loading of Doom images and IWAD
 *              data.
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
#include "sd_boot.h"
#include "sd_spi.h"
#include "fat_ro.h"
#include "doom/doom_image_loader.h"
#include "doom/doom_wad_loader.h"
#include "doom/hazard3_platform.h"
#include "doom/hazard3_video.h"

#define FAT_TYPE_16 16u
#define FAT_TYPE_32 32u
#define FAT_ATTR_LONG_NAME 0x0fu
#define FAT_ATTR_VOLUME_ID 0x08u
#define FAT_ATTR_DIRECTORY 0x10u

static hazard3_sd_card_t sd_card;
static hazard3_fat_fs_t fat_fs;
static uint32_t sd_mount_ok;
static uint32_t sd_boot_runs;
static uint32_t sd_boot_failures;
static uint32_t sd_last_h3d_bytes;
static uint32_t sd_last_wad_bytes;
static const char* sd_last_wad_name;
static uint8_t sd_directory_sector[512];

static uint16_t sd_read_le16(const uint8_t* p)
{
    return (uint16_t)((uint16_t)p[0] | ((uint16_t)p[1] << 8));
}

static uint32_t sd_read_le32(const uint8_t* p)
{
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) |
        ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static uint32_t sd_cluster_lba(uint32_t cluster)
{
    return fat_fs.data_lba +
        (cluster - 2u) * fat_fs.sectors_per_cluster;
}

static int sd_cluster_is_eoc(uint32_t cluster)
{
    return fat_fs.fat_type == FAT_TYPE_16 ? cluster >= 0xfff8u :
        cluster >= 0x0ffffff8u;
}

static int sd_next_cluster(uint32_t cluster, uint32_t* next)
{
    uint32_t offset;
    uint32_t lba;
    uint32_t within;
    uint32_t value;

    if (fat_fs.fat_type == FAT_TYPE_16) {
        offset = cluster * 2u;
    } else {
        offset = cluster * 4u;
    }

    lba = fat_fs.fat_lba + offset / 512u;
    within = offset & 511u;

    if (!hazard3_sd_read_block(&sd_card, lba, sd_directory_sector)) {
        return -1;
    }

    value = fat_fs.fat_type == FAT_TYPE_16 ?
        sd_read_le16(sd_directory_sector + within) :
        sd_read_le32(sd_directory_sector + within) & 0x0fffffffu;

    if (sd_cluster_is_eoc(value)) {
        return 0;
    }
    if (value < 2u) {
        return -1;
    }

    *next = value;
    return 1;
}

static void sd_print_name_83(const uint8_t* entry)
{
    uint32_t base_end = 8u;
    uint32_t ext_end = 11u;

    while (base_end != 0u && entry[base_end - 1u] == ' ') {
        --base_end;
    }
    while (ext_end > 8u && entry[ext_end - 1u] == ' ') {
        --ext_end;
    }

    for (uint32_t i = 0u; i < base_end; ++i) {
        hazard3_console_putc(entry[i]);
    }

    if (ext_end > 8u) {
        hazard3_console_putc('.');
        for (uint32_t i = 8u; i < ext_end; ++i) {
            hazard3_console_putc(entry[i]);
        }
    }
}

static int sd_list_directory_sector(uint32_t lba, uint32_t* entry_count)
{
    if (!hazard3_sd_read_block(&sd_card, lba, sd_directory_sector)) {
        return -1;
    }

    for (uint32_t offset = 0u; offset < 512u; offset += 32u) {
        const uint8_t* entry = sd_directory_sector + offset;
        uint8_t first = entry[0];
        uint8_t attr = entry[11];

        if (first == 0x00u) {
            return 1;
        }
        if (first == 0xe5u || attr == FAT_ATTR_LONG_NAME ||
            (attr & FAT_ATTR_VOLUME_ID) != 0u) {
            continue;
        }

        hazard3_console_puts("  ");
        sd_print_name_83(entry);

        if ((attr & FAT_ATTR_DIRECTORY) != 0u) {
            hazard3_console_puts("  <DIR>\r\n");
        } else {
            hazard3_console_puts("  bytes=");
            hazard3_console_put_hex32(sd_read_le32(entry + 28u));
            hazard3_console_puts("\r\n");
        }
        ++*entry_count;
    }

    return 0;
}

static void hazard3_sd_print_root_directory(void)
{
    uint32_t entry_count = 0u;
    int end_of_directory = 0;

    if (sd_mount_ok == 0u || fat_fs.fat_type == 0u) {
        return;
    }

    hazard3_console_puts("SD FAT root (8.3):\r\n");

    if (fat_fs.fat_type == FAT_TYPE_16) {
        for (uint32_t sector_index = 0u;
            sector_index < fat_fs.root_dir_sectors && !end_of_directory;
            ++sector_index) {
            int result = sd_list_directory_sector(
                fat_fs.root_lba + sector_index, &entry_count);
            if (result < 0) {
                hazard3_console_puts("  <directory read error>\r\n");
                return;
            }
            end_of_directory = result;
        }
    } else if (fat_fs.fat_type == FAT_TYPE_32) {
        uint32_t cluster = fat_fs.root_cluster;

        for (uint32_t guard = 0u;
            guard <= fat_fs.cluster_count && !end_of_directory;
            ++guard) {
            uint32_t base = sd_cluster_lba(cluster);

            for (uint32_t sector_index = 0u;
                sector_index < fat_fs.sectors_per_cluster &&
                !end_of_directory;
                ++sector_index) {
                int result = sd_list_directory_sector(
                    base + sector_index, &entry_count);
                if (result < 0) {
                    hazard3_console_puts("  <directory read error>\r\n");
                    return;
                }
                end_of_directory = result;
            }

            if (!end_of_directory) {
                uint32_t next;
                int result = sd_next_cluster(cluster, &next);
                if (result < 0) {
                    hazard3_console_puts("  <FAT chain read error>\r\n");
                    return;
                }
                if (result == 0) {
                    break;
                }
                cluster = next;
            }
        }
    }

    if (entry_count == 0u) {
        hazard3_console_puts("  <empty>\r\n");
    }

    hazard3_console_puts("root_entries=");
    hazard3_console_put_hex32(entry_count);
    hazard3_console_puts("\r\n");
}

static int fat_stream_read(void* context, void* buffer, uint32_t byte_count)
{
    return hazard3_fat_read((hazard3_fat_file_t*)context, buffer, byte_count);
}

static int open_wad(hazard3_fat_file_t* file, const char** file_name)
{
    static const char doom_name83[11] = {
        'D','O','O','M',' ',' ',' ',' ','W','A','D'
    };

    if (hazard3_fat_open_83(&fat_fs, doom_name83, file)) {
        *file_name = "DOOM.WAD";
        return 1;
    }
    return 0;
}

int hazard3_sd_boot(int launch_after_load)
{
    static const char h3d_name83[11] = {
        'D','O','O','M',' ',' ',' ',' ','H','3','D'
    };
    hazard3_fat_file_t h3d_file;
    hazard3_fat_file_t wad_file;
    const char* wad_name;
    ++sd_boot_runs;
    sd_mount_ok = 0u;
    sd_last_h3d_bytes = 0u;
    sd_last_wad_bytes = 0u;
    sd_last_wad_name = (const char*)0;

    if (HAZARD3_VIDEO_FPGA_BUILD_ID != HAZARD3_FPGA_BUILD_ID_ULX3S &&
        HAZARD3_VIDEO_FPGA_BUILD_ID != HAZARD3_FPGA_BUILD_ID_ULX3S_12F &&
        HAZARD3_VIDEO_FPGA_BUILD_ID != HAZARD3_FPGA_BUILD_ID_ULX4M_LD) {
        ++sd_boot_failures;
        hazard3_console_puts("SD boot: unsupported on this FPGA target\r\n");
        return 0;
    }
    hazard3_console_puts("SD boot: initializing micro-SD...\r\n");
    if (!hazard3_sd_init(&sd_card)) {
        ++sd_boot_failures;
        hazard3_console_puts("SD boot: card initialization failed\r\n");
        return 0;
    }
    hazard3_sd_print_status(&sd_card);

    if (!hazard3_fat_mount(&fat_fs, &sd_card)) {
        ++sd_boot_failures;
        hazard3_console_puts("SD boot: FAT16/FAT32 mount failed\r\n");
        return 0;
    }
    sd_mount_ok = 1u;
    hazard3_fat_print_status(&fat_fs);
    if (!hazard3_fat_open_83(&fat_fs, h3d_name83, &h3d_file)) {
        ++sd_boot_failures;
        hazard3_console_puts("SD boot: DOOM.H3D not found in FAT root\r\n");
        return 0;
    }
    sd_last_h3d_bytes = h3d_file.size;
    hazard3_console_puts("SD boot: loading DOOM.H3D bytes=");
    hazard3_console_put_hex32(h3d_file.size);
    hazard3_console_puts("\r\n");
    if (!doom_image_loader_load_stream(fat_stream_read, &h3d_file)) {
        ++sd_boot_failures;
        hazard3_console_puts("SD boot: H3D load/CRC validation failed\r\n");
        return 0;
    }
    if (!open_wad(&wad_file, &wad_name)) {
        ++sd_boot_failures;
        hazard3_console_puts("SD boot: DOOM.WAD not found in FAT root\r\n");
        return 0;
    }
    sd_last_wad_bytes = wad_file.size;
    sd_last_wad_name = wad_name;
    hazard3_console_puts("SD boot: loading ");
    hazard3_console_puts(wad_name);
    hazard3_console_puts(" bytes=");
    hazard3_console_put_hex32(wad_file.size);
    hazard3_console_puts("\r\n");
    if (!doom_wad_loader_load_raw_stream(wad_name, wad_file.size,
        fat_stream_read, &wad_file)) {
        ++sd_boot_failures;
        hazard3_console_puts("SD boot: IWAD validation failed\r\n");
        return 0;
    }
    hazard3_console_puts("SD boot: image and IWAD ready\r\n");
    if (launch_after_load != 0) {
        return doom_image_loader_launch();
    }
    return 1;
}

void hazard3_sd_boot_print_status(void)
{
    hazard3_console_puts("\r\nsd_boot_runs=");
    hazard3_console_put_hex32(sd_boot_runs);
    hazard3_console_puts(" failures=");
    hazard3_console_put_hex32(sd_boot_failures);
    hazard3_console_puts(" mounted=");
    hazard3_console_puts(sd_mount_ok != 0u ? "YES" : "NO");
    hazard3_console_puts("\r\n");
    hazard3_sd_print_status(&sd_card);
    if (sd_mount_ok != 0u) {
        hazard3_fat_print_status(&fat_fs);
        hazard3_sd_print_root_directory();
    }
    hazard3_console_puts("sd_h3d_bytes=");
    hazard3_console_put_hex32(sd_last_h3d_bytes);
    hazard3_console_puts(" sd_wad_bytes=");
    hazard3_console_put_hex32(sd_last_wad_bytes);
    hazard3_console_puts(" wad=");
    hazard3_console_puts(sd_last_wad_name != (const char*)0 ?
        sd_last_wad_name : "NONE");
    hazard3_console_puts("\r\n");
}
