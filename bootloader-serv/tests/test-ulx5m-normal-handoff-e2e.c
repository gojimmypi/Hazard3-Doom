/* Host-only bridge: actual U5IM validation and C transport -> byte trace.
 * The output is a disposable test fixture, NEVER a hardware programming file.
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ulx5m_normal_boot.h"
#include "ulx5m_flash_layout.h"

static uint8_t *flash_data;
static uint32_t image_bytes, read_starts, sent, prepared, finished, aborted;
static int inject_late_drift;
static FILE *trace_file;

static uint32_t crc32_bytes(const uint8_t *buf, uint32_t length)
{
    uint32_t crc = ~0u;
    for (uint32_t n = 0; n < length; ++n) {
        crc ^= buf[n];
        for (unsigned bit = 0; bit < 8; ++bit)
            crc = (crc >> 1) ^ ((crc & 1u) ? 0xedb88320u : 0u);
    }
    return ~crc;
}

static void store_u32(uint8_t *dst, uint32_t value)
{
    for (unsigned n = 0; n < 4; ++n)
        dst[n] = (uint8_t)(value >> (8 * n));
}

static int read_flash(void *ctx, uint32_t address, uint8_t *dst, unsigned length)
{
    (void)ctx;
    if (address >= ULX5M_FLASH_BYTES ||
        length > ULX5M_FLASH_BYTES - address)
        return -1;
    if (address == ULX5M_NORMAL_BOOT_SLOT + 256u && ++read_starts == 2 &&
        inject_late_drift) {
        /* After validated first pass, change the FINAL payload byte. */
        flash_data[address + image_bytes - 1] ^= 1u;
    }
    memcpy(dst, flash_data + address, length);
    return 0;
}

static int prepare(void *ctx, uint32_t length)
{
    (void)ctx;
    ++prepared;
    return length == image_bytes ? 0 : -1;
}

static int send_byte(void *ctx, uint8_t value)
{
    (void)ctx;
    if (sent >= image_bytes || fputc(value, trace_file) == EOF)
        return -1;
    ++sent;
    return 0;
}

static int finish(void *ctx)
{
    (void)ctx;
    ++finished;
    return sent == image_bytes ? 0 : -1;
}

static void abort_stream(void *ctx)
{
    (void)ctx;
    ++aborted;
}

static int load_flash_image(const char *path)
{
    FILE *input = fopen(path, "rb");
    long size;
    uint8_t *hdr;
    if (!input)
        return -1;
    if (fseek(input, 0, SEEK_END) || (size = ftell(input)) < 16 ||
        (unsigned long)size > ULX5M_NORMAL_BOOT_MAX_BYTES ||
        fseek(input, 0, SEEK_SET)) {
        fclose(input);
        return -1;
    }
    image_bytes = (uint32_t)size;
    flash_data = malloc(ULX5M_FLASH_BYTES);
    if (!flash_data) {
        fclose(input);
        return -1;
    }
    memset(flash_data, 0xff, ULX5M_FLASH_BYTES);
    hdr = flash_data + ULX5M_NORMAL_BOOT_SLOT;
    uint8_t *image = hdr + 256u;
    size_t count = fread(image, 1, image_bytes, input);
    int close_result = fclose(input);
    if (count != image_bytes || close_result ||
        memcmp(image, "\xd9\x01\xed\x96", 4) != 0)
        return -1;
    memset(hdr, 0, 32);
    memcpy(hdr, "U5IM", 4);
    store_u32(hdr + 4, 1u);
    store_u32(hdr + 8, 1u);
    store_u32(hdr + 12, 256u);
    store_u32(hdr + 16, image_bytes);
    store_u32(hdr + 20, crc32_bytes(image, image_bytes));
    store_u32(hdr + 24, crc32_bytes(hdr, 32u));
    return 0;
}

int main(int argc, char **argv)
{
    struct ulx5m_normal_image_reader reader = {NULL, read_flash};
    struct ulx5m_normal_boot_transport transport = {
        NULL, prepare, send_byte, finish, abort_stream
    };
    enum ulx5m_normal_boot_result result;
    if (argc != 4 || (strcmp(argv[3], "clean") != 0 &&
                       strcmp(argv[3], "late-drift") != 0) ||
        load_flash_image(argv[1])) {
        fputs("[FAIL] Need input.bit output.trace clean|late-drift\n", stderr);
        free(flash_data);
        return 1;
    }
    /* Prove a valid U5IM by itself cannot invoke the transport. */
    if (ulx5m_normal_boot_run(&reader, &transport, 0, 0) !=
            ULX5M_BOOT_VALID_BLOCKED || prepared || sent || finished || aborted) {
        fputs("[FAIL] Unapproved U5IM initiated a transport\n", stderr);
        free(flash_data);
        return 1;
    }
    read_starts = 0;
    inject_late_drift = strcmp(argv[3], "late-drift") == 0;
    trace_file = fopen(argv[2], "wb");
    if (!trace_file) {
        free(flash_data);
        return 1;
    }
    /* authorize_stream=1 is HOST TEST INJECTION, not device authorization. */
    result = ulx5m_normal_boot_run(&reader, &transport, 0, 1);
    int close_result = fclose(trace_file);
    if (close_result || prepared != 1 || sent != image_bytes ||
        (inject_late_drift && (result != ULX5M_BOOT_STREAM_ERROR ||
                               finished != 0 || aborted != 1)) ||
        (!inject_late_drift && (result != ULX5M_BOOT_STREAM_COMPLETE ||
                                finished != 1 || aborted != 0))) {
        fputs("[FAIL] C firmware completion or abort contract violated\n", stderr);
        free(flash_data);
        return 1;
    }
    printf("[PASS] C U5IM -> transport: bytes=%u finish=%u abort=%u\n",
           sent, finished, aborted);
    free(flash_data);
    return 0;
}
