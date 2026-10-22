#include "ulx5m-at25ql321-mock.h"
#include <string.h>

static int spi_begin(void *ctx)
{
    struct ulx5m_spi_mock *m = ctx;
    if (m->selected)
        return -1;
    m->selected = 1;
    m->bytes = 0;
    m->address = 0;
    m->payload_len = 0;
    m->read_pos = 0;
    return 0;
}

static int spi_xfer(void *ctx, uint8_t tx, uint8_t *rx)
{
    struct ulx5m_spi_mock *m = ctx;
    if (!m->selected || m->broken)
        return -1;
    m->transfers++;
    if (m->fail_transfer_at && m->transfers == m->fail_transfer_at) {
        m->broken = 1;
        return -1;
    }
    if (!m->bytes) {
        if (rx) return -1;
        m->current = tx;
        m->bytes++;
        return 0;
    }
    if (rx) {
        switch (m->current) {
        case 0x9f:
            *rx = m->jedec[m->read_pos++ % 3u];
            break;
        case 0x05:
            *rx = (m->hold_busy || m->busy_ticks ? 0x01u : 0u) |
                  (m->wel ? 0x02u : 0u);
            if (m->busy_ticks)
                m->busy_ticks--;
            break;
        case 0x03:
            if (m->bytes != 4u || m->address + m->read_pos >= ULX5M_FLASH_BYTES)
                return -1;
            *rx = m->memory[m->address + m->read_pos++];
            break;
        default:
            return -1;
        }
        return 0;
    }
    switch (m->current) {
    case 0x03: case 0x20: case 0x02:
        if (m->bytes < 4u)
            m->address = (m->address << 8) | tx;
        else if (m->current == 0x02) {
            if (m->payload_len >= ULX5M_FLASH_PAGE_BYTES)
                return -1;
            m->pending[m->payload_len++] = tx;
        } else return -1;
        break;
    default:
        return -1;
    }
    m->bytes++;
    return 0;
}

static int spi_end(void *ctx)
{
    struct ulx5m_spi_mock *m = ctx;
    if (!m->selected)
        return -1;
    m->selected = 0;
    if (m->broken)
        return -1;
    switch (m->current) {
    case 0x9f: case 0x05:
        if (m->bytes != 1) return -1;
        break;
    case 0x03:
        if (m->bytes != 4) return -1;
        m->reads++;
        break;
    case 0x06:
        if (m->bytes != 1) return -1;
        m->write_enables++;
        if (!m->force_no_wel && !m->busy_ticks && !m->hold_busy)
            m->wel = 1;
        break;
    case 0x04:
        if (m->bytes != 1) return -1;
        m->write_disables++;
        m->wel = 0;
        break;
    case 0x20:
        if (m->bytes != 4 || !m->wel || m->busy_ticks || m->hold_busy ||
            m->address % ULX5M_FLASH_ERASE_BYTES ||
            m->address > ULX5M_FLASH_BYTES - ULX5M_FLASH_ERASE_BYTES)
            return -1;
        if (m->address < ULX5M_AT25QL321_CANDIDATE_START)
            m->writes_to_factory++;
        memset(m->memory + m->address, 0xff, ULX5M_FLASH_ERASE_BYTES);
        m->erases++;
        m->wel = 0;
        m->busy_ticks = m->busy_after_write;
        break;
    case 0x02:
        if (m->bytes < 5 || m->bytes != 4 + m->payload_len ||
            !m->wel || m->busy_ticks || m->hold_busy ||
            !m->payload_len || m->payload_len > ULX5M_FLASH_PAGE_BYTES ||
            m->address > ULX5M_FLASH_BYTES - m->payload_len ||
            m->payload_len > ULX5M_FLASH_PAGE_BYTES - (m->address % ULX5M_FLASH_PAGE_BYTES))
            return -1;
        if (m->address < ULX5M_AT25QL321_CANDIDATE_START)
            m->writes_to_factory++;
        for (unsigned i = 0; i < m->payload_len; ++i)
            m->memory[m->address + i] &= m->pending[i];
        m->pages++;
        m->wel = 0;
        m->busy_ticks = m->busy_after_write;
        break;
    default:
        m->bad_command++;
        return -1;
    }
    return 0;
}

void ulx5m_spi_mock_init(struct ulx5m_spi_mock *m)
{
    memset(m, 0, sizeof(*m));
    memset(m->memory, 0xff, sizeof(m->memory));
    m->jedec[0] = ULX5M_AT25QL321_JEDEC0;
    m->jedec[1] = ULX5M_AT25QL321_JEDEC1;
    m->jedec[2] = ULX5M_AT25QL321_JEDEC2;
    m->busy_after_write = 2;
}

struct ulx5m_at25ql321_bus ulx5m_spi_mock_bus(struct ulx5m_spi_mock *m)
{
    struct ulx5m_at25ql321_bus bus = {
        .ctx = m,
        .begin = spi_begin,
        .transfer = spi_xfer,
        .end = spi_end
    };
    return bus;
}
