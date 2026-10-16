/*
 * ULX5M-GS V005 enumeration-only DFU diagnostic firmware.
 * This is NOT a flash bootloader; no SPI code or DFU write service is linked.
 * The diagnostic interface rejects DNLOAD and UPLOAD requests.
 */
#include <stdint.h>
#include "usb.h"
#include "usb_dfu_proto.h"

extern const struct usb_stack_descriptors ulx5m_probe_desc;

static enum usb_fnd_resp
probe_ctrl_req(struct usb_ctrl_req *req, struct usb_xfer *xfer)
{
    switch (req->wRequestAndType) {
    case USB_RT_DFU_GETSTATUS:
        xfer->data[0] = OK;
        xfer->data[1] = 0;
        xfer->data[2] = 0;
        xfer->data[3] = 0;
        xfer->data[4] = dfuIDLE;
        xfer->data[5] = 0;
        xfer->len = 6;
        return USB_FND_SUCCESS;
    case USB_RT_DFU_GETSTATE:
        xfer->data[0] = dfuIDLE;
        xfer->len = 1;
        return USB_FND_SUCCESS;
    case USB_RT_DFU_CLRSTATUS:
    case USB_RT_DFU_ABORT:
        xfer->len = 0;
        return USB_FND_SUCCESS;
    case USB_RT_DFU_DNLOAD:
    case USB_RT_DFU_UPLOAD:
    case USB_RT_DFU_DETACH:
        return USB_FND_ERROR;
    default:
        return USB_FND_CONTINUE;
    }
}

static enum usb_fnd_resp
probe_set_intf(const struct usb_intf_desc *base, const struct usb_intf_desc *sel)
{
    if (base->bInterfaceClass != 0xfe || sel->bAlternateSetting != 0)
        return USB_FND_CONTINUE;
    return USB_FND_SUCCESS;
}

static enum usb_fnd_resp
probe_get_intf(const struct usb_intf_desc *base, uint8_t *alt)
{
    if (base->bInterfaceClass != 0xfe)
        return USB_FND_CONTINUE;
    *alt = 0;
    return USB_FND_SUCCESS;
}

static struct usb_fn_drv probe_drv = {
    .ctrl_req = probe_ctrl_req,
    .set_intf = probe_set_intf,
    .get_intf = probe_get_intf,
};

/* usb.c calls this hook on each poll; never touch flash. */
void _dfu_tick(void) {}

void main(void)
{
    usb_init(&ulx5m_probe_desc);
    usb_register_function_driver(&probe_drv);
    usb_connect();
    while (1)
        usb_poll();
}
