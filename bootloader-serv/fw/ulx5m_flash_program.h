/* ULX5M-GS bounded candidate-slot flash programming logic.
 * No SPI opcodes in this module. Default builds are fail-closed.
 * The emulator-only build switch MUST NOT be used in FPGA firmware.
 */
#ifndef ULX5M_FLASH_PROGRAM_H
#define ULX5M_FLASH_PROGRAM_H

#include <stdint.h>
#include "ulx5m_flash_layout.h"

#if defined(ULX5M_FLASH_HW_NATIVE_SLOT_TEST) || defined(ULX5M_DFU_FULL_IMAGE_TEST)
#define ULX5M_FLASH_CANDIDATE_START 0x00201000u
#else
#define ULX5M_FLASH_CANDIDATE_START 0x00200000u
#endif
#define ULX5M_FLASH_CANDIDATE_BYTES (ULX5M_FLASH_BYTES - ULX5M_FLASH_CANDIDATE_START)
#define ULX5M_FLASH_STREAM_BLOCK_BYTES 64u

enum ulx5m_flash_program_result {
    ULX5M_PROGRAM_OK = 0,
    ULX5M_PROGRAM_DENIED = 1,
    ULX5M_PROGRAM_RANGE = 2,
    ULX5M_PROGRAM_ORDER = 3,
    ULX5M_PROGRAM_IO = 4,
    ULX5M_PROGRAM_VERIFY = 5,
    ULX5M_PROGRAM_CRC = 6,
    ULX5M_PROGRAM_STATE = 7,
    ULX5M_PROGRAM_FORMAT = 8
};

struct ulx5m_flash_program_ops {
    void *ctx;
    /* Return 0 on success. The caller enforces erase/page geometry. */
    int (*erase_sector)(void *ctx, uint32_t address);
    int (*program_page)(void *ctx, uint32_t address,
                        const uint8_t *data, unsigned length);
    int (*read_bytes)(void *ctx, uint32_t address,
                      uint8_t *data, unsigned length);
};

struct ulx5m_flash_program {
    struct ulx5m_flash_program_ops ops;
    uint32_t image_size;
    uint32_t expected_crc32;
    uint32_t received;
    uint32_t running_crc;
    uint32_t next_page_address;
    uint32_t next_sector_address;
    unsigned pending_length;
    uint8_t pending[ULX5M_FLASH_PAGE_BYTES];
    uint8_t verified[ULX5M_FLASH_PAGE_BYTES];
    enum ulx5m_flash_program_result result;
    uint8_t active;
    uint8_t finalized;
};

/* The only way to enable the mock backend is ULX5M_FLASH_PROGRAM_EMULATOR_TEST.
 * This define is used exclusively by a native-host test target.
 */
enum ulx5m_flash_program_result
ulx5m_flash_program_begin(struct ulx5m_flash_program *session,
                          const struct ulx5m_flash_program_ops *ops,
                          uint32_t image_size, uint32_t expected_crc32);

enum ulx5m_flash_program_result
ulx5m_flash_program_feed(struct ulx5m_flash_program *session,
                         uint32_t offset, const uint8_t *data, unsigned length);

enum ulx5m_flash_program_result
ulx5m_flash_program_finish(struct ulx5m_flash_program *session);

#endif
