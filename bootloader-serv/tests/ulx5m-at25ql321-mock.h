/* Native-host SPI flash transaction model. NEVER used on hardware. */
#ifndef ULX5M_AT25QL321_MOCK_H
#define ULX5M_AT25QL321_MOCK_H
#include <stdint.h>
#include "ulx5m_at25ql321.h"

struct ulx5m_spi_mock {
    uint8_t memory[ULX5M_FLASH_BYTES];
    uint8_t jedec[3];
    uint8_t current;
    uint8_t pending[ULX5M_FLASH_PAGE_BYTES];
    uint32_t address;
    unsigned bytes, payload_len, read_pos;
    unsigned erases, pages, reads, write_enables, write_disables;
    unsigned writes_to_factory;
    unsigned busy_ticks, busy_after_write;
    unsigned fail_transfer_at, transfers;
    int force_no_wel, hold_busy, selected, bad_command, broken;
    uint8_t wel;
};

void ulx5m_spi_mock_init(struct ulx5m_spi_mock *m);
struct ulx5m_at25ql321_bus ulx5m_spi_mock_bus(struct ulx5m_spi_mock *m);
#endif
