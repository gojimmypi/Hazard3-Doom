/* Host test of the real GateMate MMIO adapter, with register-level fakes. */
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "ulx5m_at25ql321_hw.h"

#define BASE 0x84000000u
#define CSR_LOW 0x00000f00u
#define CSR_HIGH 0x00010f00u

struct fake_spi {
    unsigned select_count, deselect_count, tx_count, rx_count;
    unsigned selected, opcode, addr, command_bytes, fail_rx;
    uint8_t id[3], status;
    unsigned transactions;
};

static void write_reg(void *ctx, uintptr_t reg, uint32_t value)
{
    struct fake_spi *f = ctx;
    assert(reg == BASE || reg == BASE + 4u);
    if (reg == BASE) {
        if (value == CSR_LOW) {
            assert(!f->selected);
            f->selected = 1;
            f->opcode = 0;
            f->addr = 0;
            f->command_bytes = 0;
            f->rx_count = 0;
            ++f->select_count;
        } else {
            assert(value == CSR_HIGH && f->selected);
            f->selected = 0;
            ++f->deselect_count;
            ++f->transactions;
        }
        return;
    }
    assert(f->selected);
    if (value == 0x100u) {
        ++f->rx_count;
        return;
    }
    assert(value <= 0xffu);
    if (!f->command_bytes) {
        f->opcode = value;
        assert(f->opcode == 0x9fu || f->opcode == 0x05u ||
               f->opcode == 0x03u);
    } else if (f->opcode == 0x03u && f->command_bytes <= 3u) {
        f->addr = (f->addr << 8) | value;
    }
    ++f->command_bytes;
    ++f->tx_count;
}

static uint32_t read_reg(void *ctx, uintptr_t reg)
{
    struct fake_spi *f = ctx;
    assert(reg == BASE + 4u && f->selected);
    if (f->fail_rx)
        return 0x80000000u;
    assert(f->rx_count > 0);
    unsigned pos = f->rx_count - 1u;
    if (f->opcode == 0x9fu) {
        assert(pos < 3);
        return f->id[pos];
    }
    if (f->opcode == 0x05u) {
        assert(pos == 0);
        return f->status;
    }
    assert(f->opcode == 0x03u && f->command_bytes == 4u);
    return (uint8_t)((f->addr + pos) ^ 0x5au);
}

int main(void)
{
    struct ulx5m_at25ql321_hw hw;
    struct ulx5m_at25ql321 dev;
    struct fake_spi fake = {.id = {0x1f, 0x42, 0x16}, .status = 0x1cu};
    uint8_t id[3], status, out[32];
    ulx5m_at25ql321_hw_init(&hw, BASE);
    hw.io_ctx = &fake;
    hw.read32 = read_reg;
    hw.write32 = write_reg;
    ulx5m_at25ql321_hw_bind(&dev, &hw);
    assert(ulx5m_at25ql321_identify(&dev, id) == ULX5M_AT25_OK);
    assert(!memcmp(id, fake.id, 3));
    assert(ulx5m_at25ql321_status(&dev, &status) == ULX5M_AT25_OK);
    assert(status == fake.status);
    assert(ulx5m_at25ql321_read(&dev, 0x00123456u, out, sizeof(out)) ==
           ULX5M_AT25_OK);
    for (unsigned i = 0; i < sizeof(out); ++i)
        assert(out[i] == (uint8_t)((0x123456u + i) ^ 0x5au));
    assert(fake.select_count == 3 && fake.deselect_count == 3 &&
           fake.transactions == 3 && !fake.selected);
    unsigned tx = fake.tx_count;
    assert(ulx5m_at25ql321_read(&dev, 0x3fffffu, out, 2) ==
           ULX5M_AT25_RANGE);
    assert(ulx5m_at25ql321_erase_4k(&dev, 0x200000u) == ULX5M_AT25_DENIED);
    assert(ulx5m_at25ql321_program_page(&dev, 0x200000u, out, 32) ==
           ULX5M_AT25_DENIED);
    assert(fake.tx_count == tx && fake.transactions == 3);
    fake.fail_rx = 1;
    assert(ulx5m_at25ql321_status(&dev, &status) == ULX5M_AT25_IO);
    assert(fake.select_count == 4 && fake.deselect_count == 4 &&
           !fake.selected);
    puts("[PASS] physical-MMIO adapter: RDID, RDSR, READ, timeout/CS cleanup");
    puts("[PASS] bounds and production erase/program DENIED without SPI traffic");
    return 0;
}
