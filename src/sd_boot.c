#include <stdint.h>

#include "sd_boot.h"
#include "sd_spi.h"
#include "fat_ro.h"
#include "doom/doom_image_loader.h"
#include "doom/doom_wad_loader.h"
#include "doom/hazard3_platform.h"
#include "doom/hazard3_video.h"

static hazard3_sd_card_t sd_card;
static hazard3_fat_fs_t fat_fs;
static uint32_t sd_mount_ok;
static uint32_t sd_boot_runs;
static uint32_t sd_boot_failures;
static uint32_t sd_last_h3d_bytes;
static uint32_t sd_last_wad_bytes;
static const char* sd_last_wad_name;

static int fat_stream_read(void* context, void* buffer, uint32_t byte_count)
{
    return hazard3_fat_read((hazard3_fat_file_t*)context, buffer, byte_count);
}

static int open_wad(hazard3_fat_file_t* file, const char** file_name)
{
    static const char doom1_name83[11] = {
        'D','O','O','M','1',' ',' ',' ','W','A','D'
    };
    static const char doom_name83[11] = {
        'D','O','O','M',' ',' ',' ',' ','W','A','D'
    };

    if (hazard3_fat_open_83(&fat_fs, doom1_name83, file)) {
        *file_name = "DOOM1.WAD";
        return 1;
    }
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

    if (HAZARD3_VIDEO_FPGA_BUILD_ID != HAZARD3_FPGA_BUILD_ID_ULX3S) {
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
        hazard3_console_puts("SD boot: DOOM1.WAD or DOOM.WAD not found in FAT root\r\n");
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
