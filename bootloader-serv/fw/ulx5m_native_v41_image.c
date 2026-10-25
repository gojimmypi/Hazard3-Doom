/* Exact native v41 SPI slot qualification; no writer or config transport. */
#include "ulx5m_native_v41_image.h"

static uint32_t crc_update(uint32_t crc, const uint8_t *bytes, unsigned len)
{
    for (unsigned i = 0; i < len; ++i) {
        crc ^= bytes[i];
        for (unsigned bit = 0; bit < 8; ++bit)
            crc = (crc >> 1) ^ ((crc & 1u) ? 0xedb88320u : 0u);
    }
    return crc;
}

enum ulx5m_v41_probe_result
ulx5m_v41_native_probe(const struct ulx5m_normal_image_reader *reader,
                       int btn2_selected_latched, uint32_t *image_crc32)
{
    uint8_t page[256];
    uint32_t crc = ~0u;
    unsigned payload_read = 0;
    unsigned invalid = 0;

    if (image_crc32)
        *image_crc32 = 0;
    if (btn2_selected_latched)
        return ULX5M_V41_STAY_DFU_BTN2;
    if (!reader || !reader->read)
        return ULX5M_V41_BAD_READER;

    /* Read the entire existing sector, including the erased 1070-byte tail.
     * Do not stop early on malformed content: all reads stay in one sector.
     */
    for (unsigned offset = 0; offset < ULX5M_V41_NATIVE_SECTOR_BYTES;
         offset += sizeof(page)) {
        if (reader->read(reader->ctx, ULX5M_V41_NATIVE_ADDR + offset,
                         page, sizeof(page)))
            return ULX5M_V41_READ_ERROR;
        for (unsigned i = 0; i < sizeof(page); ++i) {
            unsigned pos = offset + i;
            if (pos < ULX5M_V41_NATIVE_BYTES) {
                if (pos < 4u) {
                    static const uint8_t sync[4] = {0xd9, 0x01, 0xed, 0x96};
                    if (page[i] != sync[pos])
                        invalid = 1;
                }
                crc = crc_update(crc, &page[i], 1);
                ++payload_read;
            } else if (page[i] != 0xffu) {
                invalid = 1;
            }
        }
    }
    crc = ~crc;
    if (payload_read != ULX5M_V41_NATIVE_BYTES ||
        crc != ULX5M_V41_NATIVE_CRC32 || invalid)
        return ULX5M_V41_INVALID_IMAGE;
    if (image_crc32)
        *image_crc32 = crc;
    return ULX5M_V41_VERIFIED_ONLY;
}
