/* AT25QL321 SPI command driver; hardware writes are NOT authorized.
 * Mutating commands compile only for native-host emulator tests.
 */
#ifndef ULX5M_AT25QL321_H
#define ULX5M_AT25QL321_H

#include <stdint.h>
#include "ulx5m_flash_layout.h"

#define ULX5M_AT25QL321_JEDEC0 0x1fu
#define ULX5M_AT25QL321_JEDEC1 0x42u
#define ULX5M_AT25QL321_JEDEC2 0x16u
#if defined(ULX5M_FLASH_HW_NATIVE_SLOT_TEST)
#define ULX5M_AT25QL321_CANDIDATE_START 0x00201000u
#else
#define ULX5M_AT25QL321_CANDIDATE_START 0x00200000u
#endif
#define ULX5M_AT25QL321_MAX_POLLS 4096u

/* Send one byte, optionally returning the simultaneously received byte.
 * The adapter MUST support command bytes (rx == NULL) and dummy-clocked
 * receive bytes (rx != NULL), matching the existing SPI MMIO controller.
 */
struct ulx5m_at25ql321_bus {
    void *ctx;
    int (*begin)(void *ctx);
    int (*transfer)(void *ctx, uint8_t tx, uint8_t *rx);
    int (*end)(void *ctx);
};

enum ulx5m_at25ql321_result {
    ULX5M_AT25_OK = 0,
    ULX5M_AT25_DENIED = 1,
    ULX5M_AT25_RANGE = 2,
    ULX5M_AT25_IO = 3,
    ULX5M_AT25_ID = 4,
    ULX5M_AT25_BUSY = 5,
    ULX5M_AT25_WEL = 6,
    ULX5M_AT25_NOT_ERASED = 7
};

struct ulx5m_at25ql321 {
    struct ulx5m_at25ql321_bus bus;
    uint8_t identified;
};

void ulx5m_at25ql321_init(struct ulx5m_at25ql321 *dev,
                           const struct ulx5m_at25ql321_bus *bus);
enum ulx5m_at25ql321_result
ulx5m_at25ql321_identify(struct ulx5m_at25ql321 *dev, uint8_t id[3]);
enum ulx5m_at25ql321_result
ulx5m_at25ql321_status(struct ulx5m_at25ql321 *dev, uint8_t *status1);
enum ulx5m_at25ql321_result
ulx5m_at25ql321_read(struct ulx5m_at25ql321 *dev, uint32_t address,
                       uint8_t *buffer, unsigned length);

enum ulx5m_at25ql321_result
ulx5m_at25ql321_erase_4k(struct ulx5m_at25ql321 *dev, uint32_t address);
enum ulx5m_at25ql321_result
ulx5m_at25ql321_program_page(struct ulx5m_at25ql321 *dev, uint32_t address,
                               const uint8_t *data, unsigned length);

#endif
