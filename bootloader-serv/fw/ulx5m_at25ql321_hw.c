/* Read-only AT25QL321 adapter to the ULX5M-GS QSPI MMIO controller.
 * Mirrors the already hardware-proven 0x9f/0x03 flash diagnostic transport.
 */
#include "ulx5m_at25ql321_hw.h"

#ifdef ULX5M_AT25QL321_EMULATOR_TEST
#if !defined(ULX5M_AT25QL321_MMIO_HOST_TEST) || defined(__riscv)
#error "Emulator writes through MMIO are permitted only in native-host tests"
#endif
#endif

#if defined(ULX5M_AT25QL321_MMIO_HOST_TEST) && !defined(ULX5M_AT25QL321_EMULATOR_TEST)
#error "MMIO host test requires the AT25QL321 emulator"
#endif

#define SPI_CS_HIGH       0x00010f00u
#define SPI_CS_LOW        0x00000f00u
#define SPI_RX_PENDING    0x80000000u
#define SPI_RX_TIMEOUT    100000u

static uint32_t native_read32(void *ctx, uintptr_t address)
{
    (void)ctx;
    return *(volatile const uint32_t *)address;
}

static void native_write32(void *ctx, uintptr_t address, uint32_t value)
{
    (void)ctx;
    *(volatile uint32_t *)address = value;
}

void ulx5m_at25ql321_hw_init(struct ulx5m_at25ql321_hw *hw,
                              uintptr_t base)
{
    if (!hw)
        return;
    hw->base = base;
    hw->io_ctx = 0;
    hw->read32 = native_read32;
    hw->write32 = native_write32;
}

static int hw_begin(void *ctx)
{
    struct ulx5m_at25ql321_hw *hw = ctx;
    if (!hw || !hw->write32)
        return -1;
    hw->write32(hw->io_ctx, hw->base, SPI_CS_LOW);
    return 0;
}

static int hw_transfer(void *ctx, uint8_t tx, uint8_t *rx)
{
    struct ulx5m_at25ql321_hw *hw = ctx;
    if (!hw || !hw->write32 || !hw->read32)
        return -1;
    if (!rx) {
        hw->write32(hw->io_ctx, hw->base + 4u, tx);
        return 0;
    }
    /* Mode 0x100 queues one 8-bit SPI read with a dummy zero byte. */
    hw->write32(hw->io_ctx, hw->base + 4u, 0x100u);
    for (unsigned i = 0; i < SPI_RX_TIMEOUT; ++i) {
        uint32_t word = hw->read32(hw->io_ctx, hw->base + 4u);
        if (!(word & SPI_RX_PENDING)) {
            *rx = (uint8_t)word;
            return 0;
        }
    }
    return -1;
}

static int hw_end(void *ctx)
{
    struct ulx5m_at25ql321_hw *hw = ctx;
    if (!hw || !hw->write32)
        return -1;
    /* Deassert CS and tristate IO2/IO3 just like the existing driver. */
    hw->write32(hw->io_ctx, hw->base, SPI_CS_HIGH);
    return 0;
}

void ulx5m_at25ql321_hw_bind(struct ulx5m_at25ql321 *dev,
                              struct ulx5m_at25ql321_hw *hw)
{
    const struct ulx5m_at25ql321_bus bus = {
        .ctx = hw,
        .begin = hw_begin,
        .transfer = hw_transfer,
        .end = hw_end
    };
    ulx5m_at25ql321_init(dev, &bus);
}
