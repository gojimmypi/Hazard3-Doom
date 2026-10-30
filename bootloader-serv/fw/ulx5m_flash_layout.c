/* Fail-closed ULX5M-GS flash policy. Physical protection is not asserted. */
#include "ulx5m_flash_layout.h"

static void put32(uint8_t *out, uint32_t word)
{
    for (unsigned i = 0; i < 4; ++i)
        out[i] = (uint8_t)(word >> (i * 8u));
}

int ulx5m_flash_read_range_valid(uint32_t address, uint32_t length)
{
    return length != 0u && address < ULX5M_FLASH_BYTES &&
           length <= ULX5M_FLASH_BYTES - address;
}

enum ulx5m_flash_write_result ulx5m_flash_check_erase(uint32_t address,
                                                      uint32_t length)
{
    if (!ulx5m_flash_read_range_valid(address, length))
        return ULX5M_FLASH_WRITE_BAD_RANGE;
    if ((address % ULX5M_FLASH_ERASE_BYTES) != 0u ||
        (length % ULX5M_FLASH_ERASE_BYTES) != 0u)
        return ULX5M_FLASH_WRITE_BAD_GEOMETRY;
#ifdef ULX5M_DFU_FULL_IMAGE_TEST
    if (address >= 0x00201000u)
        return ULX5M_FLASH_WRITE_OK;
#endif
    return ULX5M_FLASH_WRITE_PROTECTED;
}

enum ulx5m_flash_write_result ulx5m_flash_check_program(uint32_t address,
                                                        uint32_t length)
{
    if (!ulx5m_flash_read_range_valid(address, length))
        return ULX5M_FLASH_WRITE_BAD_RANGE;
    if (length > ULX5M_FLASH_PAGE_BYTES ||
        length > ULX5M_FLASH_PAGE_BYTES -
                 (address % ULX5M_FLASH_PAGE_BYTES))
        return ULX5M_FLASH_WRITE_BAD_GEOMETRY;
#ifdef ULX5M_DFU_FULL_IMAGE_TEST
    if (address >= 0x00201000u)
        return ULX5M_FLASH_WRITE_OK;
#endif
    return ULX5M_FLASH_WRITE_PROTECTED;
}

void ulx5m_flash_layout_encode(uint8_t *out)
{
    /* FLM1 / total / erase / page / protected_start / protected_len /
     * writable_count / flags, all uint32 values little-endian. */
    out[0] = 'F';
    out[1] = 'L';
    out[2] = 'M';
    out[3] = '1';
    put32(out + 4, ULX5M_FLASH_BYTES);
    put32(out + 8, ULX5M_FLASH_ERASE_BYTES);
    put32(out + 12, ULX5M_FLASH_PAGE_BYTES);
    put32(out + 16, 0u);
#ifdef ULX5M_DFU_FULL_IMAGE_TEST
    /* Single writable trailing partition: 0x201000..0x3fffff. */
    put32(out + 20, 0x00201000u);
    put32(out + 24, 1u);
    put32(out + 28, 0u);
#else
    put32(out + 20, ULX5M_FLASH_BYTES);
    put32(out + 24, 0u);
    put32(out + 28, ULX5M_FLASH_LAYOUT_UNVERIFIED |
                    ULX5M_FLASH_WRITES_DISABLED);
#endif
}
