/* GateMate QSPI Wishbone adapter for AT25QL321 read-only operations.
 * No flash writes, write-enable or programming authorization.
 */
#ifndef ULX5M_AT25QL321_HW_H
#define ULX5M_AT25QL321_HW_H

#include <stdint.h>
#include "ulx5m_at25ql321.h"

struct ulx5m_at25ql321_hw {
    uintptr_t base;
    void *io_ctx;
    uint32_t (*read32)(void *ctx, uintptr_t address);
    void (*write32)(void *ctx, uintptr_t address, uint32_t value);
};

/* base is SPI_BASE; register 0 = CSR, register 1 = DATA. */
void ulx5m_at25ql321_hw_init(struct ulx5m_at25ql321_hw *hw,
                              uintptr_t base);
void ulx5m_at25ql321_hw_bind(struct ulx5m_at25ql321 *dev,
                              struct ulx5m_at25ql321_hw *hw);

#endif
