/* Host-only AT25QL321 emulator: isolated candidate slot, NEVER hardware. */
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "ulx5m_flash_program.h"

static uint8_t flash_mem[ULX5M_FLASH_BYTES];
static unsigned erases, writes, reads;
static uint32_t fail_program_address;
static int corrupt_program;
static int fail_read;

static int erase_sector(void *ctx, uint32_t address)
{
    (void)ctx;
    if (address < ULX5M_FLASH_CANDIDATE_START ||
        (address % ULX5M_FLASH_ERASE_BYTES) != 0u ||
        address >= ULX5M_FLASH_BYTES)
        return -1;
    ++erases;
    memset(flash_mem + address, 0xff, ULX5M_FLASH_ERASE_BYTES);
    return 0;
}
static int program_page(void *ctx, uint32_t address,
                        const uint8_t *data, unsigned len)
{
    (void)ctx;
    if (address < ULX5M_FLASH_CANDIDATE_START ||
        (address % ULX5M_FLASH_PAGE_BYTES) != 0u ||
        !len || len > ULX5M_FLASH_PAGE_BYTES ||
        len > ULX5M_FLASH_BYTES - address ||
        address == fail_program_address)
        return -1;
    for (unsigned i = 0; i < len; ++i) {
        /* NOR program must never change a zero bit back into a one bit. */
        if ((flash_mem[address+i] & data[i]) != data[i])
            return -1;
    }
    ++writes;
    for (unsigned i = 0; i < len; ++i)
        flash_mem[address+i] &= data[i];
    if (corrupt_program)
        flash_mem[address] ^= 1u;
    return 0;
}
static int read_bytes(void *ctx, uint32_t address, uint8_t *out, unsigned len)
{
    (void)ctx;
    if (fail_read || address >= ULX5M_FLASH_BYTES ||
        len > ULX5M_FLASH_BYTES - address)
        return -1;
    ++reads;
    memcpy(out, flash_mem + address, len);
    return 0;
}
static struct ulx5m_flash_program_ops fake_ops(void)
{
    struct ulx5m_flash_program_ops ops = {
        .ctx = NULL, .erase_sector = erase_sector,
        .program_page = program_page, .read_bytes = read_bytes
    };
    return ops;
}
static uint32_t crc32(const uint8_t *p, unsigned len)
{
    uint32_t crc = 0xffffffffu;
    for (unsigned i = 0; i < len; ++i) {
        crc ^= p[i];
        for (unsigned k = 0; k < 8; ++k)
            crc = (crc >> 1) ^ ((crc & 1u) ? 0xedb88320u : 0);
    }
    return crc ^ 0xffffffffu;
}
static uint8_t pattern(unsigned i)
{
    return (uint8_t)((i * 31u + (i >> 7) + 0x56u) & 255u);
}
static void reset_flash(void)
{
    /* Mark golden/primary half as occupied. No test may touch it. */
    memset(flash_mem, 0xa5, ULX5M_FLASH_CANDIDATE_START);
    memset(flash_mem + ULX5M_FLASH_CANDIDATE_START, 0xff,
           ULX5M_FLASH_CANDIDATE_BYTES);
    erases = writes = reads = 0;
    fail_program_address = 0xffffffffu;
    corrupt_program = fail_read = 0;
}
static void check_primary(void)
{
    for (unsigned i = 0; i < ULX5M_FLASH_CANDIDATE_START; ++i)
        assert(flash_mem[i] == 0xa5);
}
static void send_image(struct ulx5m_flash_program *session,
                       const uint8_t *image, unsigned size)
{
    for (unsigned off = 0; off < size;) {
        unsigned len = size - off;
        if (len > 64u)
            len = 64u;
        assert(ulx5m_flash_program_feed(session, off, image+off, len) ==
               ULX5M_PROGRAM_OK);
        off += len;
    }
}
int main(void)
{
    static uint8_t image[ULX5M_FLASH_CANDIDATE_BYTES];
    struct ulx5m_flash_program session;
    struct ulx5m_flash_program_ops ops = fake_ops();
    for (unsigned i = 0; i < sizeof(image); ++i)
        image[i] = pattern(i);
    const uint32_t image_crc = crc32(image, sizeof(image));

    reset_flash();
    assert(ulx5m_flash_program_begin(&session, &ops, sizeof(image), image_crc)
           == ULX5M_PROGRAM_OK);
    send_image(&session, image, sizeof(image));
    assert(ulx5m_flash_program_finish(&session) == ULX5M_PROGRAM_OK);
    assert(session.finalized && !session.active);
    assert(erases == 512 && writes == 8192 && reads == 16384);
    assert(memcmp(flash_mem + ULX5M_FLASH_CANDIDATE_START,
                  image, sizeof(image)) == 0);
    check_primary();
    printf("[PASS] 2 MiB / 32768 blocks, 512 erases, 8192 pages, double readback, CRC32=%08x\n", image_crc);

    reset_flash();
    const unsigned partial = 419538u;
    assert(ulx5m_flash_program_begin(&session, &ops, partial,
                                     crc32(image, partial)) == ULX5M_PROGRAM_OK);
    send_image(&session, image, partial);
    assert(ulx5m_flash_program_finish(&session) == ULX5M_PROGRAM_OK);
    assert(erases == 103 && writes == 1639);
    assert(memcmp(flash_mem + ULX5M_FLASH_CANDIDATE_START, image, partial) == 0);
    assert(flash_mem[ULX5M_FLASH_CANDIDATE_START+partial] == 0xff);
    check_primary();
    puts("[PASS] 419538-byte bitstream, final partial page, golden half untouched");

    reset_flash();
    assert(ulx5m_flash_program_begin(&session, &ops, 64, image_crc) ==
           ULX5M_PROGRAM_OK);
    assert(ulx5m_flash_program_feed(&session, 0, image, 64) ==
           ULX5M_PROGRAM_OK);
    assert(ulx5m_flash_program_finish(&session) == ULX5M_PROGRAM_CRC);
    assert(!erases && !writes);
    check_primary();
    puts("[PASS] wrong expected CRC refuses final page; no boot commit");

    reset_flash();
    assert(ulx5m_flash_program_begin(&session, &ops, 256,
                                     crc32(image, 256)) == ULX5M_PROGRAM_OK);
    assert(ulx5m_flash_program_feed(&session, 64, image, 64) ==
           ULX5M_PROGRAM_ORDER);
    assert(ulx5m_flash_program_feed(&session, 0, image, 64) ==
           ULX5M_PROGRAM_STATE);
    assert(erases == 0 && writes == 0);
    puts("[PASS] out-of-order blocks latch error without touching flash");

    reset_flash();
    assert(ulx5m_flash_program_begin(&session, &ops, sizeof(image)+1u,
                                     0) == ULX5M_PROGRAM_RANGE);
    assert(!erases && !writes);
    puts("[PASS] oversized image rejected before erase");

    reset_flash();
    corrupt_program = 1;
    assert(ulx5m_flash_program_begin(&session, &ops, 256,
                                     crc32(image, 256)) == ULX5M_PROGRAM_OK);
    for (unsigned off = 0; off < 256; off += 64) {
        enum ulx5m_flash_program_result result =
            ulx5m_flash_program_feed(&session, off, image + off, 64);
        assert(result == ((off == 192) ? ULX5M_PROGRAM_VERIFY : ULX5M_PROGRAM_OK));
    }
    assert(!session.active && erases == 1 && writes == 1);
    puts("[PASS] immediate page-readback mismatch halts transaction");

    reset_flash();
    fail_program_address = ULX5M_FLASH_CANDIDATE_START;
    assert(ulx5m_flash_program_begin(&session, &ops, 256,
                                     crc32(image, 256)) == ULX5M_PROGRAM_OK);
    for (unsigned off = 0; off < 192; off += 64)
        assert(ulx5m_flash_program_feed(&session, off, image+off, 64) ==
               ULX5M_PROGRAM_OK);
    assert(ulx5m_flash_program_feed(&session, 192, image+192, 64) ==
           ULX5M_PROGRAM_IO);
    assert(!session.active && erases == 1 && writes == 0);
    puts("[PASS] page program I/O error stops update");

    reset_flash();
    fail_read = 1;
    assert(ulx5m_flash_program_begin(&session, &ops, 256,
                                     crc32(image, 256)) == ULX5M_PROGRAM_OK);
    for (unsigned off = 0; off < 192; off += 64)
        assert(ulx5m_flash_program_feed(&session, off, image+off, 64) ==
               ULX5M_PROGRAM_OK);
    assert(ulx5m_flash_program_feed(&session, 192, image+192, 64) ==
           ULX5M_PROGRAM_IO);
    puts("[PASS] readback transport failure stops update");

    reset_flash();
    assert(ulx5m_flash_program_begin(&session, &ops, 256,
                                     crc32(image, 256)) == ULX5M_PROGRAM_OK);
    for (unsigned off = 0; off < 256; off += 64)
        assert(ulx5m_flash_program_feed(&session, off, image+off, 64) ==
               ULX5M_PROGRAM_OK);
    flash_mem[ULX5M_FLASH_CANDIDATE_START+3] ^= 1u;
    assert(ulx5m_flash_program_finish(&session) == ULX5M_PROGRAM_VERIFY);
    puts("[PASS] final whole-image reread detects post-page corruption");
    return 0;
}
