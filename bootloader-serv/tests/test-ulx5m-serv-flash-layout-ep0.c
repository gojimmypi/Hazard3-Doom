/* Host-only test of the actual experimental firmware 0x58 USB dispatch.
 * It does not touch USB hardware registers or the physical SPI flash.
 */
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

/* Include production dispatch to test request validation without hardware. */
#define main ulx5m_unused_flash_main
#include "../fw/fw_ulx5m_flash_read.c"
#undef main

static enum usb_fnd_resp request(uint8_t type, uint16_t value,
                                 uint16_t index, uint16_t length,
                                 struct usb_xfer *xfer)
{
    struct usb_ctrl_req req = {
        .bmRequestType = type, .bRequest = ULX5M_FLASH_LAYOUT_REQ,
        .wValue = value, .wIndex = index, .wLength = length
    };
    return flash_ctrl_req(&req, xfer);
}

int main(void)
{
    uint8_t output[64];
    struct usb_xfer xfer = {.data = output, .len = sizeof(output)};
    memset(output, 0xa5, sizeof(output));
    assert(request(0xc0u, 0u, 0u, 32u, &xfer) == USB_FND_SUCCESS);
    assert(xfer.len == 32);
    assert(!memcmp(output, "FLM1", 4));
    for (unsigned i = 32; i < sizeof(output); ++i)
        assert(output[i] == 0xa5u);

    assert(request(0xc0u, 0u, 0u, 31u, &xfer) == USB_FND_ERROR);
    assert(request(0xc0u, 0u, 0u, 33u, &xfer) == USB_FND_ERROR);
    assert(request(0xc0u, 1u, 0u, 32u, &xfer) == USB_FND_ERROR);
    assert(request(0xc0u, 0u, 1u, 32u, &xfer) == USB_FND_ERROR);
    assert(request(0x40u, 0u, 0u, 32u, &xfer) != USB_FND_SUCCESS);
    puts("[PASS] actual firmware vendor IN FLM1 dispatch and malformed-request refusal");
    return 0;
}
