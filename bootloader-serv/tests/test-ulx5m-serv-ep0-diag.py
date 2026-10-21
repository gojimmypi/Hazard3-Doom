#!/usr/bin/env python3
"""Host simulation of SERV EP0 counters and the pre-SETUP snapshot.

Compiles the actual usb_ctrl_ep0.c with RAM-backed fake USB registers.
Does not access the real FPGA or host USB device.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile

FW = Path(__file__).resolve().parents[1] / "fw"
HARNESS = r'''
#define _GNU_SOURCE
#include <assert.h>
#include <stdint.h>
#include <string.h>
#include "usb_priv.h"
#include "usb_hw.h"
#include "usb_ep0_diag.h"

struct usb_stack g_usb;

/* The test must not require WSL/Linux to map FPGA physical addresses. */
static uint32_t usb_core_mem[65536u / sizeof(uint32_t)];
static uint8_t usb_data_mem[65536u];
volatile struct usb_core *usb_regs =
    (volatile struct usb_core *)(void *)usb_core_mem;
volatile struct usb_ep_pair *usb_ep_regs =
    (volatile struct usb_ep_pair *)(void *)&usb_core_mem[(1u << 13) / 4u];

void usb_data_read(void *dst, unsigned offset, int len)
{
    memcpy(dst, usb_data_mem + offset, (size_t)len);
}
void usb_data_write(unsigned offset, const void *src, int len)
{
    memcpy(usb_data_mem + offset, src, (size_t)len);
}

enum usb_fnd_resp usb_dispatch_ctrl_req(struct usb_ctrl_req *req,
                                        struct usb_xfer *xfer)
{
    if (req->bmRequestType == 0xc0 && req->bRequest == USB_EP0_DIAG_REQ) {
        usb_ep0_diag_snapshot(xfer->data);
        xfer->len = USB_EP0_DIAG_BYTES;
    } else if (req->bmRequestType == 0xc0 &&
               req->bRequest == USB_EP0_DIAG_SHORT_REQ) {
        assert(req->wValue < USB_EP0_DIAG_SHORT_PAGES);
        usb_ep0_diag_short_snapshot(xfer->data, req->wValue);
        xfer->len = USB_EP0_DIAG_SHORT_BYTES;
    } else {
        xfer->data[0] = 0x12;
        xfer->data[1] = 0x01;
        xfer->len = 18;
    }
    return USB_FND_SUCCESS;
}

static void submit_setup_with_page(uint8_t type, uint8_t request,
                                   uint16_t length, uint16_t page)
{
    struct usb_ctrl_req req = {0};
    req.bmRequestType = type;
    req.bRequest = request;
    req.wLength = length;
    req.wValue = page;
    memcpy(usb_data_mem + 64u, &req, sizeof(req));
    usb_ep_regs[0].out.bd[1].csr = USB_BD_STATE_DONE_OK | USB_BD_IS_SETUP;
    usb_ep0_poll();
}

static void submit_setup(uint8_t type, uint8_t request, uint16_t length)
{
    submit_setup_with_page(type, request, length, 0);
}

static uint32_t word(int n)
{
    uint8_t *p = g_usb.ctrl.buf + (n * 4);
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) |
           ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

int main(void)
{
    usb_ep0_reset();
    assert(usb_ep_regs[0].out.bd[1].csr ==
           (USB_BD_STATE_RDY_DATA | USB_BD_LEN(64)));

    submit_setup(0x80, 0x06, 18);
    assert(g_usb.ctrl.state == STATUS_DONE_OUT);
    usb_ep_regs[0].in.bd[0].csr = USB_BD_STATE_DONE_OK | 18u;
    usb_ep_regs[0].out.bd[0].csr = USB_BD_STATE_DONE_OK | 2u;
    usb_ep0_poll();
    assert(g_usb.ctrl.state == IDLE);

    submit_setup(0x80, 0x06, 18);
    assert(g_usb.ctrl.state == STATUS_DONE_OUT);
    usb_ep_regs[0].in.bd[0].csr = USB_BD_STATE_DONE_ERR;
    usb_ep0_poll();
    usb_ep0_poll(); /* Same latched error must be counted only once. */

    /* Diagnostic request captures the state BEFORE it clears BDs. */
    submit_setup(0xc0, USB_EP0_DIAG_REQ, 60);
    assert(word(0) == 0x31445045);
    assert((word(1) & 0xff) == 1);
    assert(((word(1) >> 8) & 0xff) == STATUS_DONE_OUT);
    assert(((word(1) >> 16) & 0xff) == 0x06);
    assert(((word(1) >> 24) & 0xff) == 1);
    assert(word(2) == 3); /* SETUP completions incl. diagnostic */
    assert(word(3) == 1); /* IN ACK */
    assert(word(4) == 1); /* OUT status ACK */
    assert(word(6) == 1); /* One latched IN error */
    assert(word(9) == 1); /* SETUP while STATUS_DONE_OUT */
    assert(word(13) == USB_BD_STATE_DONE_ERR);
    assert(word(14) == (USB_BD_STATE_RDY_DATA | USB_BD_LEN(64)));
    assert(g_usb.ctrl.state == STATUS_DONE_OUT);
    assert(usb_ep_regs[0].in.bd[0].csr ==
           (USB_BD_STATE_RDY_DATA | USB_BD_LEN(60)));

    /* Short diagnostic must retain the original descriptor state, even
     * after the previous (legacy) diagnostic query. */
    submit_setup_with_page(0xc0, USB_EP0_DIAG_SHORT_REQ, 16, 0);
    assert(word(0) == 0x31535045);
    assert(((word(1) >> 8) & 0xff) == STATUS_DONE_OUT);
    assert(((word(1) >> 16) & 0xff) == 0x06);
    assert(word(2) == USB_BD_STATE_DONE_ERR);
    assert(word(3) == (USB_BD_STATE_RDY_DATA | USB_BD_LEN(64)));
    assert(usb_ep_regs[0].in.bd[0].csr ==
           (USB_BD_STATE_RDY_DATA | USB_BD_LEN(16)));

    /* Repeated diagnostic SETUP does not overwrite the latched state. */
    submit_setup_with_page(0xc0, USB_EP0_DIAG_SHORT_REQ, 16, 0);
    assert(((word(1) >> 16) & 0xff) == 0x06);
    assert(word(2) == USB_BD_STATE_DONE_ERR);

    /* Counter pages are independent of the latched snapshot. */
    submit_setup_with_page(0xc0, USB_EP0_DIAG_SHORT_REQ, 16, 2);
    assert(word(0) == 0x31535045);
    assert(word(2) == 1); /* One latched IN BD error */
    submit_setup_with_page(0xc0, USB_EP0_DIAG_SHORT_REQ, 16, 3);
    assert(word(2) >= 1); /* SETUP while busy */

    /* V16f: paged hardware counters are latched once and stable across
     * diagnostic requests; host test uses deterministic fake MMIO values. */
    submit_setup_with_page(0xc0, USB_EP0_DIAG_SHORT_REQ, 16, 5);
    assert(word(0) == 0x31535045);
    assert(word(1) == 0xe017u);
    assert(word(2) == 0xe018u);
    assert(word(3) == 0xe019u);
    submit_setup_with_page(0xc0, USB_EP0_DIAG_SHORT_REQ, 16, 8);
    assert(word(1) == 0xe020u);
    assert(word(2) == 0xe021u);
    assert(word(3) == 0xe022u);

    submit_setup_with_page(0xc0, USB_EP0_DIAG_SHORT_REQ, 16, 10);
    assert(word(1) == 0xe026u); /* EP0 IN DONE_OK writeback */
    assert(word(2) == 0xe027u); /* last_ack_result */
    assert(word(3) == 0xe028u); /* ack_line_changes */

    /* Any non-diagnostic request permits a fresh snapshot. */
    submit_setup(0x80, 0x06, 18);
    submit_setup_with_page(0xc0, USB_EP0_DIAG_SHORT_REQ, 16, 0);
    assert(((word(1) >> 16) & 0xff) == 0x06);
    assert(word(2) == (USB_BD_STATE_RDY_DATA | USB_BD_LEN(18)));

    /* When the host completes STATUS OUT despite an IN ACK missed by the
     * FPGA, EP0 must not retain its old ready-to-transmit IN descriptor.
     * The control request has completed, irrespective of that ACK.
     */
    submit_setup(0x80, 0x06, 16);
    assert(g_usb.ctrl.state == STATUS_DONE_OUT);
    assert(usb_ep_regs[0].in.bd[0].csr ==
           (USB_BD_STATE_RDY_DATA | USB_BD_LEN(16)));
    usb_ep0_poll();
    assert(usb_ep_regs[0].in.bd[0].csr ==
           (USB_BD_STATE_RDY_DATA | USB_BD_LEN(16)));
    usb_ep_regs[0].out.bd[0].csr = USB_BD_STATE_DONE_OK | 2u;
    usb_ep0_poll();
    assert(g_usb.ctrl.state == IDLE);
    assert(usb_ep_regs[0].in.bd[0].csr == USB_BD_STATE_NONE);
    assert(usb_ep_regs[0].out.bd[0].csr == USB_BD_STATE_NONE);
    return 0;
}
'''


def main():
    gcc = shutil.which("gcc")
    if not gcc:
        raise SystemExit("gcc is required for the host-only EP0 diagnostic test")
    with tempfile.TemporaryDirectory(prefix="ulx5m-ep0-") as tmp:
        source = Path(tmp) / "harness.c"
        binary = Path(tmp) / "test"
        source.write_text(HARNESS, encoding="ascii")
        cmd = [gcc, "-std=gnu11", "-DULX5M_SERV_TEST=1", "-DULX5M_EP0_HOST_TEST=1",
               "-ffreestanding",
               "-fno-builtin", "-O0", "-Wall", "-Wextra",
               "-Wno-unused-parameter", "-I", str(FW),
               str(source), str(FW / "usb_ctrl_ep0.c"), "-o", str(binary)]
        subprocess.run(cmd, check=True)
        subprocess.run([str(binary)], check=True)
    print("[PASS] EP0 short pages, preserved pre-SETUP snapshot and counters")


if __name__ == "__main__":
    main()
