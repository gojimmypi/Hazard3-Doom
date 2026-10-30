/* ULX5M SERV streaming DFU: discard-only except separate HW test build. */
#pragma once
#include "usb.h"

#define ULX5M_STREAM_INFO_REQ 0x59u
#define ULX5M_STREAM_INFO_BYTES 20u
#define ULX5M_STREAM_BLOCK_BYTES 64u
#ifdef ULX5M_DFU_FULL_IMAGE_TEST
#define ULX5M_STREAM_MAX_BYTES (0x00400000u - 0x00201000u)
#else
#define ULX5M_STREAM_MAX_BYTES 0x00200000u
#endif

void ulx5m_dfu_stream_reset(void);
int ulx5m_dfu_stream_can_arm(void);
enum usb_fnd_resp ulx5m_dfu_stream_req(struct usb_ctrl_req *req,
                                       struct usb_xfer *xfer);

#ifdef ULX5M_DFU_STREAM_EMULATOR_TEST
/* Native-host test only: production DFU continues discarding every block. */
void ulx5m_dfu_stream_set_test_sink(
    int (*sink)(uint32_t offset, const uint8_t *data, unsigned length));
#endif
#ifdef ULX5M_FLASH_HW_TEST
/* Only populated by explicit vendor arm in experimental build. */
void ulx5m_dfu_stream_set_flash_sink(
    int (*sink)(uint32_t offset, const uint8_t *data, unsigned length));
#endif
