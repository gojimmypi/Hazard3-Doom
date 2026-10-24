/* Native host acceptance for normal-mode image validation -> transport. */
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ulx5m_normal_boot.h"
#include "ulx5m_flash_layout.h"

static uint8_t *flash;
static unsigned calls, transmitted, aborts, prepares, finishes;
static int fail_read, fail_byte, mutate_after_probe;
static unsigned byte_index;

static uint32_t crc32(const uint8_t *data, size_t n)
{
    uint32_t crc = 0xffffffffu;
    for (size_t i = 0; i < n; ++i) {
        crc ^= data[i];
        for (unsigned j = 0; j < 8; ++j)
            crc = (crc >> 1) ^ ((crc & 1u) ? 0xedb88320u : 0);
    }
    return ~crc;
}
static void put32(uint8_t *dst, uint32_t value)
{
    for (unsigned i = 0; i < 4; ++i)
        dst[i] = (uint8_t)(value >> (i * 8));
}
static int reader(void *ctx, uint32_t addr, uint8_t *buf, unsigned n)
{
    (void)ctx;
    ++calls;
    if (fail_read && calls == (unsigned)fail_read)
        return -1;
    /* One header + four 256-byte CRC reads precede the streaming pass. */
    if (mutate_after_probe && calls == 6)
        flash[ULX5M_NORMAL_BOOT_SLOT + 256 + 800] ^= 1u;
    if (!n || addr >= ULX5M_FLASH_BYTES || n > ULX5M_FLASH_BYTES - addr)
        return -1;
    memcpy(buf, flash + addr, n);
    return 0;
}
static int prepare(void *ctx, uint32_t n)
{
    (void)ctx;
    assert(n == 1024);
    ++prepares;
    return 0;
}
static int send_byte(void *ctx, uint8_t byte)
{
    (void)ctx;
    if (fail_byte && byte_index == (unsigned)fail_byte)
        return -1;
    uint8_t expected = (uint8_t)(byte_index * 13u + 5u);
    if (byte_index < 4)
        expected = (const uint8_t[]){0xd9, 0x01, 0xed, 0x96}[byte_index];
    if (mutate_after_probe && byte_index == 800)
        expected ^= 1u;
    assert(byte == expected);
    ++byte_index;
    ++transmitted;
    return 0;
}
static int finish(void *ctx) { (void)ctx; ++finishes; return 0; }
static void abort_stream(void *ctx) { (void)ctx; ++aborts; }
static struct ulx5m_normal_image_reader r = {0, reader};
static struct ulx5m_normal_boot_transport t = {
    0, prepare, send_byte, finish, abort_stream
};
static void clear_state(void)
{
    calls = transmitted = aborts = prepares = finishes = byte_index = 0;
    fail_read = fail_byte = mutate_after_probe = 0;
}
static void valid_image(void)
{
    uint8_t *h = flash + ULX5M_NORMAL_BOOT_SLOT;
    uint8_t *p = h + 256;
    memset(h, 0xff, 4096);
    memset(h, 0, 32);
    memcpy(h, "U5IM", 4);
    put32(h + 4, 1);
    put32(h + 8, 1);
    put32(h + 12, 256);
    put32(h + 16, 1024);
    for (unsigned i = 0; i < 1024; ++i)
        p[i] = (uint8_t)(i * 13u + 5u);
    memcpy(p, "\xd9\x01\xed\x96", 4);
    put32(h + 20, crc32(p, 1024));
    put32(h + 24, crc32(h, 32));
}
int main(void)
{
    flash = malloc(ULX5M_FLASH_BYTES);
    assert(flash);
    memset(flash, 0xff, ULX5M_FLASH_BYTES);
    clear_state();
    assert(ulx5m_normal_boot_run(&r, &t, 1, 1) == ULX5M_BOOT_DFU_SELECTED);
    assert(calls == 0 && prepares == 0);
    assert(ulx5m_normal_boot_run(&r, &t, 0, 1) == ULX5M_BOOT_NO_IMAGE);
    assert(prepares == 0);
    puts("[PASS] DFU path isolated; absent candidate cannot hand off");

    clear_state();
    valid_image();
    assert(ulx5m_normal_boot_run(&r, &t, 0, 0) == ULX5M_BOOT_VALID_BLOCKED);
    assert(prepares == 0 && transmitted == 0 && finishes == 0);
    puts("[PASS] Valid U5IM cannot authorize its own configuration");

    clear_state();
    flash[ULX5M_NORMAL_BOOT_SLOT + 256 + 800] ^= 1;
    assert(ulx5m_normal_boot_run(&r, &t, 0, 1) == ULX5M_BOOT_INVALID);
    assert(prepares == 0);
    puts("[PASS] Corrupted candidate blocked before stream");

    clear_state();
    valid_image();
    assert(ulx5m_normal_boot_run(&r, &t, 0, 1) == ULX5M_BOOT_STREAM_COMPLETE);
    assert(transmitted == 1024 && prepares == 1 && finishes == 1 && aborts == 0);
    puts("[PASS] Verified 1024-byte payload streamed in order");

    clear_state();
    mutate_after_probe = 1;
    assert(ulx5m_normal_boot_run(&r, &t, 0, 1) == ULX5M_BOOT_STREAM_ERROR);
    assert(prepares == 1 && transmitted == 1024 && finishes == 0 && aborts == 1);
    puts("[PASS] Changed payload during second flash pass rejects FINISH");

    clear_state();
    valid_image();
    fail_read = 8; // header + 4 CRC reads + 2 stream reads -> later stream read
    assert(ulx5m_normal_boot_run(&r, &t, 0, 1) == ULX5M_BOOT_STREAM_ERROR);
    assert(aborts == 1 && finishes == 0 && transmitted > 0);
    puts("[PASS] Read error after partial stream aborts");

    clear_state();
    fail_byte = 123;
    assert(ulx5m_normal_boot_run(&r, &t, 0, 1) == ULX5M_BOOT_STREAM_ERROR);
    assert(aborts == 1 && finishes == 0 && transmitted == 123);
    puts("[PASS] Transport error after partial stream aborts");

    clear_state();
    assert(ulx5m_normal_boot_run(&r, 0, 0, 1) == ULX5M_BOOT_STREAM_ERROR);
    assert(prepares == 0);
    puts("[PASS] Absent transport cannot stream");
    free(flash);
    return 0;
}
