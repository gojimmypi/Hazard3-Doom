/* ULX5M-GS U9 AT25QL321 layout policy. No flash write implementation. */
#pragma once
#include <stdint.h>

#define ULX5M_FLASH_BYTES         0x00400000u
#define ULX5M_FLASH_ERASE_BYTES   0x00001000u
#define ULX5M_FLASH_PAGE_BYTES    256u
#define ULX5M_FLASH_LAYOUT_REQ    0x58u
#define ULX5M_FLASH_LAYOUT_BYTES  32u

/* Default layout remains entirely protected; full-image opt-in exposes only the native secondary. */
#define ULX5M_FLASH_LAYOUT_UNVERIFIED  0x01u
#define ULX5M_FLASH_WRITES_DISABLED    0x02u

enum ulx5m_flash_write_result {
    ULX5M_FLASH_WRITE_OK = 0,
    ULX5M_FLASH_WRITE_BAD_RANGE = 1,
    ULX5M_FLASH_WRITE_BAD_GEOMETRY = 2,
    ULX5M_FLASH_WRITE_PROTECTED = 3
};

int ulx5m_flash_read_range_valid(uint32_t address, uint32_t length);
enum ulx5m_flash_write_result ulx5m_flash_check_erase(uint32_t address,
                                                      uint32_t length);
enum ulx5m_flash_write_result ulx5m_flash_check_program(uint32_t address,
                                                        uint32_t length);
void ulx5m_flash_layout_encode(uint8_t *out);
