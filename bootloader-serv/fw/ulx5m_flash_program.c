/* Fail-closed flash image programming state machine.
 * This module has NO MMIO and NO SPI hardware driver. Its callbacks are
 * implemented by the host flash emulator only. Normal firmware builds
 * reject begin() before invoking any callback or changing flash state.
 */
#include "ulx5m_flash_program.h"

#if defined(__riscv) && defined(ULX5M_FLASH_PROGRAM_EMULATOR_TEST)
#error "Flash emulator authorization must never be built for RISC-V hardware"
#endif

static enum ulx5m_flash_program_result
fail(struct ulx5m_flash_program *s, enum ulx5m_flash_program_result result)
{
    s->result = result;
    s->active = 0;
    return result;
}

static uint32_t crc_byte(uint32_t crc, uint8_t value)
{
    crc ^= value;
    for (unsigned bit = 0; bit < 8; ++bit)
        crc = (crc >> 1) ^ ((crc & 1u) ? 0xedb88320u : 0u);
    return crc;
}

static enum ulx5m_flash_program_result
flush_page(struct ulx5m_flash_program *s)
{
    if (!s->pending_length)
        return ULX5M_PROGRAM_OK;

    const uint32_t address = s->next_page_address;
    if (address < ULX5M_FLASH_CANDIDATE_START ||
        address >= ULX5M_FLASH_BYTES ||
        s->pending_length > ULX5M_FLASH_PAGE_BYTES ||
        s->pending_length > ULX5M_FLASH_BYTES - address)
        return fail(s, ULX5M_PROGRAM_RANGE);

    if (address == s->next_sector_address) {
        if (s->ops.erase_sector(s->ops.ctx, address) != 0)
            return fail(s, ULX5M_PROGRAM_IO);
        s->next_sector_address += ULX5M_FLASH_ERASE_BYTES;
    }

    if (s->ops.program_page(s->ops.ctx, address, s->pending,
                            s->pending_length) != 0)
        return fail(s, ULX5M_PROGRAM_IO);
    if (s->ops.read_bytes(s->ops.ctx, address, s->verified,
                          s->pending_length) != 0)
        return fail(s, ULX5M_PROGRAM_IO);
    for (unsigned i = 0; i < s->pending_length; ++i) {
        if (s->pending[i] != s->verified[i])
            return fail(s, ULX5M_PROGRAM_VERIFY);
    }

    s->next_page_address += ULX5M_FLASH_PAGE_BYTES;
    s->pending_length = 0;
    return ULX5M_PROGRAM_OK;
}

enum ulx5m_flash_program_result
ulx5m_flash_program_begin(struct ulx5m_flash_program *s,
                          const struct ulx5m_flash_program_ops *ops,
                          uint32_t size, uint32_t crc)
{
    if (!s)
        return ULX5M_PROGRAM_STATE;
    s->active = 0;
    s->finalized = 0;
    s->result = ULX5M_PROGRAM_DENIED;
#ifndef ULX5M_FLASH_PROGRAM_EMULATOR_TEST
    /* FLM1 still reports zero writable regions. Even providing a valid
     * backend does not allow the production module to touch any flash. */
    (void)ops;
    (void)size;
    (void)crc;
    return s->result;
#else
    if (!ops || !ops->erase_sector || !ops->program_page || !ops->read_bytes)
        return fail(s, ULX5M_PROGRAM_STATE);
    if (!size || size > ULX5M_FLASH_CANDIDATE_BYTES)
        return fail(s, ULX5M_PROGRAM_RANGE);
    s->ops = *ops;
    s->image_size = size;
    s->expected_crc32 = crc;
    s->received = 0;
    s->running_crc = 0xffffffffu;
    s->next_page_address = ULX5M_FLASH_CANDIDATE_START;
    s->next_sector_address = ULX5M_FLASH_CANDIDATE_START;
    s->pending_length = 0;
    s->active = 1;
    s->result = ULX5M_PROGRAM_OK;
    return ULX5M_PROGRAM_OK;
#endif
}

enum ulx5m_flash_program_result
ulx5m_flash_program_feed(struct ulx5m_flash_program *s,
                         uint32_t offset, const uint8_t *data, unsigned len)
{
    if (!s || !s->active || s->finalized)
        return s ? fail(s, ULX5M_PROGRAM_STATE) : ULX5M_PROGRAM_STATE;
    if (!data || !len || len > ULX5M_FLASH_STREAM_BLOCK_BYTES ||
        offset != s->received)
        return fail(s, ULX5M_PROGRAM_ORDER);
    if (len > s->image_size - s->received)
        return fail(s, ULX5M_PROGRAM_RANGE);

    for (unsigned i = 0; i < len; ++i) {
        s->pending[s->pending_length++] = data[i];
        s->running_crc = crc_byte(s->running_crc, data[i]);
        s->received++;
        if (s->pending_length == ULX5M_FLASH_PAGE_BYTES) {
            enum ulx5m_flash_program_result result = flush_page(s);
            if (result != ULX5M_PROGRAM_OK)
                return result;
        }
    }
    return ULX5M_PROGRAM_OK;
}

enum ulx5m_flash_program_result
ulx5m_flash_program_finish(struct ulx5m_flash_program *s)
{
    if (!s || !s->active || s->finalized)
        return s ? fail(s, ULX5M_PROGRAM_STATE) : ULX5M_PROGRAM_STATE;
    if (s->received != s->image_size)
        return fail(s, ULX5M_PROGRAM_STATE);
    if ((s->running_crc ^ 0xffffffffu) != s->expected_crc32)
        return fail(s, ULX5M_PROGRAM_CRC);

    enum ulx5m_flash_program_result result = flush_page(s);
    if (result != ULX5M_PROGRAM_OK)
        return result;

    /* Independent final readback catches changes after per-page verification. */
    uint32_t readback_crc = 0xffffffffu;
    for (uint32_t offset = 0; offset < s->image_size;) {
        unsigned chunk = s->image_size - offset;
        if (chunk > ULX5M_FLASH_PAGE_BYTES)
            chunk = ULX5M_FLASH_PAGE_BYTES;
        if (s->ops.read_bytes(s->ops.ctx,
                              ULX5M_FLASH_CANDIDATE_START + offset,
                              s->verified, chunk) != 0)
            return fail(s, ULX5M_PROGRAM_IO);
        for (unsigned i = 0; i < chunk; ++i)
            readback_crc = crc_byte(readback_crc, s->verified[i]);
        offset += chunk;
    }
    if ((readback_crc ^ 0xffffffffu) != s->expected_crc32)
        return fail(s, ULX5M_PROGRAM_VERIFY);

    /* The image has never been marked bootable. The eventual commit and
     * boot selection must be a separate, validated recovery-aware step. */
    s->active = 0;
    s->finalized = 1;
    return ULX5M_PROGRAM_OK;
}
