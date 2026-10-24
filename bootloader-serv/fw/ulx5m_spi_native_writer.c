#include "ulx5m_spi_native_writer.h"

#if defined(__riscv) && (defined(ULX5M_SPI_NATIVE_WRITER_HOST_TEST) || \
                          defined(ULX5M_FLASH_PROGRAM_EMULATOR_TEST))
#error "Host-only SPI native writer must not be built for FPGA firmware"
#endif

#if defined(ULX5M_SPI_NATIVE_WRITER_HOST_TEST) && \
    !defined(ULX5M_FLASH_PROGRAM_EMULATOR_TEST)
#error "Host-only native writer requires host-only flash emulator"
#endif

#if defined(ULX5M_SPI_NATIVE_WRITER_HOST_TEST)
static int translate(uint32_t old_address, unsigned length,
                     unsigned alignment, uint32_t *physical)
{
    if (old_address < ULX5M_FLASH_CANDIDATE_START ||
        old_address >= ULX5M_FLASH_CANDIDATE_START + ULX5M_SPI_NATIVE_CAPACITY ||
        (old_address % alignment) != 0u ||
        !length || length > ULX5M_SPI_NATIVE_CAPACITY -
                             (old_address - ULX5M_FLASH_CANDIDATE_START))
        return -1;
    *physical = ULX5M_SPI_NATIVE_ENTRY +
                (old_address - ULX5M_FLASH_CANDIDATE_START);
    return 0;
}

static int erase_cb(void *context, uint32_t address)
{
    struct ulx5m_spi_native_writer *w = context;
    uint32_t physical;
    if (translate(address, ULX5M_FLASH_ERASE_BYTES,
                  ULX5M_FLASH_ERASE_BYTES, &physical))
        return -1;
    return w->physical_ops.erase_sector(w->physical_ops.ctx, physical);
}

static int program_cb(void *context, uint32_t address,
                      const uint8_t *data, unsigned length)
{
    struct ulx5m_spi_native_writer *w = context;
    uint32_t physical;
    if (length > ULX5M_FLASH_PAGE_BYTES ||
        translate(address, length, ULX5M_FLASH_PAGE_BYTES, &physical))
        return -1;
    return w->physical_ops.program_page(w->physical_ops.ctx,
                                        physical, data, length);
}

static int read_cb(void *context, uint32_t address,
                   uint8_t *data, unsigned length)
{
    struct ulx5m_spi_native_writer *w = context;
    uint32_t physical;
    if (length > ULX5M_FLASH_PAGE_BYTES ||
        translate(address, length, 1u, &physical))
        return -1;
    return w->physical_ops.read_bytes(w->physical_ops.ctx,
                                      physical, data, length);
}
#endif

enum ulx5m_flash_program_result
ulx5m_spi_native_writer_begin(struct ulx5m_spi_native_writer *w,
                              const struct ulx5m_flash_program_ops *physical,
                              uint32_t size, uint32_t crc32)
{
    if (!w)
        return ULX5M_PROGRAM_STATE;
    w->stream.active = 0;
    w->stream.finalized = 0;
    w->stream.result = ULX5M_PROGRAM_DENIED;
#if !defined(ULX5M_SPI_NATIVE_WRITER_HOST_TEST)
    (void)physical;
    (void)size;
    (void)crc32;
    return ULX5M_PROGRAM_DENIED;
#else
    if (!physical || !physical->erase_sector || !physical->program_page ||
        !physical->read_bytes)
        return ULX5M_PROGRAM_STATE;
    if (!size || size > ULX5M_SPI_NATIVE_CAPACITY)
        return ULX5M_PROGRAM_RANGE;
    w->physical_ops = *physical;
    struct ulx5m_flash_program_ops translated = {
        .ctx = w,
        .erase_sector = erase_cb,
        .program_page = program_cb,
        .read_bytes = read_cb
    };
    return ulx5m_flash_program_begin(&w->stream, &translated, size, crc32);
#endif
}

enum ulx5m_flash_program_result
ulx5m_spi_native_writer_feed(struct ulx5m_spi_native_writer *w,
                             uint32_t offset, const uint8_t *data,
                             unsigned size)
{
    if (!w)
        return ULX5M_PROGRAM_STATE;
    return ulx5m_flash_program_feed(&w->stream, offset, data, size);
}

enum ulx5m_flash_program_result
ulx5m_spi_native_writer_finish(struct ulx5m_spi_native_writer *w)
{
    if (!w)
        return ULX5M_PROGRAM_STATE;
    return ulx5m_flash_program_finish(&w->stream);
}
