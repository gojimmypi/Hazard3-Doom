/* Inspect a provisional U5IM wrapper using bounded SPI-flash reads only.
 * No flash writes, GateMate reconfiguration, or boot authorization.
 */
#include "ulx5m_normal_image.h"
#include "ulx5m_flash_layout.h"

static uint32_t get32(const uint8_t *p)
{
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) |
           ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static uint32_t crc32_update(uint32_t crc, const uint8_t *buf, unsigned length)
{
    for (unsigned i = 0; i < length; ++i) {
        crc ^= buf[i];
        for (unsigned bit = 0; bit < 8; ++bit)
            crc = (crc >> 1) ^ ((crc & 1u) ? 0xedb88320u : 0u);
    }
    return crc;
}

static int safe_read(const struct ulx5m_normal_image_reader *reader,
                     uint32_t addr, uint8_t *out, unsigned length)
{
    if (!reader || !reader->read || !out || !length ||
        !ulx5m_flash_read_range_valid(addr, length))
        return -1;
    return reader->read(reader->ctx, addr, out, length);
}

enum ulx5m_normal_image_result
ulx5m_normal_image_probe(const struct ulx5m_normal_image_reader *reader,
                         uint32_t candidate_address,
                         struct ulx5m_normal_image_info *info)
{
    uint8_t header[ULX5M_NORMAL_IMAGE_HEADER_BYTES];
    uint8_t block[ULX5M_FLASH_PAGE_BYTES];
    uint32_t offset, length, payload_address, expected, crc;

    if (info) {
        info->header_address = 0u;
        info->payload_address = 0u;
        info->payload_bytes = 0u;
        info->expected_crc32 = 0u;
    }
    if (!reader || !reader->read || !info)
        return ULX5M_NORMAL_IMAGE_IO_ERROR;
    if (candidate_address < ULX5M_NORMAL_IMAGE_CANDIDATE_MIN ||
        (candidate_address % ULX5M_FLASH_ERASE_BYTES) != 0u ||
        !ulx5m_flash_read_range_valid(candidate_address, sizeof(header)))
        return ULX5M_NORMAL_IMAGE_BAD_RANGE;
    if (safe_read(reader, candidate_address, header, sizeof(header)))
        return ULX5M_NORMAL_IMAGE_IO_ERROR;

    /* Missing or erased header is not evidence of a bootable image. */
    if (header[0] != 'U' || header[1] != '5' ||
        header[2] != 'I' || header[3] != 'M')
        return ULX5M_NORMAL_IMAGE_ABSENT;

    /* 32-byte U5IM v1 header, all uint32 little-endian:
     * magic, version, type, payload offset, payload size, payload CRC32,
     * header CRC32 (zeroed when calculated), reserved=0.
     */
    if (get32(header + 4) != ULX5M_NORMAL_IMAGE_VERSION ||
        get32(header + 8) != ULX5M_NORMAL_IMAGE_GATEMATE ||
        get32(header + 28) != 0u)
        return ULX5M_NORMAL_IMAGE_BAD_HEADER;
    expected = get32(header + 24);
    for (unsigned i = 24; i < 28; ++i)
        header[i] = 0u;
    crc = ~crc32_update(~0u, header, sizeof(header));
    if (crc != expected)
        return ULX5M_NORMAL_IMAGE_BAD_HEADER;

    offset = get32(header + 12);
    length = get32(header + 16);
    if (offset < ULX5M_FLASH_PAGE_BYTES ||
        (offset % ULX5M_FLASH_PAGE_BYTES) != 0u || !length ||
        offset > ULX5M_FLASH_BYTES - candidate_address ||
        length > ULX5M_FLASH_BYTES - candidate_address - offset)
        return ULX5M_NORMAL_IMAGE_BAD_RANGE;
    payload_address = candidate_address + offset;
    expected = get32(header + 20);
    crc = ~0u;
    for (uint32_t done = 0; done < length;) {
        unsigned chunk = length - done > sizeof(block) ?
                         sizeof(block) : (unsigned)(length - done);
        if (safe_read(reader, payload_address + done, block, chunk))
            return ULX5M_NORMAL_IMAGE_IO_ERROR;
        /* This is only a GateMate sync-signature sanity check, NOT a
         * complete GateMate configuration-stream validation. */
        if (done == 0u && (chunk < 4u || block[0] != 0xd9u ||
                           block[1] != 0x01u || block[2] != 0xedu ||
                           block[3] != 0x96u))
            return ULX5M_NORMAL_IMAGE_BAD_PAYLOAD;
        crc = crc32_update(crc, block, chunk);
        done += chunk;
    }
    if (~crc != expected)
        return ULX5M_NORMAL_IMAGE_BAD_PAYLOAD;

    info->header_address = candidate_address;
    info->payload_address = payload_address;
    info->payload_bytes = length;
    info->expected_crc32 = expected;
    return ULX5M_NORMAL_IMAGE_INTEGRITY_OK;
}
