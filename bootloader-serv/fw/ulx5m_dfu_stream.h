/* ULX5M SERV volatile streaming DFU experiment. No flash writes. */
#pragma once
#include "usb.h"

#define ULX5M_STREAM_INFO_REQ 0x59u
#define ULX5M_STREAM_INFO_BYTES 20u
#define ULX5M_STREAM_BLOCK_BYTES 64u
#define ULX5M_STREAM_MAX_BYTES 0x00200000u

void ulx5m_dfu_stream_reset(void);
enum usb_fnd_resp ulx5m_dfu_stream_req(struct usb_ctrl_req *req,
                                       struct usb_xfer *xfer);
