/* Host-only, full-payload U5IM -> actual C firmware -> byte transport test.
 * No hardware connection and no flash-file writes are possible in this test.
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ulx5m_normal_boot.h"
#include "ulx5m_flash_layout.h"

static uint8_t *flash_mem;
static uint8_t *payload;
static uint32_t payload_size, reads, sent, prepares, finishes, aborts;
static int drift_after_validation;
static unsigned payload_start_reads;

static uint32_t crc32(const uint8_t *buf, uint32_t size)
{
    uint32_t crc = ~0u;
    for (uint32_t i = 0; i < size; ++i) {
        crc ^= buf[i];
        for (unsigned b = 0; b < 8; ++b)
            crc = (crc >> 1) ^ ((crc & 1u) ? 0xedb88320u : 0u);
    }
    return ~crc;
}

static void put32(uint8_t *ptr, uint32_t value)
{
    for (unsigned b = 0; b < 4; ++b)
        ptr[b] = (uint8_t)(value >> (b * 8));
}

static int read_flash(void *ctx, uint32_t addr, uint8_t *data, unsigned n)
{
    (void)ctx;
    if (!n || addr >= ULX5M_FLASH_BYTES || n > ULX5M_FLASH_BYTES - addr)
        return -1;
    ++reads;
    /* At the first streaming read, first-pass validation has completed. */
    if (addr == ULX5M_NORMAL_BOOT_SLOT + 256u) {
        ++payload_start_reads;
        if (drift_after_validation && payload_start_reads == 2) {
            flash_mem[ULX5M_NORMAL_BOOT_SLOT + 256u + payload_size - 1u] ^= 1u;
            drift_after_validation = 0;
        }
    }
    memcpy(data, flash_mem + addr, n);
    return 0;
}

static int prepare(void *ctx, uint32_t n)
{
    (void)ctx;
    ++prepares;
    return n == payload_size ? 0 : -1;
}

static int send_byte(void *ctx, uint8_t byte)
{
    (void)ctx;
    if (sent >= payload_size ||
        byte != flash_mem[ULX5M_NORMAL_BOOT_SLOT + 256u + sent])
        return -1;
    ++sent;
    return 0;
}

static int finish(void *ctx)
{
    (void)ctx;
    ++finishes;
    return sent == payload_size ? 0 : -1;
}

static void abort_stream(void *ctx)
{
    (void)ctx;
    ++aborts;
}

static int load_candidate(const char *filename)
{
    FILE *fp = fopen(filename, "rb");
    long len;
    uint8_t *header;
    if (!fp)
        return -1;
    if (fseek(fp, 0, SEEK_END) || (len = ftell(fp)) < 16 ||
        (unsigned long)len > ULX5M_NORMAL_BOOT_MAX_BYTES ||
        fseek(fp, 0, SEEK_SET)) {
        fclose(fp);
        return -1;
    }
    payload_size = (uint32_t)len;
    flash_mem = malloc(ULX5M_FLASH_BYTES);
    if (!flash_mem) {
        fclose(fp);
        return -1;
    }
    memset(flash_mem, 0xff, ULX5M_FLASH_BYTES);
    header = flash_mem + ULX5M_NORMAL_BOOT_SLOT;
    payload = header + 256u;
    size_t read_bytes = fread(payload, 1, payload_size, fp);
    int close_status = fclose(fp);
    if (read_bytes != payload_size || close_status)
        return -1;
    if (memcmp(payload, "\xd9\x01\xed\x96", 4) != 0)
        return -1;
    memset(header, 0, 32);
    memcpy(header, "U5IM", 4);
    put32(header + 4, 1);
    put32(header + 8, 1);
    put32(header + 12, 256);
    put32(header + 16, payload_size);
    put32(header + 20, crc32(payload, payload_size));
    put32(header + 24, crc32(header, 32));
    return 0;
}

static void reset_counters(void)
{
    reads = sent = prepares = finishes = aborts = 0;
    payload_start_reads = 0;
}

int main(int argc, char **argv)
{
    struct ulx5m_normal_image_reader reader = {0, read_flash};
    struct ulx5m_normal_boot_transport transport = {
        0, prepare, send_byte, finish, abort_stream
    };
    uint32_t original_crc;
    if (argc != 2 || load_candidate(argv[1])) {
        fputs("[FAIL] Expected a bounded raw GateMate .bit fixture\n", stderr);
        free(flash_mem);
        return 1;
    }

    /* The candidate cannot arm itself, regardless of U5IM integrity. */
    if (ulx5m_normal_boot_run(&reader, &transport, 0, 0) !=
            ULX5M_BOOT_VALID_BLOCKED || prepares || sent || finishes) {
        fputs("[FAIL] Unapproved candidate authorized a stream\n", stderr);
        return 1;
    }
    puts("[PASS] Full-size candidate remains blocked without authorization");

    reset_counters();
    if (ulx5m_normal_boot_run(&reader, &transport, 0, 1) !=
            ULX5M_BOOT_STREAM_COMPLETE || prepares != 1 ||
            sent != payload_size || finishes != 1 || aborts) {
        fputs("[FAIL] Actual application payload not streamed exactly\n", stderr);
        return 1;
    }
    printf("[PASS] %u application bytes validated and delivered in order\n",
           payload_size);

    /* Corrupt a byte only on the second flash pass; abort instead of FINISH. */
    reset_counters();
    original_crc = crc32(payload, payload_size);
    drift_after_validation = 1;
    if (ulx5m_normal_boot_run(&reader, &transport, 0, 1) !=
            ULX5M_BOOT_STREAM_ERROR || prepares != 1 ||
            sent != payload_size || finishes || aborts != 1 ||
            crc32(payload, payload_size) == original_crc) {
        fputs("[FAIL] Changed payload did not block FINISH\n", stderr);
        return 1;
    }
    puts("[PASS] Changed full-size payload aborts before FINISH");

    free(flash_mem);
    return 0;
}
