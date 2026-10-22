/* Production compile with a bus that counts every transaction. */
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "ulx5m_at25ql321.h"
static unsigned touched;
static int begin(void *ctx) { (void)ctx; touched++; return 0; }
static int transfer(void *ctx, uint8_t tx, uint8_t *rx)
{ (void)ctx; (void)tx; (void)rx; touched++; return 0; }
static int end(void *ctx) { (void)ctx; touched++; return 0; }
int main(void)
{
    struct ulx5m_at25ql321 chip;
    const struct ulx5m_at25ql321_bus bus = {
        .ctx = 0, .begin = begin, .transfer = transfer, .end = end
    };
    uint8_t page[256];
    memset(page, 0x5a, sizeof(page));
    ulx5m_at25ql321_init(&chip, &bus);
    assert(ulx5m_at25ql321_erase_4k(&chip, 0x200000) == ULX5M_AT25_DENIED);
    assert(ulx5m_at25ql321_program_page(&chip, 0x200000, page, 256) == ULX5M_AT25_DENIED);
    assert(ulx5m_at25ql321_erase_4k(&chip, 0x000000) == ULX5M_AT25_DENIED);
    assert(touched == 0);
    puts("[PASS] production AT25QL321 driver refuses writes before ANY SPI transaction");
    return 0;
}
