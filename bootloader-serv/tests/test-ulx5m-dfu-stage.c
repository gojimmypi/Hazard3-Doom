/* Host-side state-machine tests; no GateMate, USB hardware, or flash. */
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "usb_dfu_proto.h"
#include "ulx5m_dfu_stage.h"

static uint8_t ep0buf[64];

static enum usb_fnd_resp request(uint8_t type, uint8_t cmd,
                                 unsigned value, unsigned index,
                                 unsigned len, struct usb_xfer *x)
{
    struct usb_ctrl_req req = {
        .bmRequestType = type, .bRequest = cmd, .wValue = value,
        .wIndex = index, .wLength = len
    };
    memset(x, 0, sizeof(*x));
    memset(ep0buf, 0, sizeof(ep0buf));
    x->data = ep0buf;
    x->len = sizeof(ep0buf);
    return ulx5m_dfu_stage_req(&req, x);
}

static void read_info(uint8_t *info)
{
    struct usb_xfer x;
    assert(request(0xc0, ULX5M_STAGE_INFO_REQ, 0, 0, 16, &x) == USB_FND_SUCCESS);
    assert(x.len == 16);
    memcpy(info, x.data, 16);
    assert(!memcmp(info, "STG1", 4));
}

static uint32_t little32(const uint8_t *p)
{
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) |
        ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static void send_block(unsigned block, const uint8_t *data, unsigned len)
{
    struct usb_xfer x;
    assert(request(0x21, USB_REQ_DFU_DNLOAD, block, 0, len, &x) == USB_FND_SUCCESS);
    assert(x.data != ep0buf && x.len == (int)len && x.cb_done);
    memcpy(x.data, data, len);
    x.ofs = len; /* emulate complete OUT data + acknowledged status IN */
    assert(x.cb_done(&x));
    assert(request(0xa1, USB_REQ_DFU_GETSTATUS, 0, 0, 6, &x) == USB_FND_SUCCESS);
    assert(x.len == 6 && x.data[0] == OK && x.data[4] == dfuDNLOAD_IDLE);
}

int main(void)
{
    struct usb_xfer x;
    uint8_t info[16];
    uint8_t buf[64];
    ulx5m_dfu_stage_reset();

    assert(request(0xa1, USB_REQ_DFU_GETSTATE, 0, 0, 1, &x) == USB_FND_SUCCESS);
    assert(x.data[0] == dfuIDLE);
    assert(request(0xa1, USB_REQ_DFU_UPLOAD, 0, 0, 4, &x) == USB_FND_ERROR);
    assert(request(0x21, USB_REQ_DFU_DETACH, 0, 0, 0, &x) == USB_FND_ERROR);
    assert(request(0xc0, ULX5M_STAGE_INFO_REQ, 0, 0, 15, &x) == USB_FND_ERROR);
    assert(request(0x21, USB_REQ_DFU_DNLOAD, 0, 1, 9, &x) == USB_FND_ERROR);

    /* Reference CRC-32/ISO-HDLC for ASCII 123456789: CB F4 39 26. */
    send_block(0, (const uint8_t *)"123456789", 9);
    read_info(info);
    assert(little32(info + 4) == 9 && little32(info + 8) == 0xcbf43926u);
    assert(info[12] == 1 && info[14] == dfuDNLOAD_IDLE && info[15] == OK);

    /* Retry/wrong block is rejected, and CLRSTATUS resets staged bytes. */
    assert(request(0x21, USB_REQ_DFU_DNLOAD, 0, 0, 9, &x) == USB_FND_ERROR);
    assert(request(0xa1, USB_REQ_DFU_GETSTATE, 0, 0, 1, &x) == USB_FND_SUCCESS);
    assert(x.data[0] == dfuERROR);
    assert(request(0x21, USB_REQ_DFU_CLRSTATUS, 0, 0, 0, &x) == USB_FND_SUCCESS);
    read_info(info);
    assert(little32(info + 4) == 0 && info[12] == 0 && info[14] == dfuIDLE);

    /* Oversize never creates a data-stage buffer. */
    assert(request(0x21, USB_REQ_DFU_DNLOAD, 0, 0, 65, &x) == USB_FND_ERROR);
    assert(request(0x21, USB_REQ_DFU_CLRSTATUS, 0, 0, 0, &x) == USB_FND_SUCCESS);

    /* Exact capacity, then one byte too many. */
    memset(buf, 0xa5, sizeof(buf));
    for (unsigned i = 0; i < 64; ++i)
        send_block(i, buf, sizeof(buf));
    read_info(info);
    assert(little32(info + 4) == ULX5M_STAGE_CAPACITY);
    assert(info[12] == 64 && info[13] == 0);
    assert(request(0x21, USB_REQ_DFU_DNLOAD, 64, 0, 1, &x) == USB_FND_ERROR);
    assert(request(0x21, USB_REQ_DFU_ABORT, 0, 0, 0, &x) == USB_FND_ERROR);
    assert(request(0x21, USB_REQ_DFU_CLRSTATUS, 0, 0, 0, &x) == USB_FND_SUCCESS);

    /* A zero-length final block can never claim the flash was programmed. */
    send_block(0, buf, 64);
    assert(request(0x21, USB_REQ_DFU_DNLOAD, 1, 0, 0, &x) == USB_FND_SUCCESS);
    assert(x.cb_done && x.cb_done(&x));
    assert(request(0xa1, USB_REQ_DFU_GETSTATUS, 0, 0, 6, &x) == USB_FND_SUCCESS);
    assert(x.data[0] == errNOTDONE && x.data[4] == dfuERROR);
    assert(request(0x21, USB_REQ_DFU_CLRSTATUS, 0, 0, 0, &x) == USB_FND_SUCCESS);

    send_block(0, buf, 64);
    assert(request(0x21, USB_REQ_DFU_ABORT, 0, 0, 0, &x) == USB_FND_SUCCESS);
    read_info(info);
    assert(little32(info + 4) == 0 && info[14] == dfuIDLE);
    ulx5m_dfu_stage_reset(); /* emulate bus reset */
    read_info(info);
    assert(little32(info + 4) == 0);
    puts("[PASS] DFU RAM staging, CRC32, bounds, order, reset, no flash commit");
    return 0;
}
