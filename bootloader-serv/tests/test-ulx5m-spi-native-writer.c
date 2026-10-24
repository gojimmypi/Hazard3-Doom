/* Native-host only mock NOR flash. No SPI MMIO or USB dependencies. */
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ulx5m_spi_native_writer.h"

static uint8_t flash[ULX5M_FLASH_BYTES];
static uint8_t image[ULX5M_SPI_NATIVE_CAPACITY];
static unsigned erases, pages, reads;
static int fail_page, fail_read, corrupt_write;

static int mock_erase(void *ctx, uint32_t addr)
{
    (void)ctx;
    assert(addr >= ULX5M_SPI_NATIVE_ENTRY);
    assert(addr <= ULX5M_FLASH_BYTES - ULX5M_FLASH_ERASE_BYTES);
    assert((addr % ULX5M_FLASH_ERASE_BYTES) == 0);
    ++erases;
    memset(flash + addr, 0xff, ULX5M_FLASH_ERASE_BYTES);
    return 0;
}

static int mock_page(void *ctx, uint32_t addr, const uint8_t *data, unsigned len)
{
    (void)ctx;
    assert(addr >= ULX5M_SPI_NATIVE_ENTRY);
    assert(addr < ULX5M_FLASH_BYTES && len <= ULX5M_FLASH_BYTES - addr);
    assert(!(addr % ULX5M_FLASH_PAGE_BYTES));
    assert(len > 0 && len <= ULX5M_FLASH_PAGE_BYTES);
    if (fail_page)
        return -1;
    for (unsigned i = 0; i < len; i++) {
        if ((flash[addr+i] & data[i]) != data[i])
            return -1;
        flash[addr+i] &= data[i];
    }
    ++pages;
    if (corrupt_write)
        flash[addr] ^= 1;
    return 0;
}

static int mock_read(void *ctx, uint32_t addr, uint8_t *dst, unsigned len)
{
    (void)ctx;
    assert(addr >= ULX5M_SPI_NATIVE_ENTRY);
    assert(addr < ULX5M_FLASH_BYTES && len <= ULX5M_FLASH_BYTES - addr);
    if (fail_read)
        return -1;
    ++reads;
    memcpy(dst, flash + addr, len);
    return 0;
}

static struct ulx5m_flash_program_ops backend(void)
{
    struct ulx5m_flash_program_ops ops = {
        .ctx = NULL, .erase_sector = mock_erase,
        .program_page = mock_page, .read_bytes = mock_read
    };
    return ops;
}

static uint32_t crc32(const uint8_t *bytes, size_t len)
{
    uint32_t crc = 0xffffffffu;
    for (size_t i = 0; i < len; ++i) {
        crc ^= bytes[i];
        for (unsigned b = 0; b < 8; ++b)
            crc = (crc >> 1) ^ ((crc & 1u) ? 0xedb88320u : 0u);
    }
    return crc ^ 0xffffffffu;
}

static void clear_mock(void)
{
    memset(flash, 0xa5, ULX5M_SPI_NATIVE_ENTRY);
    memset(flash + ULX5M_SPI_NATIVE_ENTRY, 0xff, ULX5M_SPI_NATIVE_CAPACITY);
    erases = pages = reads = 0;
    fail_page = fail_read = corrupt_write = 0;
}

static void check_protected(void)
{
    for (unsigned i = 0; i < ULX5M_SPI_NATIVE_ENTRY; ++i)
        assert(flash[i] == 0xa5);
}

#ifdef ULX5M_SPI_NATIVE_WRITER_HOST_TEST
static enum ulx5m_flash_program_result
feed(struct ulx5m_spi_native_writer *w, const uint8_t *data, unsigned size)
{
    for (unsigned i = 0; i < size; i += 64) {
        unsigned n = size - i < 64 ? size - i : 64;
        enum ulx5m_flash_program_result r =
            ulx5m_spi_native_writer_feed(w, i, data + i, n);
        if (r != ULX5M_PROGRAM_OK)
            return r;
    }
    return ULX5M_PROGRAM_OK;
}

#endif

static unsigned read_fixture(const char *file)
{
    FILE *f = fopen(file, "rb");
    assert(f != NULL);
    size_t n = fread(image, 1, sizeof(image), f);
    assert(!ferror(f));
    assert(fgetc(f) == EOF);
    assert(fclose(f) == 0);
    assert(n == 3026);
    assert(image[0] == 0xd9 && image[1] == 0x01 &&
           image[2] == 0xed && image[3] == 0x96);
    return (unsigned)n;
}

int main(int argc, char **argv)
{
    assert(argc == 2);
    const unsigned bytes = read_fixture(argv[1]);
    struct ulx5m_spi_native_writer w = {0};
    struct ulx5m_flash_program_ops ops = backend();
    const uint32_t crc = crc32(image, bytes);

#ifndef ULX5M_SPI_NATIVE_WRITER_HOST_TEST
    clear_mock();
    assert(ulx5m_spi_native_writer_begin(&w, &ops, bytes, crc) ==
           ULX5M_PROGRAM_DENIED);
    assert(!erases && !pages && !reads);
    check_protected();
    puts("[PASS] Production default denies programming, no callbacks");
#else
    clear_mock();
    assert(ulx5m_spi_native_writer_begin(&w, &ops, bytes, crc) ==
           ULX5M_PROGRAM_OK);
    assert(feed(&w, image, bytes) == ULX5M_PROGRAM_OK);
    assert(ulx5m_spi_native_writer_finish(&w) == ULX5M_PROGRAM_OK);
    assert(erases == 1 && pages == 12 && reads == 24);
    assert(memcmp(flash + ULX5M_SPI_NATIVE_ENTRY, image, bytes) == 0);
    check_protected();
    puts("[PASS] Exact 3026-byte GateMate image at 0x201000; metadata untouched");

    clear_mock();
    assert(ulx5m_spi_native_writer_begin(&w, &ops,
            ULX5M_SPI_NATIVE_CAPACITY + 1u, crc) == ULX5M_PROGRAM_RANGE);
    assert(ulx5m_spi_native_writer_begin(&w, &ops, 0, crc) ==
           ULX5M_PROGRAM_RANGE);
    assert(erases == 0 && pages == 0);
    puts("[PASS] Zero-length and overflow rejected without erasing");

    clear_mock();
    fail_page = 1;
    assert(ulx5m_spi_native_writer_begin(&w, &ops, bytes, crc) == ULX5M_PROGRAM_OK);
    assert(feed(&w, image, bytes) == ULX5M_PROGRAM_IO);
    assert(erases == 1 && pages == 0);
    check_protected();
    puts("[PASS] Page write fault aborts; first stage remains intact");

    clear_mock();
    fail_read = 1;
    assert(ulx5m_spi_native_writer_begin(&w, &ops, bytes, crc) == ULX5M_PROGRAM_OK);
    assert(feed(&w, image, bytes) == ULX5M_PROGRAM_IO);
    check_protected();
    puts("[PASS] Readback failure aborts; first stage remains intact");

    clear_mock();
    corrupt_write = 1;
    assert(ulx5m_spi_native_writer_begin(&w, &ops, bytes, crc) == ULX5M_PROGRAM_OK);
    assert(feed(&w, image, bytes) == ULX5M_PROGRAM_VERIFY);
    check_protected();
    puts("[PASS] Per-page verification catches corrupted write");

    clear_mock();
    assert(ulx5m_spi_native_writer_begin(&w, &ops, bytes, crc ^ 1u) ==
           ULX5M_PROGRAM_OK);
    assert(feed(&w, image, bytes) == ULX5M_PROGRAM_OK);
    assert(ulx5m_spi_native_writer_finish(&w) == ULX5M_PROGRAM_CRC);
    assert(pages == 11); /* 11 full pages written; 242-byte tail withheld. */
    check_protected();
    puts("[PASS] Bad final CRC rejects incomplete image; no metadata commit");

    clear_mock();
    assert(ulx5m_spi_native_writer_begin(&w, &ops, bytes, crc) == ULX5M_PROGRAM_OK);
    assert(ulx5m_spi_native_writer_feed(&w, 1, image, 64) ==
           ULX5M_PROGRAM_ORDER);
    assert(erases == 0 && pages == 0);
    check_protected();
    puts("[PASS] Out-of-order transfer rejected before erase");

    /* A large image traverses multiple 4 KiB sectors. */
    for (unsigned i = 0; i < 8193; ++i)
        image[i] = (uint8_t)(i * 13u + 7u);
    clear_mock();
    assert(ulx5m_spi_native_writer_begin(&w, &ops, 8193,
           crc32(image, 8193)) == ULX5M_PROGRAM_OK);
    assert(feed(&w, image, 8193) == ULX5M_PROGRAM_OK);
    assert(ulx5m_spi_native_writer_finish(&w) == ULX5M_PROGRAM_OK);
    assert(erases == 3 && pages == 33);
    check_protected();
    puts("[PASS] Three-sector image; first stage and U5IM metadata unchanged");

    /* Last allowed page ends exactly at 4 MiB; no wrap or outside writes. */
    for (unsigned i = 0; i < ULX5M_SPI_NATIVE_CAPACITY; ++i)
        image[i] = (uint8_t)(i * 29u + 11u);
    clear_mock();
    const unsigned capacity = ULX5M_SPI_NATIVE_CAPACITY;
    assert(ulx5m_spi_native_writer_begin(&w, &ops, capacity,
           crc32(image, capacity)) == ULX5M_PROGRAM_OK);
    assert(feed(&w, image, capacity) == ULX5M_PROGRAM_OK);
    assert(ulx5m_spi_native_writer_finish(&w) == ULX5M_PROGRAM_OK);
    assert(erases == capacity / ULX5M_FLASH_ERASE_BYTES);
    assert(pages == capacity / ULX5M_FLASH_PAGE_BYTES);
    check_protected();
    assert(memcmp(flash + ULX5M_SPI_NATIVE_ENTRY, image, capacity) == 0);
    puts("[PASS] Exact native-slot upper boundary; no protected-region changes");
#endif
    puts("[BLOCK] No USB integration, SPI hardware backend or boot authorization");
    return 0;
}
