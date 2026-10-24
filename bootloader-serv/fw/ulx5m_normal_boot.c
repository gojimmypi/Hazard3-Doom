/* Fail-closed image selection and handoff transport, no flash mutations. */
#include "ulx5m_normal_boot.h"
#include "ulx5m_flash_layout.h"

/* Recheck the second flash pass. A successful U5IM probe proves what was
 * read then, not necessarily the bytes actually delivered to CFG_CTRL.
 * This detects changed payloads before FINISH, but cannot undo earlier
 * configuration bytes already accepted by GateMate.
 */
static uint32_t stream_crc32_update(uint32_t crc, const uint8_t *buf,
                                    unsigned length)
{
    for (unsigned i = 0; i < length; ++i) {
        crc ^= buf[i];
        for (unsigned bit = 0; bit < 8; ++bit)
            crc = (crc >> 1) ^ ((crc & 1u) ? 0xedb88320u : 0u);
    }
    return crc;
}

enum ulx5m_normal_boot_result
ulx5m_normal_boot_run(const struct ulx5m_normal_image_reader *reader,
                      const struct ulx5m_normal_boot_transport *transport,
                      int dfu_selected, int authorize_stream)
{
    struct ulx5m_normal_image_info info;
    uint8_t chunk[ULX5M_FLASH_PAGE_BYTES];
    enum ulx5m_normal_image_result probe;
    uint32_t streamed_crc = ~0u;
    if (dfu_selected)
        return ULX5M_BOOT_DFU_SELECTED;
    probe = ulx5m_normal_image_probe(reader, ULX5M_NORMAL_BOOT_SLOT, &info);
    if (probe == ULX5M_NORMAL_IMAGE_ABSENT)
        return ULX5M_BOOT_NO_IMAGE;
    if (probe != ULX5M_NORMAL_IMAGE_INTEGRITY_OK ||
        info.payload_bytes > ULX5M_NORMAL_BOOT_MAX_BYTES ||
        info.payload_address != ULX5M_NORMAL_BOOT_SLOT + 256u ||
        info.payload_bytes > ULX5M_FLASH_BYTES - info.payload_address)
        return ULX5M_BOOT_INVALID;
    if (!authorize_stream)
        return ULX5M_BOOT_VALID_BLOCKED;
    if (!transport || !transport->prepare || !transport->send ||
        !transport->finish || !transport->abort)
        return ULX5M_BOOT_STREAM_ERROR;
    if (transport->prepare(transport->ctx, info.payload_bytes)) {
        transport->abort(transport->ctx);
        return ULX5M_BOOT_STREAM_ERROR;
    }
    for (uint32_t pos = 0; pos < info.payload_bytes;) {
        unsigned n = info.payload_bytes - pos > sizeof(chunk) ?
                     sizeof(chunk) : (unsigned)(info.payload_bytes - pos);
        if (reader->read(reader->ctx, info.payload_address + pos, chunk, n)) {
            transport->abort(transport->ctx);
            return ULX5M_BOOT_STREAM_ERROR;
        }
        for (unsigned i = 0; i < n; ++i)
            if (transport->send(transport->ctx, chunk[i])) {
                transport->abort(transport->ctx);
                return ULX5M_BOOT_STREAM_ERROR;
            }
        streamed_crc = stream_crc32_update(streamed_crc, chunk, n);
        pos += n;
    }
    if (~streamed_crc != info.expected_crc32) {
        transport->abort(transport->ctx);
        return ULX5M_BOOT_STREAM_ERROR;
    }
    if (transport->finish(transport->ctx)) {
        transport->abort(transport->ctx);
        return ULX5M_BOOT_STREAM_ERROR;
    }
    return ULX5M_BOOT_STREAM_COMPLETE;
}
