/* Host-only, read-only U5IM probe of an existing 4 MiB flash dump. */
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include "ulx5m_normal_image.h"
#include "ulx5m_flash_layout.h"

static int file_read(void *ctx, uint32_t address, uint8_t *data, unsigned length)
{
    FILE *file = ctx;
    if (fseek(file, (long)address, SEEK_SET))
        return -1;
    return fread(data, 1, length, file) == length ? 0 : -1;
}

int main(int argc, char **argv)
{
    FILE *file;
    long bytes;
    unsigned long address = ULX5M_NORMAL_IMAGE_CANDIDATE_MIN;
    struct ulx5m_normal_image_info info;
    enum ulx5m_normal_image_result result;
    if (argc != 2 && argc != 3) {
        fprintf(stderr, "Usage: %s flash-pass1.bin [candidate_address]\n", argv[0]);
        return 2;
    }
    if (argc == 3) {
        char *end;
        errno = 0;
        address = strtoul(argv[2], &end, 0);
        if (errno || !end || *end || address > 0xfffffffful) {
            fputs("Invalid candidate address\n", stderr);
            return 2;
        }
    }
    file = fopen(argv[1], "rb");
    if (!file) {
        perror(argv[1]);
        return 2;
    }
    if (fseek(file, 0, SEEK_END) || (bytes = ftell(file)) < 0 ||
        bytes != (long)ULX5M_FLASH_BYTES) {
        fputs("Expected exactly 4 MiB of existing flash data\n", stderr);
        fclose(file);
        return 2;
    }
    struct ulx5m_normal_image_reader reader = {
        .ctx = file, .read = file_read
    };
    result = ulx5m_normal_image_probe(&reader, (uint32_t)address, &info);
    fclose(file);
    if (result == ULX5M_NORMAL_IMAGE_ABSENT) {
        printf("[ABSENT] No U5IM header at 0x%06lx; no boot authorized\n", address);
        return 0;
    }
    if (result == ULX5M_NORMAL_IMAGE_INTEGRITY_OK) {
        printf("[INTEGRITY OK] U5IM payload at 0x%06x, %u bytes, CRC32 %08x\n",
               info.payload_address, info.payload_bytes, info.expected_crc32);
        puts("[POLICY] Not a verified boot image or authorized flash slot");
        return 0;
    }
    fprintf(stderr, "[REJECT] U5IM probe result %d; no boot authorized\n", result);
    return 1;
}
