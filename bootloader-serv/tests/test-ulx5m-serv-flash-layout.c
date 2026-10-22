/* Host-only ULX5M flash layout policy tests; never accesses physical flash. */
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "ulx5m_flash_layout.h"

static uint32_t le32(const uint8_t *b)
{
    return (uint32_t)b[0] | ((uint32_t)b[1] << 8) |
        ((uint32_t)b[2] << 16) | ((uint32_t)b[3] << 24);
}

int main(void)
{
    uint8_t report[ULX5M_FLASH_LAYOUT_BYTES];
    ulx5m_flash_layout_encode(report);
    assert(memcmp(report, "FLM1", 4) == 0);
    assert(le32(report + 4) == 0x400000u);
    assert(le32(report + 8) == 4096u);
    assert(le32(report + 12) == 256u);
    assert(le32(report + 16) == 0u);
    assert(le32(report + 20) == 0x400000u);
    assert(le32(report + 24) == 0u);
    assert(le32(report + 28) == 3u);

    assert(ulx5m_flash_read_range_valid(0, 1));
    assert(ulx5m_flash_read_range_valid(0x3fffffu, 1));
    assert(ulx5m_flash_read_range_valid(0, 0x400000u));
    assert(!ulx5m_flash_read_range_valid(0, 0));
    assert(!ulx5m_flash_read_range_valid(0x400000u, 1));
    assert(!ulx5m_flash_read_range_valid(0x3fffffu, 2));
    assert(!ulx5m_flash_read_range_valid(0xfffffff0u, 32));
    assert(!ulx5m_flash_read_range_valid(1u, 0xffffffffu));

    assert(ulx5m_flash_check_erase(0, 0x1000u) == ULX5M_FLASH_WRITE_PROTECTED);
    assert(ulx5m_flash_check_erase(0x3ff000u, 0x1000u) == ULX5M_FLASH_WRITE_PROTECTED);
    assert(ulx5m_flash_check_erase(0u, 0x400000u) == ULX5M_FLASH_WRITE_PROTECTED);
    assert(ulx5m_flash_check_erase(1, 4096) == ULX5M_FLASH_WRITE_BAD_GEOMETRY);
    assert(ulx5m_flash_check_erase(0, 4095) == ULX5M_FLASH_WRITE_BAD_GEOMETRY);
    assert(ulx5m_flash_check_erase(0x3ff000u, 8192) == ULX5M_FLASH_WRITE_BAD_RANGE);
    assert(ulx5m_flash_check_erase(0x400000u, 4096) == ULX5M_FLASH_WRITE_BAD_RANGE);
    assert(ulx5m_flash_check_erase(0, 0) == ULX5M_FLASH_WRITE_BAD_RANGE);
    assert(ulx5m_flash_check_erase(0xfffff000u, 4096) == ULX5M_FLASH_WRITE_BAD_RANGE);

    assert(ulx5m_flash_check_program(0, 1) == ULX5M_FLASH_WRITE_PROTECTED);
    assert(ulx5m_flash_check_program(0x3fffffu, 1) == ULX5M_FLASH_WRITE_PROTECTED);
    assert(ulx5m_flash_check_program(0, 256) == ULX5M_FLASH_WRITE_PROTECTED);
    assert(ulx5m_flash_check_program(255, 2) == ULX5M_FLASH_WRITE_BAD_GEOMETRY);
    assert(ulx5m_flash_check_program(0, 257) == ULX5M_FLASH_WRITE_BAD_GEOMETRY);
    assert(ulx5m_flash_check_program(0x400000u, 1) == ULX5M_FLASH_WRITE_BAD_RANGE);
    assert(ulx5m_flash_check_program(0xfffffff0u, 64) == ULX5M_FLASH_WRITE_BAD_RANGE);
    assert(ulx5m_flash_check_program(0, 0) == ULX5M_FLASH_WRITE_BAD_RANGE);

    /* Exhaustively check every 4 KiB erase-block start in the 4 MiB array. */
    for (uint32_t addr = 0; addr < ULX5M_FLASH_BYTES;
         addr += ULX5M_FLASH_ERASE_BYTES)
        assert(ulx5m_flash_check_erase(addr, ULX5M_FLASH_ERASE_BYTES) ==
               ULX5M_FLASH_WRITE_PROTECTED);

    puts("[PASS] FLM1 4 MiB layout, range/overflow/geometry validation");
    puts("[PASS] All 1024 erase blocks protected; no writable regions");
    return 0;
}
