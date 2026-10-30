/* Fail-closed flash image programming state machine.
 * This module has no MMIO. Production denies begin() outright. Host mock
 * and isolated hardware test builds can supply callbacks.
 */
#include "ulx5m_flash_program.h"

#if defined(ULX5M_FLASH_HW_TEST) && \
    !((defined(__riscv) && defined(ULX5M_DFU_HW_TEST_ONLY)) || \
      defined(ULX5M_FLASH_HW_HOST_TEST))
#error "Hardware flash writes require isolated experimental build"
#endif

#if defined(__riscv) && defined(ULX5M_FLASH_HW_HOST_TEST)
#error "Hardware MMIO host simulation is forbidden in FPGA firmware"
#endif

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
#if !defined(ULX5M_FLASH_PROGRAM_EMULATOR_TEST) && !defined(ULX5M_FLASH_HW_TEST)
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
#ifdef ULX5M_DFU_FULL_IMAGE_TEST
    /* Packed GateMate images have this four-byte synchronization prefix. */
    if (size < ULX5M_FLASH_PAGE_BYTES)
        return fail(s, ULX5M_PROGRAM_FORMAT);
#endif
#ifdef ULX5M_FLASH_HW_TEST
#if defined(ULX5M_DFU_FULL_IMAGE_TEST)
    /* Exclusive 0x201000..0x3fffff update window, no 4 KiB test limit. */
#elif defined(ULX5M_FLASH_HW_NATIVE_SLOT_TEST)
    if (size > ULX5M_FLASH_ERASE_BYTES)
        return fail(s, ULX5M_PROGRAM_RANGE);
#elif defined(ULX5M_FLASH_HW_QUAD_TEST)
    if (size > 4u * ULX5M_FLASH_ERASE_BYTES)
        return fail(s, ULX5M_PROGRAM_RANGE);
#elif defined(ULX5M_FLASH_HW_MULTI_TEST)
    if (size > 2u * ULX5M_FLASH_ERASE_BYTES)
        return fail(s, ULX5M_PROGRAM_RANGE);
#else
    if (size > ULX5M_FLASH_ERASE_BYTES)
        return fail(s, ULX5M_PROGRAM_RANGE);
#endif
#endif
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
#ifdef ULX5M_DFU_FULL_IMAGE_TEST
    if (offset == 0u) {
        static const uint8_t sync[4] = {0xd9u, 0x01u, 0xedu, 0x96u};
        if (len < sizeof(sync))
            return fail(s, ULX5M_PROGRAM_FORMAT);
        for (unsigned i = 0; i < sizeof(sync); ++i)
            if (data[i] != sync[i])
                return fail(s, ULX5M_PROGRAM_FORMAT);
    }
#endif

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

#ifdef ULX5M_DFU_FULL_IMAGE_TEST
    /* Remove stale commands from a previously longer secondary. Only
     * sectors strictly after the newly written image are considered.
     * The final image sector was already erased by flush_page(). */
    uint32_t tail = (ULX5M_FLASH_CANDIDATE_START + s->image_size +
                     ULX5M_FLASH_ERASE_BYTES - 1u) &
                    ~(ULX5M_FLASH_ERASE_BYTES - 1u);
    for (; tail < ULX5M_FLASH_BYTES; tail += ULX5M_FLASH_ERASE_BYTES) {
        unsigned dirty = 0;
        for (unsigned offset = 0; offset < ULX5M_FLASH_ERASE_BYTES;
             offset += ULX5M_FLASH_PAGE_BYTES) {
            if (s->ops.read_bytes(s->ops.ctx, tail + offset, s->verified,
                                  ULX5M_FLASH_PAGE_BYTES) != 0)
                return fail(s, ULX5M_PROGRAM_IO);
            for (unsigned i = 0; i < ULX5M_FLASH_PAGE_BYTES; ++i)
                if (s->verified[i] != 0xffu)
                    dirty = 1;
        }
        if (!dirty)
            continue;
        if (s->ops.erase_sector(s->ops.ctx, tail) != 0)
            return fail(s, ULX5M_PROGRAM_IO);
        for (unsigned offset = 0; offset < ULX5M_FLASH_ERASE_BYTES;
             offset += ULX5M_FLASH_PAGE_BYTES) {
            if (s->ops.read_bytes(s->ops.ctx, tail + offset, s->verified,
                                  ULX5M_FLASH_PAGE_BYTES) != 0)
                return fail(s, ULX5M_PROGRAM_IO);
            for (unsigned i = 0; i < ULX5M_FLASH_PAGE_BYTES; ++i)
                if (s->verified[i] != 0xffu)
                    return fail(s, ULX5M_PROGRAM_VERIFY);
        }
    }
#endif

    /* No automatic activation: only a subsequent normal-mode cold boot
     * invokes the existing independent configuration controller. An
     * interrupted in-place update must be recovered using BTN2 DFU. */
    s->active = 0;
    s->finalized = 1;
    return ULX5M_PROGRAM_OK;
}
