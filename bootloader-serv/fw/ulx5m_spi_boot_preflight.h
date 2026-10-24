/* Read-only native SPI image preflight. Never triggers configuration. */
#ifndef ULX5M_SPI_BOOT_PREFLIGHT_H
#define ULX5M_SPI_BOOT_PREFLIGHT_H

#include "ulx5m_normal_image.h"

#define ULX5M_SPI_BOOT_U5IM_ADDRESS 0x00200000u
#define ULX5M_SPI_BOOT_NATIVE_ENTRY 0x00201000u

enum ulx5m_spi_boot_preflight_result {
    ULX5M_SPI_BOOT_STAY_DFU_BTN2 = 0,
    ULX5M_SPI_BOOT_STAY_DFU_ABSENT = 1,
    ULX5M_SPI_BOOT_STAY_DFU_INVALID = 2,
    ULX5M_SPI_BOOT_STAY_DFU_WRONG_LAYOUT = 3,
    ULX5M_SPI_BOOT_VALID_BUT_BLOCKED = 4
};

/* This is NOT a boot decision or an authorization interface.
 * BTN2 must be the startup-latched selection, not the live GPIO.
 * Output is cleared on entry and populated only for VALID_BUT_BLOCKED.
 * All return values forbid configuration and flash mutations.
 */
enum ulx5m_spi_boot_preflight_result
ulx5m_spi_boot_preflight(const struct ulx5m_normal_image_reader *reader,
                         int dfu_selected_latched,
                         struct ulx5m_normal_image_info *verified);

#endif
