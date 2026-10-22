/* Discard-only streaming DFU unit test. No hardware or SPI flash. */
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "usb_dfu_proto.h"
#include "ulx5m_dfu_stream.h"

static uint8_t scratch[64];
static enum usb_fnd_resp request(uint8_t type, uint8_t cmd,
                                 unsigned value, unsigned index, unsigned len,
                                 struct usb_xfer *x)
{
    struct usb_ctrl_req r = {
        .bmRequestType = type, .bRequest = cmd, .wValue = value,
        .wIndex = index, .wLength = len
    };
    memset(x, 0, sizeof(*x));
    x->data = scratch;
    x->len = sizeof(scratch);
    return ulx5m_dfu_stream_req(&r, x);
}
static uint32_t le32(const uint8_t *b)
{
    return (uint32_t)b[0] | ((uint32_t)b[1] << 8) |
           ((uint32_t)b[2] << 16) | ((uint32_t)b[3] << 24);
}
static void info(uint32_t used, uint32_t crc, unsigned next, unsigned state)
{
    struct usb_xfer x;
    assert(request(0xc0, ULX5M_STREAM_INFO_REQ, 0, 0, 20, &x) == USB_FND_SUCCESS);
    assert(x.len == 20 && !memcmp(x.data, "STR1", 4));
    assert(le32(x.data + 4) == used && le32(x.data + 8) == crc);
    assert((unsigned)x.data[12] + ((unsigned)x.data[13] << 8) == next);
    assert(x.data[14] == state && le32(x.data + 16) == ULX5M_STREAM_MAX_BYTES);
}
static uint32_t crc_step(uint32_t crc, uint8_t b)
{
    crc ^= b;
    for (unsigned i = 0; i < 8; ++i)
        crc = (crc >> 1) ^ ((crc & 1u) ? 0xedb88320u : 0u);
    return crc;
}
static void send(unsigned n, unsigned len, uint32_t *crc)
{
    struct usb_xfer x;
    assert(request(0x21, USB_REQ_DFU_DNLOAD, n, 0, len, &x) == USB_FND_SUCCESS);
    assert(x.data != scratch && x.len == (int)len && x.cb_done);
    for (unsigned i = 0; i < len; ++i) {
        uint8_t b = (uint8_t)(n ^ i ^ (n >> 8));
        x.data[i] = b;
        *crc = crc_step(*crc, b);
    }
    x.ofs = len;
    assert(x.cb_done(&x));
    assert(request(0xa1, USB_REQ_DFU_GETSTATUS, 0, 0, 6, &x) == USB_FND_SUCCESS);
    assert(x.data[0] == OK && x.data[4] == dfuDNLOAD_IDLE);
}
int main(void)
{
    struct usb_xfer x;
    uint32_t crc = 0xffffffffu;
    ulx5m_dfu_stream_reset();
    info(0, 0, 0, dfuIDLE);
    assert(request(0xc0, ULX5M_STREAM_INFO_REQ, 0, 0, 19, &x) == USB_FND_ERROR);
    assert(request(0x21, USB_REQ_DFU_DNLOAD, 0, 1, 4, &x) == USB_FND_ERROR);
    assert(request(0xa1, USB_REQ_DFU_UPLOAD, 0, 0, 4, &x) == USB_FND_ERROR);
    assert(request(0x21, USB_REQ_DFU_DNLOAD, 0, 0, 65, &x) == USB_FND_ERROR);
    assert(request(0x21, USB_REQ_DFU_CLRSTATUS, 0, 0, 0, &x) == USB_FND_SUCCESS);
    assert(request(0x21, USB_REQ_DFU_DNLOAD, 0, 0, 0, &x) == USB_FND_ERROR);
    assert(request(0x21, USB_REQ_DFU_CLRSTATUS, 0, 0, 0, &x) == USB_FND_SUCCESS);

    /* Exercise 2 MiB without accumulating a payload in SRAM. */
    for (unsigned n = 0; n < ULX5M_STREAM_MAX_BYTES / 64u; ++n) {
        send(n, 64, &crc);
        if ((n & 1023u) == 1023u)
            info((n + 1u) * 64u, crc ^ 0xffffffffu, n + 1u,
                 dfuDNLOAD_IDLE);
    }
    info(ULX5M_STREAM_MAX_BYTES, crc ^ 0xffffffffu,
         ULX5M_STREAM_MAX_BYTES / 64u, dfuDNLOAD_IDLE);
    assert(request(0x21, USB_REQ_DFU_DNLOAD, 32768, 0, 1, &x) == USB_FND_ERROR);
    assert(request(0xa1, USB_REQ_DFU_GETSTATE, 0, 0, 1, &x) == USB_FND_SUCCESS);
    assert(x.data[0] == dfuERROR);
    assert(request(0x21, USB_REQ_DFU_CLRSTATUS, 0, 0, 0, &x) == USB_FND_SUCCESS);
    info(0, 0, 0, dfuIDLE);

    crc = 0xffffffffu;
    send(0, 9, &crc);
    assert(request(0x21, USB_REQ_DFU_DNLOAD, 1, 0, 0, &x) == USB_FND_SUCCESS);
    assert(x.cb_done(&x));
    assert(request(0xa1, USB_REQ_DFU_GETSTATUS, 0, 0, 6, &x) == USB_FND_SUCCESS);
    assert(x.data[0] == errNOTDONE && x.data[4] == dfuERROR);
    assert(request(0x21, USB_REQ_DFU_CLRSTATUS, 0, 0, 0, &x) == USB_FND_SUCCESS);

    crc = 0xffffffffu;
    send(0, 64, &crc);
    assert(request(0x21, USB_REQ_DFU_ABORT, 0, 0, 0, &x) == USB_FND_SUCCESS);
    info(0, 0, 0, dfuIDLE);
    crc = 0xffffffffu;
    send(0, 64, &crc);
    ulx5m_dfu_stream_reset();
    info(0, 0, 0, dfuIDLE);
    puts("[PASS] STR1 streaming 2 MiB, CRC32, 32768 ordered blocks, manifest refused");
    puts("[PASS] ABORT/CLRSTATUS/reset and no flash commit");
    return 0;
}
