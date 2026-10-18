/* ULX5M-GS V005: read-only JEDEC ID / 0x03 SPI flash diagnostic.
 * Vendor USB IN requests only. DFU upload/download/erase/program disabled.
 * Board U9: AT25QL321-MBUE-T, nominal 4 MiB, 1.8 V.
 */
#include <stdint.h>
#include "config.h"
#include "usb.h"
#include "usb_dfu_proto.h"

extern const struct usb_stack_descriptors ulx5m_probe_desc;

#define FLASH_BYTES          0x400000u
#define FLASH_READ_MAX       32u
#define USB_REQ_FLASH_ID     0x51u
#define USB_REQ_FLASH_READ   0x52u
#define SPI_CS_HIGH          0x00010f00u
#define SPI_CS_LOW           0x00000f00u
#define SPI_RX_PENDING       0x80000000u
#define SPI_RX_TIMEOUT       100000u

struct spi_regs {
    volatile uint32_t csr;
    volatile uint32_t data;
};
static struct spi_regs * const spi = (void *)SPI_BASE;

/* Only 0x9f and 0x03 are transmitted as flash commands. */
static void flash_begin(void)
{
    spi->csr = SPI_CS_LOW;
}

static void flash_end(void)
{
    spi->csr = SPI_CS_HIGH;
}

static void flash_send(uint8_t byte)
{
    spi->data = byte;
}

static int flash_receive(uint8_t *byte)
{
    uint32_t word;
    unsigned timeout = SPI_RX_TIMEOUT;

    spi->data = 0x100u; /* one 8-bit read, transmit dummy 0 */
    do {
        word = spi->data;
        if (!(word & SPI_RX_PENDING)) {
            *byte = (uint8_t)word;
            return 1;
        }
    } while (--timeout);
    return 0;
}

static int flash_jedec(uint8_t *buf)
{
    int ok = 1;
    flash_begin();
    flash_send(0x9fu); /* JEDEC RDID */
    for (unsigned i = 0; i < 3; i++) {
        if (!flash_receive(&buf[i])) {
            ok = 0;
            break;
        }
    }
    flash_end();
    return ok;
}

static int flash_read_bytes(uint32_t addr, uint8_t *buf, unsigned len)
{
    int ok = 1;
    flash_begin();
    flash_send(0x03u); /* normal read with 24-bit address */
    flash_send((uint8_t)(addr >> 16));
    flash_send((uint8_t)(addr >> 8));
    flash_send((uint8_t)addr);
    for (unsigned i = 0; i < len; i++) {
        if (!flash_receive(&buf[i])) {
            ok = 0;
            break;
        }
    }
    flash_end();
    return ok;
}

static enum usb_fnd_resp
flash_ctrl_req(struct usb_ctrl_req *req, struct usb_xfer *xfer)
{
    uint32_t addr;
    unsigned len;

    /* Vendor-to-device IN, no OUT requests or persistent state changes. */
    if (req->bmRequestType == 0xc0u && req->bRequest == USB_REQ_FLASH_ID) {
        if (req->wValue || req->wIndex || req->wLength != 3)
            return USB_FND_ERROR;
        if (!flash_jedec(xfer->data))
            return USB_FND_ERROR;
        xfer->len = 3;
        return USB_FND_SUCCESS;
    }
    if (req->bmRequestType == 0xc0u && req->bRequest == USB_REQ_FLASH_READ) {
        addr = ((uint32_t)req->wIndex << 16) | req->wValue;
        len = req->wLength;
        if (!len || len > FLASH_READ_MAX ||
            addr >= FLASH_BYTES || len > FLASH_BYTES - addr)
            return USB_FND_ERROR;
        if (!flash_read_bytes(addr, xfer->data, len))
            return USB_FND_ERROR;
        xfer->len = (int)len;
        return USB_FND_SUCCESS;
    }
    switch (req->wRequestAndType) {
    case USB_RT_DFU_GETSTATUS:
        xfer->data[0] = OK;
        xfer->data[1] = xfer->data[2] = xfer->data[3] = 0;
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
flash_set_intf(const struct usb_intf_desc *base, const struct usb_intf_desc *sel)
{
    if (base->bInterfaceClass != 0xfe || sel->bAlternateSetting != 0)
        return USB_FND_CONTINUE;
    return USB_FND_SUCCESS;
}

static enum usb_fnd_resp
flash_get_intf(const struct usb_intf_desc *base, uint8_t *alt)
{
    if (base->bInterfaceClass != 0xfe)
        return USB_FND_CONTINUE;
    *alt = 0;
    return USB_FND_SUCCESS;
}

static struct usb_fn_drv flash_drv = {
    .ctrl_req = flash_ctrl_req,
    .set_intf = flash_set_intf,
    .get_intf = flash_get_intf,
};

void _dfu_tick(void) {}

void main(void)
{
    flash_end(); /* deselect flash, release IO2/IO3 using CSR 0xF */
    usb_init(&ulx5m_probe_desc);
    usb_register_function_driver(&flash_drv);
    usb_connect();
    while (1)
        usb_poll();
}
