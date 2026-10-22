/* Exercise exact SPI commands against a native-host AT25QL321 model. */
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ulx5m-at25ql321-mock.h"

static struct ulx5m_spi_mock model;
static struct ulx5m_at25ql321 dev;

static void reset(void)
{
    ulx5m_spi_mock_init(&model);
    struct ulx5m_at25ql321_bus bus = ulx5m_spi_mock_bus(&model);
    ulx5m_at25ql321_init(&dev, &bus);
}
static void identify(void)
{
    uint8_t id[3];
    assert(ulx5m_at25ql321_identify(&dev, id) == ULX5M_AT25_OK);
    assert(id[0] == 0x1f && id[1] == 0x42 && id[2] == 0x16);
}
int main(void)
{
    reset();
    assert(ulx5m_at25ql321_erase_4k(&dev, 0x200000) == ULX5M_AT25_ID);
    identify();
    uint8_t status;
    assert(ulx5m_at25ql321_status(&dev, &status) == ULX5M_AT25_OK && status == 0);
    assert(ulx5m_at25ql321_read(&dev, 0x3fffff, &status, 1) == ULX5M_AT25_OK);
    assert(ulx5m_at25ql321_read(&dev, 0x3fffff, &status, 2) == ULX5M_AT25_RANGE);
    assert(ulx5m_at25ql321_read(&dev, 0x400000, &status, 1) == ULX5M_AT25_RANGE);
    assert(ulx5m_at25ql321_read(&dev, 0, &status, 0) == ULX5M_AT25_RANGE);
    puts("[PASS] JEDEC, status, bounded read and no-write initial state");

    uint8_t page[256], copied[256];
    for (unsigned i = 0; i < sizeof(page); ++i)
        page[i] = (uint8_t)(i ^ 0xa5);
    memset(model.memory, 0x55, ULX5M_AT25QL321_CANDIDATE_START);
    memset(model.memory + ULX5M_AT25QL321_CANDIDATE_START, 0xa5, 4096);
    assert(ulx5m_at25ql321_erase_4k(&dev, 0) == ULX5M_AT25_RANGE);
    assert(ulx5m_at25ql321_erase_4k(&dev, 0x200001) == ULX5M_AT25_RANGE);
    assert(ulx5m_at25ql321_erase_4k(&dev, 0x200000) == ULX5M_AT25_OK);
    assert(!model.busy_ticks && !model.wel && model.erases == 1);
    assert(ulx5m_at25ql321_program_page(&dev, 0x200000, page, 256) == ULX5M_AT25_OK);
    assert(ulx5m_at25ql321_read(&dev, 0x200000, copied, 256) == ULX5M_AT25_OK);
    assert(!memcmp(page, copied, 256));
    assert(ulx5m_at25ql321_program_page(&dev, 0x200000, page, 256) == ULX5M_AT25_NOT_ERASED);
    assert(ulx5m_at25ql321_program_page(&dev, 0x2000ff, page, 2) == ULX5M_AT25_RANGE);
    assert(ulx5m_at25ql321_program_page(&dev, 0x1fffff, page, 1) == ULX5M_AT25_RANGE);
    assert(model.erases == 1 && model.pages == 1 && model.writes_to_factory == 0);
    for (unsigned i = 0; i < ULX5M_AT25QL321_CANDIDATE_START; ++i)
        assert(model.memory[i] == 0x55);
    puts("[PASS] WREN/WEL, 0x20 erase, 0x02 page, WIP polling and factory half unchanged");

    reset();
    model.jedec[2] = 0xff;
    uint8_t id[3];
    assert(ulx5m_at25ql321_identify(&dev, id) == ULX5M_AT25_ID);
    assert(ulx5m_at25ql321_erase_4k(&dev, 0x200000) == ULX5M_AT25_ID);
    assert(model.write_enables == 0);
    puts("[PASS] wrong JEDEC blocks all mutating commands");

    reset(); identify();
    model.force_no_wel = 1;
    assert(ulx5m_at25ql321_erase_4k(&dev, 0x200000) == ULX5M_AT25_WEL);
    assert(!model.erases && model.write_enables == 1);
    puts("[PASS] missing WEL prevents erase");

    reset(); identify();
    model.hold_busy = 1;
    assert(ulx5m_at25ql321_erase_4k(&dev, 0x200000) == ULX5M_AT25_BUSY);
    assert(!model.write_enables && !model.erases);
    puts("[PASS] bounded BUSY polling never issues write-enable");

    reset(); identify();
    model.fail_transfer_at = model.transfers + 4;
    assert(ulx5m_at25ql321_erase_4k(&dev, 0x200000) == ULX5M_AT25_IO);
    assert(!model.selected && !model.erases);
    puts("[PASS] I/O error releases CS and refuses erase");
    return 0;
}
