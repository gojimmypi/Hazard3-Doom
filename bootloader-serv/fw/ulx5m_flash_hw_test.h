/* Explicitly armed physical flash writer; default golden profile stays 4 KiB. */
#ifndef ULX5M_FLASH_HW_TEST_H
#define ULX5M_FLASH_HW_TEST_H
#include "usb.h"

#define ULX5M_HW_ARM_REQ    0x5cu
#define ULX5M_HW_STATUS_REQ 0x5du
#define ULX5M_HW_FINISH_REQ 0x5eu
#define ULX5M_HW_ARM_BYTES  16u
#define ULX5M_HW_STATUS_BYTES 24u
#if defined(ULX5M_DFU_FULL_IMAGE_TEST)
#define ULX5M_HW_MAX_BYTES (ULX5M_FLASH_BYTES - 0x00201000u)
#define ULX5M_HW_ARM_TOKEN  0xc01d2042u
#elif defined(ULX5M_FLASH_HW_NATIVE_SLOT_TEST)
/* Separate SRAM-only profile; cannot be mistaken for FWT3. */
#define ULX5M_HW_MAX_BYTES 4096u
#define ULX5M_HW_ARM_TOKEN  0xc01d2041u
#elif defined(ULX5M_FLASH_HW_QUAD_TEST)
#define ULX5M_HW_MAX_BYTES 16384u
#define ULX5M_HW_ARM_TOKEN  0xc01d2028u
#elif defined(ULX5M_FLASH_HW_MULTI_TEST)
#define ULX5M_HW_MAX_BYTES 8192u
#define ULX5M_HW_ARM_TOKEN  0xc01d2027u
#else
#define ULX5M_HW_MAX_BYTES 4096u
#define ULX5M_HW_ARM_TOKEN  0xc01d2026u
#endif

#ifdef ULX5M_FLASH_HW_HOST_TEST
#include "ulx5m_at25ql321.h"
void ulx5m_flash_hw_test_set_test_bus(const struct ulx5m_at25ql321_bus *bus);
#endif
void ulx5m_flash_hw_test_reset(void);
#ifdef ULX5M_DFU_FULL_IMAGE_TEST
int ulx5m_flash_hw_test_is_armed(void);
#endif
enum usb_fnd_resp ulx5m_flash_hw_test_req(struct usb_ctrl_req *req,
                                           struct usb_xfer *xfer);
#endif
