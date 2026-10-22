/* Normal firmware build: the candidate slot cannot be written. */
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include "ulx5m_flash_program.h"

static unsigned callbacks;
static int erase_sector(void *ctx, uint32_t addr)
{
    (void)ctx; (void)addr; callbacks++; return 0;
}
static int program_page(void *ctx, uint32_t addr,
                        const uint8_t *buf, unsigned size)
{
    (void)ctx; (void)addr; (void)buf; (void)size; callbacks++; return 0;
}
static int read_bytes(void *ctx, uint32_t addr,
                      uint8_t *buf, unsigned size)
{
    (void)ctx; (void)addr; (void)buf; (void)size; callbacks++; return 0;
}
int main(void)
{
    struct ulx5m_flash_program session = {0};
    const struct ulx5m_flash_program_ops ops = {
        .ctx = 0, .erase_sector = erase_sector,
        .program_page = program_page, .read_bytes = read_bytes
    };
    uint8_t sample[64] = {0};
    assert(ulx5m_flash_check_erase(ULX5M_FLASH_CANDIDATE_START,
                                   ULX5M_FLASH_ERASE_BYTES) ==
           ULX5M_FLASH_WRITE_PROTECTED);
    assert(ulx5m_flash_check_program(ULX5M_FLASH_CANDIDATE_START, 64) ==
           ULX5M_FLASH_WRITE_PROTECTED);
    assert(ulx5m_flash_program_begin(&session, &ops, 64, 0) ==
           ULX5M_PROGRAM_DENIED);
    assert(ulx5m_flash_program_feed(&session, 0, sample, sizeof(sample)) ==
           ULX5M_PROGRAM_STATE);
    assert(ulx5m_flash_program_finish(&session) == ULX5M_PROGRAM_STATE);
    assert(callbacks == 0);
    puts("[PASS] production update begin DENIED; no erase, program or read callbacks");
    return 0;
}
