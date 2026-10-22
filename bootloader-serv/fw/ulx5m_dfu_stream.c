/*
 * ULX5M-GS: discard-only DFU streaming proof of concept.
 * It measures ordered blocks and CRC32, without retaining an image.
 * NO flash erase/program/write-enable/SPI commands exist in this module.
 * A zero-length DNLOAD cannot report a successful manifestation.
 */
#include <stdint.h>
#include "ulx5m_dfu_stream.h"
#include "usb_dfu_proto.h"

#if defined(__riscv) && defined(ULX5M_DFU_STREAM_EMULATOR_TEST)
#error "DFU emulator sink must never be built for RISC-V hardware"
#endif

#ifdef ULX5M_DFU_STREAM_EMULATOR_TEST
/* Compile-time native emulator hook, absent from the FPGA firmware. */
static int (*stream_test_sink)(uint32_t, const uint8_t *, unsigned);
void ulx5m_dfu_stream_set_test_sink(
    int (*sink)(uint32_t, const uint8_t *, unsigned))
{
    stream_test_sink = sink;
}
#endif

static struct {
    uint8_t pending[ULX5M_STREAM_BLOCK_BYTES] __attribute__((aligned(4)));
    uint32_t used;
    uint32_t crc;
    uint16_t next_block;
    uint16_t pending_len;
    uint8_t state;
    uint8_t status;
} stream;

static void put32(uint8_t *p, uint32_t v)
{
    for (unsigned i = 0; i < 4; ++i)
        p[i] = (uint8_t)(v >> (8u * i));
}

void ulx5m_dfu_stream_reset(void)
{
    stream.used = 0;
    stream.crc = 0xffffffffu;
    stream.next_block = 0;
    stream.pending_len = 0;
    stream.state = dfuIDLE;
    stream.status = OK;
    for (unsigned i = 0; i < ULX5M_STREAM_BLOCK_BYTES; ++i)
        stream.pending[i] = 0;
}

static enum usb_fnd_resp fail(uint8_t error)
{
    stream.state = dfuERROR;
    stream.status = error;
    stream.pending_len = 0;
    return USB_FND_ERROR;
}

static bool block_done(struct usb_xfer *xfer)
{
    if (xfer->data != stream.pending ||
        xfer->len != stream.pending_len ||
        xfer->ofs != stream.pending_len ||
        !stream.pending_len ||
        stream.pending_len > ULX5M_STREAM_MAX_BYTES - stream.used) {
        stream.state = dfuERROR;
        stream.status = errUSBR;
        return true;
    }
#ifdef ULX5M_DFU_STREAM_EMULATOR_TEST
    if (stream_test_sink &&
        stream_test_sink(stream.used, stream.pending, stream.pending_len)) {
        stream.state = dfuERROR;
        stream.status = errWRITE;
        stream.pending_len = 0;
        return true;
    }
#endif
    for (unsigned i = 0; i < stream.pending_len; ++i) {
        uint32_t crc = stream.crc ^ stream.pending[i];
        for (unsigned bit = 0; bit < 8; ++bit)
            crc = (crc >> 1) ^ ((crc & 1u) ? 0xedb88320u : 0u);
        stream.crc = crc;
    }
    stream.used += stream.pending_len;
    stream.next_block++;
    stream.pending_len = 0;
    stream.state = dfuDNLOAD_SYNC;
    return true;
}

static bool manifest_done(struct usb_xfer *xfer)
{
    (void)xfer;
    stream.state = dfuMANIFEST_SYNC;
    return true;
}

enum usb_fnd_resp ulx5m_dfu_stream_req(struct usb_ctrl_req *req,
                                       struct usb_xfer *xfer)
{
    if (req->bmRequestType == 0xc0u &&
        req->bRequest == ULX5M_STREAM_INFO_REQ) {
        if (req->wValue || req->wIndex ||
            req->wLength != ULX5M_STREAM_INFO_BYTES)
            return USB_FND_ERROR;
        xfer->data[0] = 'S';
        xfer->data[1] = 'T';
        xfer->data[2] = 'R';
        xfer->data[3] = '1';
        put32(xfer->data + 4, stream.used);
        put32(xfer->data + 8, stream.crc ^ 0xffffffffu);
        xfer->data[12] = (uint8_t)stream.next_block;
        xfer->data[13] = (uint8_t)(stream.next_block >> 8);
        xfer->data[14] = stream.state;
        xfer->data[15] = stream.status;
        put32(xfer->data + 16, ULX5M_STREAM_MAX_BYTES);
        xfer->len = ULX5M_STREAM_INFO_BYTES;
        return USB_FND_SUCCESS;
    }
    if (req->bmRequestType != 0x21u && req->bmRequestType != 0xa1u)
        return USB_FND_CONTINUE;
    if (req->wIndex)
        return USB_FND_ERROR;

    switch (req->wRequestAndType) {
    case USB_RT_DFU_DNLOAD:
        if (stream.state != dfuIDLE && stream.state != dfuDNLOAD_IDLE)
            return fail(errSTALLEDPKT);
        if (req->wValue != stream.next_block)
            return fail(errADDRESS);
        if (!req->wLength) {
            if (!stream.used)
                return fail(errNOTDONE);
            xfer->len = 0;
            xfer->cb_done = manifest_done;
            return USB_FND_SUCCESS;
        }
        if (req->wLength > ULX5M_STREAM_BLOCK_BYTES ||
            req->wLength > ULX5M_STREAM_MAX_BYTES - stream.used)
            return fail(errADDRESS);
        stream.pending_len = req->wLength;
        xfer->data = stream.pending;
        xfer->len = req->wLength;
        xfer->cb_done = block_done;
        return USB_FND_SUCCESS;

    case USB_RT_DFU_GETSTATUS:
        if (req->wValue || req->wLength != 6u)
            return USB_FND_ERROR;
        if (stream.state == dfuDNLOAD_SYNC)
            stream.state = dfuDNLOAD_IDLE;
        else if (stream.state == dfuMANIFEST_SYNC) {
            stream.state = dfuERROR;
            stream.status = errNOTDONE;
        }
        xfer->data[0] = stream.status;
        xfer->data[1] = 0;
        xfer->data[2] = 0;
        xfer->data[3] = 0;
        xfer->data[4] = stream.state;
        xfer->data[5] = 0;
        xfer->len = 6;
        return USB_FND_SUCCESS;

    case USB_RT_DFU_GETSTATE:
        if (req->wValue || req->wLength != 1u)
            return USB_FND_ERROR;
        xfer->data[0] = stream.state;
        xfer->len = 1;
        return USB_FND_SUCCESS;

    case USB_RT_DFU_CLRSTATUS:
        if (req->wValue || req->wLength || stream.state != dfuERROR)
            return USB_FND_ERROR;
        ulx5m_dfu_stream_reset();
        xfer->len = 0;
        return USB_FND_SUCCESS;

    case USB_RT_DFU_ABORT:
        if (req->wValue || req->wLength ||
            (stream.state != dfuIDLE && stream.state != dfuDNLOAD_SYNC &&
             stream.state != dfuDNLOAD_IDLE))
            return USB_FND_ERROR;
        ulx5m_dfu_stream_reset();
        xfer->len = 0;
        return USB_FND_SUCCESS;

    case USB_RT_DFU_UPLOAD:
    case USB_RT_DFU_DETACH:
        return USB_FND_ERROR;
    default:
        return USB_FND_CONTINUE;
    }
}
