/*
 * Experimental, VOLATILE DFU DNLOAD staging for ULX5M-GS SERV.
 * No flash erase/program/status-register commands, no reboot, no SPI access.
 * A zero-length DNLOAD deliberately reports errNOTDONE: nothing was flashed.
 */
#include <stdint.h>
#include "ulx5m_dfu_stage.h"
#include "usb_dfu_proto.h"

static struct {
    uint8_t data[ULX5M_STAGE_CAPACITY] __attribute__((aligned(4)));
    uint8_t pending[ULX5M_STAGE_BLOCK_MAX] __attribute__((aligned(4)));
    uint32_t used;
    uint32_t crc;
    uint16_t next_block;
    uint16_t pending_len;
    uint8_t state;
    uint8_t status;
} stage;

static void put32(uint8_t *p, uint32_t v)
{
    for (unsigned i = 0; i < 4; ++i)
        p[i] = (uint8_t)(v >> (8u * i));
}

static bool dnload_done(struct usb_xfer *xfer)
{
    if (xfer->data != stage.pending ||
        xfer->len != stage.pending_len ||
        xfer->ofs != stage.pending_len ||
        stage.pending_len > ULX5M_STAGE_CAPACITY - stage.used) {
        stage.status = errUSBR;
        stage.state = dfuERROR;
        return true;
    }
    for (unsigned i = 0; i < stage.pending_len; ++i) {
        uint8_t b = stage.pending[i];
        uint32_t crc = stage.crc ^ b;
        stage.data[stage.used + i] = b;
        for (unsigned j = 0; j < 8; ++j)
            crc = (crc >> 1) ^ ((crc & 1u) ? 0xedb88320u : 0u);
        stage.crc = crc;
    }
    stage.used += stage.pending_len;
    stage.next_block++;
    stage.pending_len = 0;
    stage.state = dfuDNLOAD_SYNC;
    return true;
}

static bool manifest_done(struct usb_xfer *xfer)
{
    (void)xfer;
    stage.state = dfuMANIFEST_SYNC;
    return true;
}

void ulx5m_dfu_stage_reset(void)
{
    stage.used = 0;
    stage.next_block = 0;
    stage.pending_len = 0;
    stage.crc = 0xffffffffu;
    stage.state = dfuIDLE;
    stage.status = OK;
    /* Drop staged contents on ABORT, CLRSTATUS and bus reset. */
    for (unsigned i = 0; i < ULX5M_STAGE_CAPACITY; ++i)
        stage.data[i] = 0;
    for (unsigned i = 0; i < ULX5M_STAGE_BLOCK_MAX; ++i)
        stage.pending[i] = 0;
}

static enum usb_fnd_resp fail(uint8_t status)
{
    stage.status = status;
    stage.state = dfuERROR;
    stage.pending_len = 0;
    return USB_FND_ERROR;
}

enum usb_fnd_resp ulx5m_dfu_stage_req(struct usb_ctrl_req *req,
                                      struct usb_xfer *xfer)
{
    if (req->bmRequestType == 0xc0u &&
        req->bRequest == ULX5M_STAGE_INFO_REQ) {
        if (req->wValue || req->wIndex ||
            req->wLength != ULX5M_STAGE_INFO_BYTES)
            return USB_FND_ERROR;
        xfer->data[0] = 'S';
        xfer->data[1] = 'T';
        xfer->data[2] = 'G';
        xfer->data[3] = '1';
        put32(xfer->data + 4, stage.used);
        put32(xfer->data + 8, stage.crc ^ 0xffffffffu);
        xfer->data[12] = (uint8_t)stage.next_block;
        xfer->data[13] = (uint8_t)(stage.next_block >> 8);
        xfer->data[14] = stage.state;
        xfer->data[15] = stage.status;
        xfer->len = ULX5M_STAGE_INFO_BYTES;
        return USB_FND_SUCCESS;
    }

    /* Only class requests to interface 0; leave vendor diagnostics alone. */
    if (req->bmRequestType != 0x21u && req->bmRequestType != 0xa1u)
        return USB_FND_CONTINUE;
    if (req->wIndex)
        return USB_FND_ERROR;

    switch (req->wRequestAndType) {
    case USB_RT_DFU_DNLOAD:
        if (stage.state != dfuIDLE && stage.state != dfuDNLOAD_IDLE)
            return fail(errSTALLEDPKT);
        if (req->wValue != stage.next_block)
            return fail(errADDRESS);
        if (!req->wLength) {
            if (!stage.used)
                return fail(errNOTDONE);
            xfer->len = 0;
            xfer->cb_done = manifest_done;
            return USB_FND_SUCCESS;
        }
        if (req->wLength > ULX5M_STAGE_BLOCK_MAX ||
            req->wLength > ULX5M_STAGE_CAPACITY - stage.used)
            return fail(errADDRESS);
        stage.pending_len = req->wLength;
        xfer->data = stage.pending;
        xfer->len = req->wLength;
        xfer->cb_done = dnload_done;
        return USB_FND_SUCCESS;

    case USB_RT_DFU_GETSTATUS:
        if (req->wValue || req->wLength != 6u)
            return USB_FND_ERROR;
        if (stage.state == dfuDNLOAD_SYNC)
            stage.state = dfuDNLOAD_IDLE;
        else if (stage.state == dfuMANIFEST_SYNC) {
            /* Intentionally refuse to claim a successful flash operation. */
            stage.state = dfuERROR;
            stage.status = errNOTDONE;
        }
        xfer->data[0] = stage.status;
        xfer->data[1] = 0; /* bwPollTimeout = 0 ms, no flash work */
        xfer->data[2] = 0;
        xfer->data[3] = 0;
        xfer->data[4] = stage.state;
        xfer->data[5] = 0;
        xfer->len = 6;
        return USB_FND_SUCCESS;

    case USB_RT_DFU_GETSTATE:
        if (req->wValue || req->wLength != 1u)
            return USB_FND_ERROR;
        xfer->data[0] = stage.state;
        xfer->len = 1;
        return USB_FND_SUCCESS;

    case USB_RT_DFU_CLRSTATUS:
        if (req->wValue || req->wLength || stage.state != dfuERROR)
            return USB_FND_ERROR;
        ulx5m_dfu_stage_reset();
        xfer->len = 0;
        return USB_FND_SUCCESS;

    case USB_RT_DFU_ABORT:
        if (req->wValue || req->wLength ||
            (stage.state != dfuIDLE && stage.state != dfuDNLOAD_SYNC &&
             stage.state != dfuDNLOAD_IDLE))
            return USB_FND_ERROR;
        ulx5m_dfu_stage_reset();
        xfer->len = 0;
        return USB_FND_SUCCESS;

    case USB_RT_DFU_UPLOAD:
    case USB_RT_DFU_DETACH:
        return USB_FND_ERROR;
    default:
        return USB_FND_CONTINUE;
    }
}
