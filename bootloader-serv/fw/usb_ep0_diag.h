/* ULX5M SERV read-only endpoint-zero diagnostics (not a DFU protocol).
 * Only compiled into the ULX5M_SERV_TEST firmware profile.
 */
#pragma once
#include <stdint.h>

#define USB_EP0_DIAG_REQ   0x53u
#define USB_EP0_RAW_READ_REQ 0x55u
#define USB_EP0_RAW_ARM_REQ  0x56u
#define USB_EP0_RAW_PAGES 17u
#define USB_EP0_RAW_PAGE_BYTES 16u
#define USB_EP0_DIAG_SHORT_REQ 0x54u
#define USB_EP0_DIAG_SHORT_BYTES 16u
#define USB_EP0_DIAG_SHORT_PAGES 11u
#define USB_EP0_TRACE_WORDS 18u
#define USB_EP0_DIAG_WORDS 15u
#define USB_EP0_DIAG_BYTES (USB_EP0_DIAG_WORDS * 4u)

#ifdef ULX5M_SERV_TEST
void usb_ep0_diag_snapshot(uint8_t *dst);
void usb_ep0_diag_short_snapshot(uint8_t *dst, unsigned page);
#endif
