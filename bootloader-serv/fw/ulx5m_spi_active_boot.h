/* Read-only native slot qualification followed by RECFG-only request.
 * Returned REQUESTED means the register write was issued, NOT that a
 * secondary GateMate configuration completed or took over successfully.
 */
#ifndef ULX5M_SPI_ACTIVE_BOOT_H
#define ULX5M_SPI_ACTIVE_BOOT_H
#include <stdint.h>
#include "ulx5m_native_v41_image.h"

enum ulx5m_spi_active_boot_result {
    ULX5M_SPI_BOOT_DFU = 0,
    ULX5M_SPI_BOOT_INVALID = 1,
    ULX5M_SPI_BOOT_GATE_ERROR = 2,
    ULX5M_SPI_BOOT_REQUESTED = 3
};

#define ULX5M_SPI_BOOT_READY 1u
#define ULX5M_SPI_BOOT_ARMED 2u
#define ULX5M_SPI_BOOT_FIRED 4u
#define ULX5M_SPI_BOOT_ERROR 8u
#define ULX5M_SPI_BOOT_CAPABLE 16u
#define ULX5M_SPI_BOOT_ARM_KEY 0x41524d31u
#define ULX5M_SPI_BOOT_EXEC_KEY 0x424f4f54u

struct ulx5m_spi_active_boot_gate {
    void *ctx;
    void (*release_flash)(void *ctx);
    uint32_t (*status)(void *ctx);
    void (*arm)(void *ctx, uint32_t key);
    void (*execute)(void *ctx, uint32_t key);
};

enum ulx5m_spi_active_boot_result
ulx5m_spi_active_boot_run(const struct ulx5m_normal_image_reader *reader,
                          const struct ulx5m_spi_active_boot_gate *gate,
                          int dfu_selected_latched);
#endif
