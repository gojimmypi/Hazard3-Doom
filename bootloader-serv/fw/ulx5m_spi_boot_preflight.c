/* Native SPI layout eligibility only. No jump, transport or flash writes. */
#include "ulx5m_spi_boot_preflight.h"
#include "ulx5m_flash_layout.h"

static void clear_info(struct ulx5m_normal_image_info *info)
{
    if (info) {
        info->header_address = 0u;
        info->payload_address = 0u;
        info->payload_bytes = 0u;
        info->expected_crc32 = 0u;
    }
}

enum ulx5m_spi_boot_preflight_result
ulx5m_spi_boot_preflight(const struct ulx5m_normal_image_reader *reader,
                         int dfu_selected_latched,
                         struct ulx5m_normal_image_info *verified)
{
    struct ulx5m_normal_image_info info;
    enum ulx5m_normal_image_result result;

    clear_info(verified);
    if (dfu_selected_latched)
        return ULX5M_SPI_BOOT_STAY_DFU_BTN2;
    if (!reader || !reader->read)
        return ULX5M_SPI_BOOT_STAY_DFU_INVALID;

    result = ulx5m_normal_image_probe(reader, ULX5M_SPI_BOOT_U5IM_ADDRESS,
                                       &info);
    if (result == ULX5M_NORMAL_IMAGE_ABSENT)
        return ULX5M_SPI_BOOT_STAY_DFU_ABSENT;
    if (result != ULX5M_NORMAL_IMAGE_INTEGRITY_OK)
        return ULX5M_SPI_BOOT_STAY_DFU_INVALID;

    /* A valid U5IM with offset 0x100 is NOT a native SPI jump target.
     * Check exact address and bounds independent of parser acceptance.
     */
    if (info.header_address != ULX5M_SPI_BOOT_U5IM_ADDRESS ||
        info.payload_address != ULX5M_SPI_BOOT_NATIVE_ENTRY ||
        !info.payload_bytes ||
        info.payload_bytes > ULX5M_FLASH_BYTES - info.payload_address)
        return ULX5M_SPI_BOOT_STAY_DFU_WRONG_LAYOUT;

    if (verified)
        *verified = info;
    /* This result never grants permission to call CC_CFG_CTRL or reset. */
    return ULX5M_SPI_BOOT_VALID_BUT_BLOCKED;
}
