/* ULX5M-GS SERV bootloader firmware.
 * The DFU test profile can arm only one 4 KiB candidate sector.
 * Board U9: AT25QL321-MBUE-T, nominal 4 MiB, 1.8 V.
 */
#include <stdint.h>
#include "config.h"
#include "usb.h"
#include "usb_dfu_proto.h"
#ifdef ULX5M_DFU_STAGE_ONLY
#include "ulx5m_dfu_stage.h"
#include "ulx5m_flash_layout.h"
#endif
#ifdef ULX5M_DFU_STREAM_ONLY
#include "ulx5m_dfu_stream.h"
#include "ulx5m_flash_layout.h"
#include "ulx5m_at25ql321_hw.h"
#ifdef ULX5M_FLASH_HW_TEST
#include "ulx5m_flash_hw_test.h"
#endif
#endif
#ifdef ULX5M_SERV_TEST
#include "usb_ep0_diag.h"
#endif

extern const struct usb_stack_descriptors ulx5m_probe_desc;

#define FLASH_BYTES          0x400000u
#if defined(ULX5M_DFU_STAGE_ONLY) || defined(ULX5M_DFU_STREAM_ONLY)
_Static_assert(FLASH_BYTES == ULX5M_FLASH_BYTES, "ULX5M flash size mismatch");
#endif
#define FLASH_READ_MAX       32u
#define USB_REQ_FLASH_ID     0x51u
#define USB_REQ_FLASH_READ   0x52u
#ifdef ULX5M_DFU_STREAM_ONLY
#define USB_REQ_AT25_STATUS  0x5au
#define USB_REQ_AT25_READ    0x5bu
#endif
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
#ifdef ULX5M_SERV_TEST
    if (req->bmRequestType == 0xc0u &&
        req->bRequest == USB_EP0_DIAG_SHORT_REQ) {
        if (req->wValue >= USB_EP0_DIAG_SHORT_PAGES || req->wIndex ||
            req->wLength != USB_EP0_DIAG_SHORT_BYTES)
            return USB_FND_ERROR;
        usb_ep0_diag_short_snapshot(xfer->data, req->wValue);
        xfer->len = USB_EP0_DIAG_SHORT_BYTES;
        return USB_FND_SUCCESS;
    }
    // Frozen 48 MHz IDDR waveform. Page 0 is the header; pages 1..16
    // contain 256 chronological sample bytes. Read only; no flash access.
    if (req->bmRequestType == 0xc0u &&
        req->bRequest == USB_EP0_RAW_READ_REQ) {
        unsigned page = req->wValue;
        if (page >= USB_EP0_RAW_PAGES || req->wIndex ||
            req->wLength != USB_EP0_RAW_PAGE_BYTES)
            return USB_FND_ERROR;
        if (page == 0) {
            uint32_t status = *(volatile const uint32_t *)
                (uintptr_t)(USB_CORE_BASE + 0xccu);
            uint32_t count = *(volatile const uint32_t *)
                (uintptr_t)(USB_CORE_BASE + 0xd0u);
            const uint32_t hdr[4] = {
                0x31575255u, // "URW1" little-endian
                (count << 16) | (status & 0xffffu),
                *(volatile const uint32_t *)
                    (uintptr_t)(USB_CORE_BASE + 0xc8u),
                *(volatile const uint32_t *)
                    (uintptr_t)(USB_CORE_BASE + 0xc0u)
            };
            for (unsigned i = 0; i < 4; ++i) {
                uint32_t v = hdr[i];
                for (unsigned b = 0; b < 4; ++b)
                    xfer->data[i*4u+b] = (uint8_t)(v >> (8u*b));
            }
        } else {
            volatile const uint32_t * const raw =
                (volatile const uint32_t *)(uintptr_t)
                (USB_CORE_BASE + 0x100u + ((page - 1u) * 32u));
            for (unsigned i = 0; i < 8; ++i) {
                uint32_t value = raw[i];
                xfer->data[2u*i] = (uint8_t)value;
                xfer->data[2u*i+1] = (uint8_t)(value >> 8);
            }
        }
        xfer->len = USB_EP0_RAW_PAGE_BYTES;
        return USB_FND_SUCCESS;
    }
    if (req->bmRequestType == 0x40u &&
        req->bRequest == USB_EP0_RAW_ARM_REQ) {
        if (req->wValue || req->wIndex || req->wLength)
            return USB_FND_ERROR;
        *(volatile uint32_t *)(uintptr_t)(USB_CORE_BASE + 0xfcu) = 1u;
        xfer->len = 0;
        return USB_FND_SUCCESS;
    }
    if (req->bmRequestType == 0xc0u && req->bRequest == USB_EP0_DIAG_REQ) {
        if (req->wValue || req->wIndex || req->wLength != USB_EP0_DIAG_BYTES)
            return USB_FND_ERROR;
        usb_ep0_diag_snapshot(xfer->data);
        xfer->len = USB_EP0_DIAG_BYTES;
        return USB_FND_SUCCESS;
    }
#endif
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
#ifdef ULX5M_DFU_STREAM_ONLY
    /* Independent read-only AT25QL321 command driver over the same SPI MMIO. */
    if (req->bmRequestType == 0xc0u &&
        req->bRequest == USB_REQ_AT25_STATUS) {
        struct ulx5m_at25ql321_hw hw;
        struct ulx5m_at25ql321 dev;
        uint8_t id[3];
        uint8_t status;
        if (req->wValue || req->wIndex || req->wLength != 8u)
            return USB_FND_ERROR;
        ulx5m_at25ql321_hw_init(&hw, SPI_BASE);
        ulx5m_at25ql321_hw_bind(&dev, &hw);
        if (ulx5m_at25ql321_identify(&dev, id) != ULX5M_AT25_OK ||
            ulx5m_at25ql321_status(&dev, &status) != ULX5M_AT25_OK)
            return USB_FND_ERROR;
        xfer->data[0] = 'A'; xfer->data[1] = '2';
        xfer->data[2] = '5'; xfer->data[3] = '1';
        xfer->data[4] = id[0]; xfer->data[5] = id[1];
        xfer->data[6] = id[2]; xfer->data[7] = status;
        xfer->len = 8;
        return USB_FND_SUCCESS;
    }
    if (req->bmRequestType == 0xc0u &&
        req->bRequest == USB_REQ_AT25_READ) {
        struct ulx5m_at25ql321_hw hw;
        struct ulx5m_at25ql321 dev;
        uint8_t id[3];
        addr = ((uint32_t)req->wIndex << 16) | req->wValue;
        len = req->wLength;
        if (!len || len > FLASH_READ_MAX || addr >= FLASH_BYTES ||
            len > FLASH_BYTES - addr)
            return USB_FND_ERROR;
        ulx5m_at25ql321_hw_init(&hw, SPI_BASE);
        ulx5m_at25ql321_hw_bind(&dev, &hw);
        if (ulx5m_at25ql321_identify(&dev, id) != ULX5M_AT25_OK ||
            ulx5m_at25ql321_read(&dev, addr, xfer->data, len) != ULX5M_AT25_OK)
            return USB_FND_ERROR;
        xfer->len = (int)len;
        return USB_FND_SUCCESS;
    }
#endif
#if defined(ULX5M_DFU_STAGE_ONLY) || defined(ULX5M_DFU_STREAM_ONLY)
    /* Read-only provisional layout; no SPI command is issued. */
    if (req->bmRequestType == 0xc0u &&
        req->bRequest == ULX5M_FLASH_LAYOUT_REQ) {
        if (req->wValue || req->wIndex ||
            req->wLength != ULX5M_FLASH_LAYOUT_BYTES)
            return USB_FND_ERROR;
        ulx5m_flash_layout_encode(xfer->data);
        xfer->len = ULX5M_FLASH_LAYOUT_BYTES;
        return USB_FND_SUCCESS;
    }
    /* Experimental receiver, never installed in the golden build. */
#ifdef ULX5M_DFU_STREAM_ONLY
#ifdef ULX5M_FLASH_HW_TEST
    {
        enum usb_fnd_resp response = ulx5m_flash_hw_test_req(req, xfer);
        if (response != USB_FND_CONTINUE)
            return response;
    }
#endif
    return ulx5m_dfu_stream_req(req, xfer);
#else
    return ulx5m_dfu_stage_req(req, xfer);
#endif
#else
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
#endif
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
#ifdef ULX5M_DFU_STAGE_ONLY
    .bus_reset = ulx5m_dfu_stage_reset,
#elif defined(ULX5M_DFU_STREAM_ONLY)
    .bus_reset = ulx5m_dfu_stream_reset,
#endif
    .ctrl_req = flash_ctrl_req,
    .set_intf = flash_set_intf,
    .get_intf = flash_get_intf,
};

#ifdef ULX5M_NORMAL_MODE
#define MISC_MODE (*(volatile uint32_t *)(uintptr_t)(HAD_MISC_BASE + 4u))
#define MISC_LEDS (*(volatile uint32_t *)(uintptr_t)(HAD_MISC_BASE))

static void normal_mode_main(void)
{
    /* Autonomous 25 MHz CC_CFG_CTRL owns the normal-mode transition.
     * Do NOT read U9, write CONFIG MMIO, or start another SPI handoff here.
     * D0 is a pre-handoff witness; secondary boot owns LEDs afterwards.
     */
    MISC_LEDS = 1u;
    while (1) { }
}
#endif

void _dfu_tick(void) {}

void main(void)
{
#ifdef ULX5M_NORMAL_MODE
    if ((MISC_MODE & 3u) == 1u)
        normal_mode_main();
#endif
#ifdef ULX5M_DFU_STAGE_ONLY
    ulx5m_dfu_stage_reset();
#elif defined(ULX5M_DFU_STREAM_ONLY)
    ulx5m_dfu_stream_reset();
#endif
    flash_end(); /* deselect flash, release IO2/IO3 using CSR 0xF */
    usb_init(&ulx5m_probe_desc);
    usb_register_function_driver(&flash_drv);
    usb_connect();
    while (1)
        usb_poll();
}
