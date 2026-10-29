/*
 * USB DFU enumeration probe descriptor for standalone ULX5M-GS development.
 * VID:PID below is inherited from ULX3S firmware for local bench testing;
 * it is NOT a registered ULX5M product identity. Do not distribute unchanged.
 * No alternate flash targets; bmAttributes indicates neither upload nor download.
 */
#include "usb.h"

#define NUM_ELEMENTS(a) (sizeof(a) / sizeof((a)[0]))

static const struct {
    struct usb_conf_desc conf;
    struct usb_intf_desc intf;
    struct usb_dfu_desc dfu;
} __attribute__((packed)) probe_conf = {
    .conf = {
        .bLength = sizeof(struct usb_conf_desc),
        .bDescriptorType = USB_DT_CONF,
        .wTotalLength = sizeof(probe_conf),
        .bNumInterfaces = 1,
        .bConfigurationValue = 1,
        .iConfiguration = 0,
        .bmAttributes = 0x80,
        .bMaxPower = 0x32,
    },
    .intf = {
        .bLength = sizeof(struct usb_intf_desc),
        .bDescriptorType = USB_DT_INTF,
        .bInterfaceNumber = 0,
        .bAlternateSetting = 0,
        .bNumEndpoints = 0,
        .bInterfaceClass = 0xfe,
        .bInterfaceSubClass = 0x01,
        .bInterfaceProtocol = 0x02,
        .iInterface = 0,
    },
    .dfu = {
        .bLength = sizeof(struct usb_dfu_desc),
        .bDescriptorType = USB_DT_DFU,
#ifdef ULX5M_DFU_STAGE_ONLY
        .bmAttributes = 0x01, /* canDnload only; RAM staging, not persistent */
#else
        .bmAttributes = 0x08, /* manifestation tolerant; no upload/download */
#endif
        .wDetachTimeOut = 0,
        .wTransferSize = 64,
        .bcdDFUVersion = 0x0110,
    },
};

/* USB string index 0 is the supported language (English - US).
 * Index 1 identifies this no-flash ULX5M-GS diagnostic probe.
 */
static const struct usb_str_desc probe_lang = {
    .bLength = 4,
    .bDescriptorType = USB_DT_STR,
    .wString = { 0x0409 },
};

static const struct usb_str_desc probe_product = {
    .bLength = 52, /* 2 + 25 UTF-16LE code units * 2 */
    .bDescriptorType = USB_DT_STR,
    .wString = {
        'U', 'L', 'X', '5', 'M', '-', 'G', 'S',
#ifdef ULX5M_DFU_STAGE_ONLY
        ' ', 'F', 'P', 'G', 'A', ' ', '(', 'D',
        'F', 'U', ' ', 'S', 't', 'a', 'g', 'e', ')',
#else
        ' ', 'F', 'P', 'G', 'A', ' ', '(', 'D',
        'F', 'U', ' ', 'P', 'r', 'o', 'b', 'e', ')',
#endif
    },
};

static const struct usb_str_desc * const probe_str_list[] = {
    &probe_lang,
    &probe_product,
};

static const struct usb_dev_desc probe_dev = {
    .bLength = sizeof(struct usb_dev_desc),
    .bDescriptorType = USB_DT_DEV,
    .bcdUSB = 0x0200,
    .bDeviceClass = 0,
    .bDeviceSubClass = 0,
    .bDeviceProtocol = 0,
    .bMaxPacketSize0 = 64,
    .idVendor = 0x1d50,
    .idProduct = 0x614b,
    .bcdDevice = 0x0001,
    .iManufacturer = 0,
    .iProduct = 1,
    .iSerialNumber = 0,
    .bNumConfigurations = 1,
};

static const struct usb_conf_desc * const probe_conf_list[] = {
    &probe_conf.conf,
};

const struct usb_stack_descriptors ulx5m_probe_desc = {
    .dev = &probe_dev,
    .bos = 0,
    .conf = probe_conf_list,
    .n_conf = NUM_ELEMENTS(probe_conf_list),
    .str = probe_str_list,
    .n_str = NUM_ELEMENTS(probe_str_list),
};
