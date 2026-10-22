/* Host check of the production STR1/FLM1 vendor dispatch, no USB/SPI hardware. */
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#define main ulx5m_unused_stream_main
#include "../fw/fw_ulx5m_flash_read.c"
#undef main

static enum usb_fnd_resp request(uint8_t type, uint8_t cmd, unsigned value,
                                 unsigned index, unsigned len,
                                 struct usb_xfer *xfer)
{
    struct usb_ctrl_req r = {
        .bmRequestType = type, .bRequest = cmd,
        .wValue = value, .wIndex = index, .wLength = len
    };
    return flash_ctrl_req(&r, xfer);
}
int main(void)
{
    uint8_t buf[64];
    struct usb_xfer x = {.data = buf, .len = sizeof(buf)};
    ulx5m_dfu_stream_reset();
    memset(buf, 0xaa, sizeof(buf));
    assert(request(0xc0, ULX5M_STREAM_INFO_REQ, 0, 0, 20, &x) == USB_FND_SUCCESS);
    assert(x.len == 20 && !memcmp(buf, "STR1", 4));
    assert(request(0xc0, ULX5M_STREAM_INFO_REQ, 1, 0, 20, &x) == USB_FND_ERROR);
    assert(request(0xc0, ULX5M_STREAM_INFO_REQ, 0, 0, 19, &x) == USB_FND_ERROR);
    x.data = buf;
    assert(request(0xc0, ULX5M_FLASH_LAYOUT_REQ, 0, 0, 32, &x) == USB_FND_SUCCESS);
    assert(x.len == 32 && !memcmp(buf, "FLM1", 4));
    assert(buf[24] == 0 && buf[28] == 3);
    assert(request(0x40, ULX5M_STREAM_INFO_REQ, 0, 0, 20, &x) != USB_FND_SUCCESS);
    puts("[PASS] production STR1/FLM1 dispatch; writes remain disabled");
    return 0;
}
