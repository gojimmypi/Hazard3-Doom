/* Native GateMate application slot writer, host-emulator qualification only.
 * Maps the existing flash stream engine from 0x200000 to 0x201000.
 * NEVER writes U5IM metadata, the factory/DFU first half, or flash status.
 */
#ifndef ULX5M_SPI_NATIVE_WRITER_H
#define ULX5M_SPI_NATIVE_WRITER_H

#include <stdint.h>
#include "ulx5m_flash_program.h"

#define ULX5M_SPI_NATIVE_ENTRY 0x00201000u
#define ULX5M_SPI_NATIVE_LIMIT 0x00400000u
#define ULX5M_SPI_NATIVE_CAPACITY (ULX5M_SPI_NATIVE_LIMIT - ULX5M_SPI_NATIVE_ENTRY)

struct ulx5m_spi_native_writer {
    struct ulx5m_flash_program stream;
    struct ulx5m_flash_program_ops physical_ops;
};

/* No production authorization exists. The host-test build explicitly
 * requires BOTH ULX5M_SPI_NATIVE_WRITER_HOST_TEST and
 * ULX5M_FLASH_PROGRAM_EMULATOR_TEST. RISC-V builds reject either flag.
 * A successful finish proves only stream/write/readback integrity;
 * it NEVER makes an application bootable or commits U5IM metadata.
 */
enum ulx5m_flash_program_result
ulx5m_spi_native_writer_begin(struct ulx5m_spi_native_writer *writer,
                              const struct ulx5m_flash_program_ops *physical,
                              uint32_t size, uint32_t crc32);

enum ulx5m_flash_program_result
ulx5m_spi_native_writer_feed(struct ulx5m_spi_native_writer *writer,
                             uint32_t offset, const uint8_t *data,
                             unsigned size);

enum ulx5m_flash_program_result
ulx5m_spi_native_writer_finish(struct ulx5m_spi_native_writer *writer);

#endif
