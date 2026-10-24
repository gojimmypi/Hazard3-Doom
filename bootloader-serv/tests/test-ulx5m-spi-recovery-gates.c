/* v38 host-only negative test: a self-consistent U5IM is not proof of a bootable GateMate image. */
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ulx5m_spi_boot_preflight.h"
#include "ulx5m_flash_layout.h"

static uint8_t *flash_data;
static uint32_t image_length;

static uint32_t crc32_buf(const uint8_t *ptr, unsigned count)
{
    uint32_t crc = 0xffffffffu;
    for (unsigned i = 0; i < count; ++i) {
        crc ^= ptr[i];
        for (unsigned j = 0; j < 8; ++j)
            crc = (crc >> 1) ^ ((crc & 1u) ? 0xedb88320u : 0u);
    }
    return ~crc;
}

static void le32(uint8_t *dst, uint32_t value)
{
    for (unsigned i = 0; i < 4; ++i)
        dst[i] = (uint8_t)(value >> (8u * i));
}

static int reader_cb(void *ctx, uint32_t address, uint8_t *dst, unsigned count)
{
    (void)ctx;
    if (!count || address >= ULX5M_FLASH_BYTES ||
        count > ULX5M_FLASH_BYTES - address)
        return -1;
    memcpy(dst, flash_data + address, count);
    return 0;
}

static void reissue_header(uint8_t *h, uint8_t *payload)
{
    memset(h, 0, 32);
    memcpy(h, "U5IM", 4);
    le32(h + 4, 1);
    le32(h + 8, 1);
    le32(h + 12, 0x1000u);
    le32(h + 16, image_length);
    le32(h + 20, crc32_buf(payload, image_length));
    le32(h + 24, crc32_buf(h, 32));
}

int main(int argc, char **argv)
{
    FILE *input;
    struct ulx5m_normal_image_reader reader = {0, reader_cb};
    struct ulx5m_normal_image_info info;
    uint8_t *metadata, *payload;
    enum ulx5m_spi_boot_preflight_result code;

    if (argc != 2) return 2;
    input = fopen(argv[1], "rb");
    if (!input) return 2;
    if (fseek(input, 0, SEEK_END) || ftell(input) != 3026L ||
        fseek(input, 0, SEEK_SET)) return 2;
    image_length = 3026u;
    flash_data = malloc(ULX5M_FLASH_BYTES);
    if (!flash_data) return 2;
    memset(flash_data, 0xff, ULX5M_FLASH_BYTES);
    metadata = flash_data + ULX5M_SPI_BOOT_U5IM_ADDRESS;
    payload = flash_data + ULX5M_SPI_BOOT_NATIVE_ENTRY;
    if (fread(payload, 1, image_length, input) != image_length) return 2;
    fclose(input);
    assert(!memcmp(payload, "\xd9\x01\xed\x96", 4));
    reissue_header(metadata, payload);
    code = ulx5m_spi_boot_preflight(&reader, 0, &info);
    assert(code == ULX5M_SPI_BOOT_VALID_BUT_BLOCKED);
    puts("[PASS] Known JTAG-working image passes U5IM preflight, remains blocked");

    /* Change a byte without changing the GateMate sync word, then calculate
     * a NEW matching payload CRC32 and header CRC32. We deliberately do NOT
     * repair the internal configuration stream. The U5IM parser cannot know
     * that the native image is now different from the tested image.
     */
    payload[40] ^= 0x80u;
    reissue_header(metadata, payload);
    code = ulx5m_spi_boot_preflight(&reader, 0, &info);
    assert(code == ULX5M_SPI_BOOT_VALID_BUT_BLOCKED);
    puts("[PASS] Modified, re-CRC'd native image also passes U5IM; NOT proven bootable");

    code = ulx5m_spi_boot_preflight(&reader, 1, &info);
    assert(code == ULX5M_SPI_BOOT_STAY_DFU_BTN2);
    puts("[PASS] Latched BTN2 still overrides re-CRC'd candidate");
    free(flash_data);
    puts("[BLOCK] No hardware config, SPI jump, flash or JTAG operation");
    return 0;
}
