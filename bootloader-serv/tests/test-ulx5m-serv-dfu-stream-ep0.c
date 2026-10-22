/*
 * Host-only integration test for real EP0 control-OUT firmware and discard-only streaming DFU.
 * Simulates USB endpoint RAM/BDs, NOT PHY, host ACK on wire, or SPI flash.
 * Build with ULX5M_EP0_HOST_TEST; no FPGA memory mappings are accessed.
 */
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "usb_priv.h"
#include "usb_hw.h"
#include "usb_dfu_proto.h"
#include "ulx5m_dfu_stream.h"

struct usb_stack g_usb;
static uint32_t usb_core_mem[65536u / sizeof(uint32_t)];
static uint8_t usb_data_mem[65536u];
volatile struct usb_core *usb_regs =
    (volatile struct usb_core *)(void *)usb_core_mem;
volatile struct usb_ep_pair *usb_ep_regs =
    (volatile struct usb_ep_pair *)(void *)&usb_core_mem[(1u << 13) / 4u];

void usb_data_read(void *dst, unsigned offset, int len)
{
    assert(len >= 0 && (unsigned)len <= sizeof(usb_data_mem) - offset);
    memcpy(dst, usb_data_mem + offset, (size_t)len);
}
void usb_data_write(unsigned offset, const void *src, int len)
{
    assert(len >= 0 && (unsigned)len <= sizeof(usb_data_mem) - offset);
    memcpy(usb_data_mem + offset, src, (size_t)len);
}

enum usb_fnd_resp usb_dispatch_ctrl_req(struct usb_ctrl_req *req,
                                        struct usb_xfer *xfer)
{
    return ulx5m_dfu_stream_req(req, xfer);
}

static void setup(uint8_t type, uint8_t command, uint16_t value,
                  uint16_t index, uint16_t length)
{
    struct usb_ctrl_req req = {
        .bmRequestType = type, .bRequest = command, .wValue = value,
        .wIndex = index, .wLength = length
    };
    memcpy(usb_data_mem + 64, &req, sizeof(req));
    usb_ep_regs[0].out.bd[1].csr =
        USB_BD_STATE_DONE_OK | USB_BD_IS_SETUP | USB_BD_LEN(10);
    usb_ep0_poll();
}

static void status_in_ack(void)
{
    assert(g_usb.ctrl.state == STATUS_DONE_IN);
    assert(usb_ep_regs[0].in.bd[0].csr ==
           (USB_BD_STATE_RDY_DATA | USB_BD_LEN(0)));
    usb_ep_regs[0].in.bd[0].csr = USB_BD_STATE_DONE_OK;
    usb_ep0_poll();
    assert(g_usb.ctrl.state == IDLE);
}

static void status_out_ack(void)
{
    assert(g_usb.ctrl.state == STATUS_DONE_OUT);
    usb_ep_regs[0].in.bd[0].csr = USB_BD_STATE_DONE_OK;
    usb_ep_regs[0].out.bd[0].csr = USB_BD_STATE_DONE_OK | USB_BD_LEN(2);
    usb_ep0_poll();
    assert(g_usb.ctrl.state == IDLE);
}

static void read_control(uint8_t type, uint8_t cmd,
                         uint16_t len, uint8_t *out)
{
    setup(type, cmd, 0, 0, len);
    assert(g_usb.ctrl.state == STATUS_DONE_OUT);
    assert(usb_ep_regs[0].in.bd[0].csr ==
           (USB_BD_STATE_RDY_DATA | USB_BD_LEN(len)));
    memcpy(out, usb_data_mem, len);
    status_out_ack();
}

static uint32_t little32(const uint8_t *p)
{
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) |
        ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static void info(uint8_t *p)
{
    read_control(0xc0, ULX5M_STREAM_INFO_REQ, 20, p);
    assert(memcmp(p, "STR1", 4) == 0);
}

static void get_status(uint8_t expect_status, uint8_t expect_state)
{
    uint8_t b[6];
    read_control(0xa1, USB_REQ_DFU_GETSTATUS, 6, b);
    assert(b[0] == expect_status && b[4] == expect_state);
    assert(b[1] == 0 && b[2] == 0 && b[3] == 0 && b[5] == 0);
}

static void send_out(uint16_t block, const uint8_t *data, uint16_t len)
{
    assert(len > 0 && len <= 64);
    setup(0x21, USB_REQ_DFU_DNLOAD, block, 0, len);
    assert(g_usb.ctrl.state == DATA_OUT);
    assert(usb_ep_regs[0].out.bd[0].csr ==
           (USB_BD_STATE_RDY_DATA | USB_BD_LEN(64)));
    memcpy(usb_data_mem, data, len);
    /* Endpoint BD completion includes the two received CRC16 bytes. */
    usb_ep_regs[0].out.bd[0].csr =
        USB_BD_STATE_DONE_OK | USB_BD_LEN(len + 2);
    usb_ep0_poll();
    assert(g_usb.ctrl.state == STATUS_DONE_IN);
}

int main(void)
{
    uint8_t bytes[64], result[20], state;
    for (unsigned i = 0; i < sizeof(bytes); ++i)
        bytes[i] = (uint8_t)i;
    ulx5m_dfu_stream_reset();
    usb_ep0_reset();

    read_control(0xa1, USB_REQ_DFU_GETSTATE, 1, &state);
    assert(state == dfuIDLE);

    /* No byte is committed until the status-IN ACK completes. */
    send_out(0, (const uint8_t *)"123456789", 9);
    {
        struct usb_ctrl_req req = {
            .bmRequestType = 0xc0, .bRequest = ULX5M_STREAM_INFO_REQ,
            .wLength = 20
        };
        struct usb_xfer snapshot = {.data = result, .len = 20};
        assert(ulx5m_dfu_stream_req(&req, &snapshot) == USB_FND_SUCCESS);
        assert(little32(result + 4) == 0);
    }
    status_in_ack();
    get_status(OK, dfuDNLOAD_IDLE);
    info(result);
    assert(little32(result + 4) == 9);
    assert(little32(result + 8) == 0xcbf43926u);
    assert(result[12] == 1 && result[14] == dfuDNLOAD_IDLE);

    /* A full 64-byte EP0 packet is accepted and staged, not flashed. */
    send_out(1, bytes, 64);
    status_in_ack();
    get_status(OK, dfuDNLOAD_IDLE);
    info(result);
    assert(little32(result + 4) == 73 && result[12] == 2);

    /* An interrupted transfer must not commit the unacknowledged block. */
    send_out(2, bytes, 4);
    setup(0xa1, USB_REQ_DFU_GETSTATE, 0, 0, 1);
    assert(g_usb.ctrl.state == STATUS_DONE_OUT);
    assert(usb_data_mem[0] == dfuDNLOAD_IDLE);
    status_out_ack();
    info(result);
    assert(little32(result + 4) == 73 && result[12] == 2);
    send_out(2, bytes, 4);
    status_in_ack();
    get_status(OK, dfuDNLOAD_IDLE);
    info(result);
    assert(little32(result + 4) == 77 && result[12] == 3);

    /* Wrong block number stalls EP0 and sets DFU error; CLRSTATUS recovers. */
    setup(0x21, USB_REQ_DFU_DNLOAD, 1, 0, 2);
    assert(g_usb.ctrl.state == STALL);
    assert(usb_ep_regs[0].in.bd[0].csr == USB_BD_STATE_RDY_STALL);
    get_status(errADDRESS, dfuERROR);
    setup(0x21, USB_REQ_DFU_CLRSTATUS, 0, 0, 0);
    status_in_ack();
    info(result);
    assert(little32(result + 4) == 0 && result[14] == dfuIDLE);

    /* Two 64-byte blocks followed by a zero-byte manifestation request.
     * The receiver MUST answer errNOTDONE, never successful programming. */
    send_out(0, bytes, 64);
    status_in_ack();
    get_status(OK, dfuDNLOAD_IDLE);
    send_out(1, bytes, 64);
    status_in_ack();
    get_status(OK, dfuDNLOAD_IDLE);
    setup(0x21, USB_REQ_DFU_DNLOAD, 2, 0, 0);
    status_in_ack();
    get_status(errNOTDONE, dfuERROR);

    /* A reset drops the volatile staging buffer. The production USB
     * stack invokes the registered DFU bus-reset callback separately. */
    ulx5m_dfu_stream_reset();
    usb_ep0_reset();
    info(result);
    assert(little32(result + 4) == 0 && result[14] == dfuIDLE);
    puts("[PASS] actual EP0 SETUP -> DATA OUT -> STATUS IN -> streaming DFU");
    puts("[PASS] 64-byte stream block, interrupted ACK, STALL, CLEAR, no flash");
    return 0;
}
