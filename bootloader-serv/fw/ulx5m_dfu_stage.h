/* ULX5M-GS experimental RAM-only DFU receiver. Never writes flash. */
#pragma once

#include "usb.h"

#define ULX5M_STAGE_CAPACITY 4096u
#define ULX5M_STAGE_BLOCK_MAX 64u
#define ULX5M_STAGE_INFO_REQ 0x57u
#define ULX5M_STAGE_INFO_BYTES 16u

void ulx5m_dfu_stage_reset(void);
enum usb_fnd_resp ulx5m_dfu_stage_req(struct usb_ctrl_req *req,
                                      struct usb_xfer *xfer);
