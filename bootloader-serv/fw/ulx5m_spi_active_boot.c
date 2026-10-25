#include "ulx5m_spi_active_boot.h"

/* This function does not write flash. It requests an SPI-active reread
 * only after validating the exact v41 native sector. It cannot detect
 * whether initial FPGA configuration was SPI-active or JTAG mode.
 */
enum ulx5m_spi_active_boot_result
ulx5m_spi_active_boot_run(const struct ulx5m_normal_image_reader *reader,
                          const struct ulx5m_spi_active_boot_gate *gate,
                          int dfu_selected_latched)
{
    uint32_t crc32 = 0;
    uint32_t status = 0;
    enum ulx5m_v41_probe_result image;
    if (dfu_selected_latched)
        return ULX5M_SPI_BOOT_DFU;
    if (!gate || !gate->release_flash || !gate->status ||
        !gate->arm || !gate->execute)
        return ULX5M_SPI_BOOT_GATE_ERROR;
    image = ulx5m_v41_native_probe(reader, 0, &crc32);
    gate->release_flash(gate->ctx);
    if (image != ULX5M_V41_VERIFIED_ONLY ||
        crc32 != ULX5M_V41_NATIVE_CRC32)
        return ULX5M_SPI_BOOT_INVALID;
    for (unsigned i = 0; i < 100000u; ++i) {
        status = gate->status(gate->ctx);
        if (status & ULX5M_SPI_BOOT_ERROR)
            return ULX5M_SPI_BOOT_GATE_ERROR;
        if ((status & (ULX5M_SPI_BOOT_READY | ULX5M_SPI_BOOT_CAPABLE)) ==
            (ULX5M_SPI_BOOT_READY | ULX5M_SPI_BOOT_CAPABLE))
            break;
    }
    if ((status & (ULX5M_SPI_BOOT_READY | ULX5M_SPI_BOOT_CAPABLE)) !=
        (ULX5M_SPI_BOOT_READY | ULX5M_SPI_BOOT_CAPABLE))
        return ULX5M_SPI_BOOT_GATE_ERROR;
    gate->arm(gate->ctx, ULX5M_SPI_BOOT_ARM_KEY);
    status = gate->status(gate->ctx);
    if ((status & ULX5M_SPI_BOOT_ARMED) == 0u ||
        (status & ULX5M_SPI_BOOT_ERROR))
        return ULX5M_SPI_BOOT_GATE_ERROR;
    gate->execute(gate->ctx, ULX5M_SPI_BOOT_EXEC_KEY);
    /* In SPI-active mode RECFG may replace our configuration right here. */
    status = gate->status(gate->ctx);
    if ((status & ULX5M_SPI_BOOT_FIRED) == 0u ||
        (status & ULX5M_SPI_BOOT_ERROR))
        return ULX5M_SPI_BOOT_GATE_ERROR;
    /* Do not label this as success. A SPI-active primary may reset here. */
    return ULX5M_SPI_BOOT_REQUESTED;
}
