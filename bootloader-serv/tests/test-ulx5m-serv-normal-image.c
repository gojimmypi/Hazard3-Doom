/* Native-only U5IM candidate-image parser tests. Never touches hardware. */
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "ulx5m_normal_image.h"
#include "ulx5m_flash_layout.h"
#include "ulx5m-at25ql321-mock.h"

static struct ulx5m_spi_mock mock;
static struct ulx5m_at25ql321 dev;
static struct ulx5m_normal_image_info info;
static const uint32_t base = ULX5M_NORMAL_IMAGE_CANDIDATE_MIN;
static const uint32_t offset = ULX5M_FLASH_PAGE_BYTES;
static unsigned fail_reads, read_calls;

static uint32_t crc32(const uint8_t *data, unsigned len)
{
    uint32_t result = ~0u;
    for (unsigned i = 0; i < len; ++i) {
        result ^= data[i];
        for (unsigned j = 0; j < 8; ++j)
            result = (result >> 1) ^ ((result & 1u) ? 0xedb88320u : 0u);
    }
    return ~result;
}

static void put32(uint8_t *p, uint32_t value)
{
    for (unsigned i = 0; i < 4; ++i)
        p[i] = (uint8_t)(value >> (8u * i));
}

static int reader(void *ctx, uint32_t address, uint8_t *buf, unsigned len)
{
    ++read_calls;
    if (fail_reads && read_calls == fail_reads)
        return -1;
    if (len > ULX5M_FLASH_PAGE_BYTES)
        return -1;
    return ulx5m_at25ql321_read(ctx, address, buf, len) == ULX5M_AT25_OK ? 0 : -1;
}

static struct ulx5m_normal_image_reader source = {
    .ctx = &dev, .read = reader
};

static enum ulx5m_normal_image_result probe(uint32_t address)
{
    read_calls = 0;
    return ulx5m_normal_image_probe(&source, address, &info);
}

static void create_image(unsigned len)
{
    uint8_t *header = mock.memory + base;
    uint8_t *data = header + offset;
    memset(header, 0xff, 4096);
    memset(header, 0, ULX5M_NORMAL_IMAGE_HEADER_BYTES);
    memcpy(header, "U5IM", 4);
    put32(header + 4, 1);
    put32(header + 8, ULX5M_NORMAL_IMAGE_GATEMATE);
    put32(header + 12, offset);
    put32(header + 16, len);
    for (unsigned i = 0; i < len; ++i)
        data[i] = (uint8_t)(i * 13u + 7u);
    memcpy(data, "\xd9\x01\xed\x96", 4);
    put32(header + 20, crc32(data, len));
    put32(header + 24, crc32(header, ULX5M_NORMAL_IMAGE_HEADER_BYTES));
}

static void reseal_header(void)
{
    uint8_t *header = mock.memory + base;
    put32(header + 24, 0);
    put32(header + 24, crc32(header, ULX5M_NORMAL_IMAGE_HEADER_BYTES));
}

int main(void)
{
    uint8_t id[3];
    ulx5m_spi_mock_init(&mock);
    struct ulx5m_at25ql321_bus bus = ulx5m_spi_mock_bus(&mock);
    ulx5m_at25ql321_init(&dev, &bus);
    assert(ulx5m_at25ql321_identify(&dev, id) == ULX5M_AT25_OK);
    assert(probe(base) == ULX5M_NORMAL_IMAGE_ABSENT);
    assert(info.payload_bytes == 0);
    assert(probe(0) == ULX5M_NORMAL_IMAGE_BAD_RANGE);
    assert(probe(base + 1) == ULX5M_NORMAL_IMAGE_BAD_RANGE);
    assert(probe(ULX5M_FLASH_BYTES) == ULX5M_NORMAL_IMAGE_BAD_RANGE);
    assert(ulx5m_normal_image_probe(0, base, &info) == ULX5M_NORMAL_IMAGE_IO_ERROR);
    assert(ulx5m_normal_image_probe(&source, base, 0) == ULX5M_NORMAL_IMAGE_IO_ERROR);
    puts("[PASS] Empty flash, arguments and flash bounds rejected");

    create_image(1000);
    assert(probe(base) == ULX5M_NORMAL_IMAGE_INTEGRITY_OK);
    assert(info.header_address == base && info.payload_address == base + offset);
    assert(info.payload_bytes == 1000);
    assert(mock.reads >= 2 && mock.write_enables == 0 && mock.erases == 0 &&
           mock.pages == 0 && mock.write_disables == 0);
    puts("[PASS] U5IM header and streamed payload CRC, read-only SPI 0x03");

    mock.memory[base + offset + 999] ^= 1;
    assert(probe(base) == ULX5M_NORMAL_IMAGE_BAD_PAYLOAD);
    create_image(1000);
    mock.memory[base + offset] ^= 1;
    assert(probe(base) == ULX5M_NORMAL_IMAGE_BAD_PAYLOAD);
    create_image(1000);
    mock.memory[base + 24] ^= 1;
    assert(probe(base) == ULX5M_NORMAL_IMAGE_BAD_HEADER);
    puts("[PASS] Payload corruption, GateMate signature and header CRC rejected");

    create_image(1000);
    put32(mock.memory + base + 4, 2);
    reseal_header();
    assert(probe(base) == ULX5M_NORMAL_IMAGE_BAD_HEADER);
    create_image(1000);
    put32(mock.memory + base + 8, 2);
    reseal_header();
    assert(probe(base) == ULX5M_NORMAL_IMAGE_BAD_HEADER);
    create_image(1000);
    put32(mock.memory + base + 28, 1);
    reseal_header();
    assert(probe(base) == ULX5M_NORMAL_IMAGE_BAD_HEADER);
    puts("[PASS] Unknown header version/type and nonzero flags rejected");

    create_image(1000);
    put32(mock.memory + base + 12, 0);
    reseal_header();
    assert(probe(base) == ULX5M_NORMAL_IMAGE_BAD_RANGE);
    create_image(1000);
    put32(mock.memory + base + 12, 257);
    reseal_header();
    assert(probe(base) == ULX5M_NORMAL_IMAGE_BAD_RANGE);
    create_image(1000);
    put32(mock.memory + base + 16, 0);
    reseal_header();
    assert(probe(base) == ULX5M_NORMAL_IMAGE_BAD_RANGE);
    create_image(1000);
    put32(mock.memory + base + 16, 0xffffffffu);
    reseal_header();
    assert(probe(base) == ULX5M_NORMAL_IMAGE_BAD_RANGE);
    create_image(1000);
    put32(mock.memory + base + 12, 0xffffff00u);
    reseal_header();
    assert(probe(base) == ULX5M_NORMAL_IMAGE_BAD_RANGE);
    puts("[PASS] Overlaps, alignment errors and arithmetic overflow rejected");

    create_image(1000);
    fail_reads = 1;
    assert(probe(base) == ULX5M_NORMAL_IMAGE_IO_ERROR);
    fail_reads = 3;
    assert(probe(base) == ULX5M_NORMAL_IMAGE_IO_ERROR);
    fail_reads = 0;
    assert(probe(base) == ULX5M_NORMAL_IMAGE_INTEGRITY_OK);
    assert(!mock.write_enables && !mock.erases && !mock.pages && !mock.bad_command);
    puts("[PASS] Read errors fail closed; no SPI write commands issued");
    return 0;
}
