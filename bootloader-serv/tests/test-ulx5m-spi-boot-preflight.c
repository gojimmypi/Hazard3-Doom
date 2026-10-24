/* Host integration tests: real U5IM parser, real walking-LED image. */
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ulx5m_spi_boot_preflight.h"
#include "ulx5m_flash_layout.h"

static uint8_t *flash;
static uint8_t *image;
static size_t image_bytes;
static unsigned reads;
static unsigned fail_on_read;

static uint32_t crc32(const uint8_t *buf, size_t len)
{
    uint32_t crc = 0xffffffffu;
    for (size_t i = 0; i < len; ++i) {
        crc ^= buf[i];
        for (unsigned b = 0; b < 8; ++b)
            crc = (crc >> 1) ^ ((crc & 1u) ? 0xedb88320u : 0u);
    }
    return ~crc;
}

static void put32(uint8_t *p, uint32_t v)
{
    for (unsigned i = 0; i < 4; ++i)
        p[i] = (uint8_t)(v >> (i * 8));
}

static int read_flash(void *ctx, uint32_t addr, uint8_t *data, unsigned n)
{
    (void)ctx;
    ++reads;
    if ((fail_on_read && reads == fail_on_read) ||
        !n || addr >= ULX5M_FLASH_BYTES || n > ULX5M_FLASH_BYTES - addr)
        return -1;
    memcpy(data, flash + addr, n);
    return 0;
}

static struct ulx5m_normal_image_reader reader = {NULL, read_flash};

static void install_synthetic(uint32_t offset)
{
    uint8_t *h = flash + ULX5M_SPI_BOOT_U5IM_ADDRESS;
    uint8_t *p = h + offset;
    assert(image_bytes <= ULX5M_FLASH_BYTES - ULX5M_SPI_BOOT_U5IM_ADDRESS - offset);
    memset(h, 0xff, 0x2000);
    memcpy(p, image, image_bytes);
    memset(h, 0, 32);
    memcpy(h, "U5IM", 4);
    put32(h + 4, 1);
    put32(h + 8, 1);
    put32(h + 12, offset);
    put32(h + 16, (uint32_t)image_bytes);
    put32(h + 20, crc32(p, image_bytes));
    put32(h + 24, crc32(h, 32));
}

static void clear_checks(void)
{
    reads = fail_on_read = 0;
}

static void expect(enum ulx5m_spi_boot_preflight_result expected, int btn2)
{
    struct ulx5m_normal_image_info info = {1, 2, 3, 4};
    enum ulx5m_spi_boot_preflight_result result =
        ulx5m_spi_boot_preflight(&reader, btn2, &info);
    assert(result == expected);
    if (result == ULX5M_SPI_BOOT_VALID_BUT_BLOCKED) {
        assert(info.header_address == ULX5M_SPI_BOOT_U5IM_ADDRESS);
        assert(info.payload_address == ULX5M_SPI_BOOT_NATIVE_ENTRY);
        assert(info.payload_bytes == image_bytes);
        assert(info.expected_crc32 == crc32(image, image_bytes));
    } else {
        assert(info.header_address == 0 && info.payload_address == 0);
        assert(info.payload_bytes == 0 && info.expected_crc32 == 0);
    }
}

int main(int argc, char **argv)
{
    FILE *f;
    long len;
    struct ulx5m_normal_image_info out = {1, 2, 3, 4};
    assert(argc == 2);
    f = fopen(argv[1], "rb");
    assert(f);
    assert(fseek(f, 0, SEEK_END) == 0);
    len = ftell(f);
    assert(len == 3026);
    rewind(f);
    image_bytes = (size_t)len;
    image = malloc(image_bytes);
    flash = malloc(ULX5M_FLASH_BYTES);
    assert(image && flash);
    assert(fread(image, 1, image_bytes, f) == image_bytes);
    assert(fclose(f) == 0);
    assert(memcmp(image, "\xd9\x01\xed\x96", 4) == 0);
    memset(flash, 0xff, ULX5M_FLASH_BYTES);

    clear_checks();
    expect(ULX5M_SPI_BOOT_STAY_DFU_BTN2, 1);
    assert(reads == 0);
    puts("[PASS] Latched BTN2 overrides all reads");

    clear_checks();
    expect(ULX5M_SPI_BOOT_STAY_DFU_ABSENT, 0);
    puts("[PASS] Erased/absent image stays DFU");

    install_synthetic(0x1000);
    clear_checks();
    expect(ULX5M_SPI_BOOT_STAY_DFU_BTN2, 1);
    assert(reads == 0);
    puts("[PASS] BTN2 overrides intact native image");

    clear_checks();
    expect(ULX5M_SPI_BOOT_VALID_BUT_BLOCKED, 0);
    assert(reads > 1);
    puts("[PASS] Real 3026-byte native image validated; handoff remains blocked");

    install_synthetic(0x100);
    clear_checks();
    expect(ULX5M_SPI_BOOT_STAY_DFU_WRONG_LAYOUT, 0);
    puts("[PASS] Valid legacy 0x100 U5IM rejected for native SPI entry");

    install_synthetic(0x1000);
    flash[ULX5M_SPI_BOOT_NATIVE_ENTRY + image_bytes - 1] ^= 1u;
    clear_checks();
    expect(ULX5M_SPI_BOOT_STAY_DFU_INVALID, 0);
    puts("[PASS] Payload corruption stays DFU");

    install_synthetic(0x1000);
    flash[ULX5M_SPI_BOOT_U5IM_ADDRESS + 16] ^= 1u;
    clear_checks();
    expect(ULX5M_SPI_BOOT_STAY_DFU_INVALID, 0);
    puts("[PASS] Header corruption stays DFU");

    install_synthetic(0x1000);
    clear_checks();
    fail_on_read = 4;
    expect(ULX5M_SPI_BOOT_STAY_DFU_INVALID, 0);
    puts("[PASS] SPI read fault stays DFU");

    clear_checks();
    assert(ulx5m_spi_boot_preflight(NULL, 0, &out) == ULX5M_SPI_BOOT_STAY_DFU_INVALID);
    assert(out.header_address == 0 && out.payload_bytes == 0);
    puts("[PASS] Missing reader fails closed");

    clear_checks();
    install_synthetic(0x1000);
    assert(ulx5m_spi_boot_preflight(&reader, 0, NULL) ==
           ULX5M_SPI_BOOT_VALID_BUT_BLOCKED);
    puts("[PASS] Null output does not authorize configuration");

    free(flash);
    free(image);
    puts("[BLOCK] No jump, reset, transport, JTAG or flash write operation");
    return 0;
}
