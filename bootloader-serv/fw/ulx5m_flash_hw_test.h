/* Isolated one-sector physical flash experiment. Not the normal DFU build. */
#ifndef ULX5M_FLASH_HW_TEST_H
#define ULX5M_FLASH_HW_TEST_H
#include "usb.h"

#define ULX5M_HW_ARM_REQ    0x5cu
#define ULX5M_HW_STATUS_REQ 0x5du
#define ULX5M_HW_FINISH_REQ 0x5eu
#define ULX5M_HW_ARM_BYTES  16u
#define ULX5M_HW_STATUS_BYTES 24u
#ifdef ULX5M_FLASH_HW_MULTI_TEST
#define ULX5M_HW_MAX_BYTES 8192u
#define ULX5M_HW_ARM_TOKEN  0xc01d2027u
#else
#define ULX5M_HW_MAX_BYTES 4096u
#define ULX5M_HW_ARM_TOKEN  0xc01d2026u
#endif

void ulx5m_flash_hw_test_reset(void);
enum usb_fnd_resp ulx5m_flash_hw_test_req(struct usb_ctrl_req *req,
                                           struct usb_xfer *xfer);
#endif
