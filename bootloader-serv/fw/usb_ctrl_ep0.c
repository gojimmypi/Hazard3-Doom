/*
 * bootloader/fw/usb_ctrl_ep0.c
 *
 * Copyright (C) 2019 Sylvain Munaut
 * All rights reserved.
 *
 * LGPL v3+, see LICENSE.lgpl3
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

#include <stdint.h>
#include <stdbool.h>
#include <string.h>

#include "console.h"
#include "usb_hw.h"
#include "usb_priv.h"
#ifdef ULX5M_SERV_TEST
#include "usb_ep0_diag.h"

/* SERV-only observation counters. No change to endpoint ownership or flow. */
static struct {
	uint32_t setup_ok;
	uint32_t in_ok;
	uint32_t status_out_ok;
	uint32_t setup_err;
	uint32_t in_err;
	uint32_t out_err;
	uint32_t stalls;
	uint32_t setup_busy;
	uint32_t unexpected_in;
	uint32_t unexpected_out;
	uint32_t bad_status_len;
	uint32_t before_in_csr;
	uint32_t before_out_csr;
	uint16_t before_hw[USB_EP0_TRACE_WORDS];
	uint8_t before_state;
	uint8_t before_request;
	uint8_t bus_resets;
	bool in_err_seen;
	bool snapshot_valid;
} ep0_diag;

/* Trace registers are physically at USB_CORE_BASE + (word offset * 4).
 * Only this SERV firmware uses the trace; the host harness has no FPGA MMIO.
 * This is read when the first diagnostic SETUP arrives, before its IN reply.
 */
static void
usb_ep0_diag_latch_hw(void)
{
#ifdef ULX5M_EP0_HOST_TEST
	unsigned i;
	for (i = 0; i < USB_EP0_TRACE_WORDS; i++)
		ep0_diag.before_hw[i] = (uint16_t)(0xe017u + i);
#else
	volatile const uint32_t * const trace =
		(volatile const uint32_t *)(uintptr_t)(USB_CORE_BASE + 0x80u);
	unsigned i;
	for (i = 0; i < USB_EP0_TRACE_WORDS; i++)
		ep0_diag.before_hw[i] = (uint16_t)trace[i];
#endif
}

/* Fixed 60-byte short packet: avoids the exact-64-byte ZLP path. */
void
usb_ep0_diag_snapshot(uint8_t *dst)
{
	const uint32_t words[USB_EP0_DIAG_WORDS] = {
		0x31445045u, /* ASCII EPD1, little-endian */
		1u | ((uint32_t)ep0_diag.before_state << 8) |
			((uint32_t)ep0_diag.before_request << 16) |
			((uint32_t)ep0_diag.bus_resets << 24),
		ep0_diag.setup_ok,
		ep0_diag.in_ok,
		ep0_diag.status_out_ok,
		ep0_diag.setup_err,
		ep0_diag.in_err,
		ep0_diag.out_err,
		ep0_diag.stalls,
		ep0_diag.setup_busy,
		ep0_diag.unexpected_in,
		ep0_diag.unexpected_out,
		ep0_diag.bad_status_len,
		ep0_diag.before_in_csr,
		ep0_diag.before_out_csr,
	};
	unsigned i;
	for (i = 0; i < USB_EP0_DIAG_WORDS; i++) {
		uint32_t v = words[i];
		dst[4*i]   = (uint8_t)v;
		dst[4*i+1] = (uint8_t)(v >> 8);
		dst[4*i+2] = (uint8_t)(v >> 16);
		dst[4*i+3] = (uint8_t)(v >> 24);
	}
}
/* Fixed 16-byte pages. The first response preserves the pre-SETUP
 * state for retries and subsequent diagnostic pages. Never reads flash. */
void
usb_ep0_diag_short_snapshot(uint8_t *dst, unsigned page)
{
    uint32_t words[4] = { 0x31535045u, 0, 0, 0 }; /* EPS1 */
    unsigned i;
    switch (page) {
    case 0:
        words[1] = 1u | ((uint32_t)ep0_diag.before_state << 8) |
            ((uint32_t)ep0_diag.before_request << 16) |
            ((uint32_t)ep0_diag.bus_resets << 24);
        words[2] = ep0_diag.before_in_csr;
        words[3] = ep0_diag.before_out_csr;
        break;
    case 1:
        words[1] = ep0_diag.setup_ok;
        words[2] = ep0_diag.in_ok;
        words[3] = ep0_diag.status_out_ok;
        break;
    case 2:
        words[1] = ep0_diag.setup_err;
        words[2] = ep0_diag.in_err;
        words[3] = ep0_diag.out_err;
        break;
    case 3:
        words[1] = ep0_diag.stalls;
        words[2] = ep0_diag.setup_busy;
        words[3] = ep0_diag.unexpected_in;
        break;
    case 4:
        words[1] = ep0_diag.unexpected_out;
        words[2] = ep0_diag.bad_status_len;
        words[3] = 0;
        break;
    case 5:
    case 6:
    case 7:
    case 8:
    case 9:
    case 10: {
        unsigned base = (page - 5u) * 3u;
        words[1] = base < USB_EP0_TRACE_WORDS ? ep0_diag.before_hw[base] : 0;
        words[2] = base + 1u < USB_EP0_TRACE_WORDS ? ep0_diag.before_hw[base + 1u] : 0;
        words[3] = base + 2u < USB_EP0_TRACE_WORDS ? ep0_diag.before_hw[base + 2u] : 0;
        break;
    }
    default:
        return;
    }
    for (i = 0; i < 4; i++) {
        uint32_t v = words[i];
        dst[4*i]   = (uint8_t)v;
        dst[4*i+1] = (uint8_t)(v >> 8);
        dst[4*i+2] = (uint8_t)(v >> 16);
        dst[4*i+3] = (uint8_t)(v >> 24);
    }
}
#endif

#define EP0_PKT_LEN	64

/* Helpers to manipulate BDs */

	/* IN */
static inline uint32_t
usb_ep0_in_peek(void)
{
	return usb_ep_regs[0].in.bd[0].csr;
}

static inline void
usb_ep0_in_clear(void)
{
	usb_ep_regs[0].in.bd[0].csr = 0;
}

static inline void
usb_ep0_in_queue_data(unsigned int len)
{
	usb_ep_regs[0].in.bd[0].csr = USB_BD_STATE_RDY_DATA | USB_BD_LEN(len);
}

static inline void
usb_ep0_in_queue_stall(void)
{
	usb_ep_regs[0].in.bd[0].csr = USB_BD_STATE_RDY_STALL;
}

	/* OUT */
static inline uint32_t
usb_ep0_out_peek(void)
{
	return usb_ep_regs[0].out.bd[0].csr;
}

static inline void
usb_ep0_out_clear(void)
{
	usb_ep_regs[0].out.bd[0].csr = 0;
}

static inline void
usb_ep0_out_queue_data(void)
{
	usb_ep_regs[0].out.bd[0].csr = USB_BD_STATE_RDY_DATA | USB_BD_LEN(EP0_PKT_LEN);
}

static inline void
usb_ep0_out_queue_stall(void)
{
	usb_ep_regs[0].out.bd[0].csr = USB_BD_STATE_RDY_STALL;
}

	/* SETUP */
static inline uint32_t
usb_ep0_setup_peek(void)
{
	return usb_ep_regs[0].out.bd[1].csr;
}

static inline void
usb_ep0_setup_clear(void)
{
	usb_ep_regs[0].out.bd[1].csr = 0;
}

static inline void
usb_ep0_setup_queue_data(void)
{
	usb_ep_regs[0].out.bd[1].csr = USB_BD_STATE_RDY_DATA | USB_BD_LEN(EP0_PKT_LEN);
}


/* Handle control transfers */

static void
usb_handle_control_data()
{
	/* Handle read requests */
	if (g_usb.ctrl.state == DATA_IN) {
		/* How much left to do ? */
		int xflen = g_usb.ctrl.xfer.len - g_usb.ctrl.xfer.ofs;
		if (xflen > EP0_PKT_LEN)
			xflen = EP0_PKT_LEN;

		/* Setup descriptor for output */
		if (xflen)
			usb_data_write(0, &g_usb.ctrl.xfer.data[g_usb.ctrl.xfer.ofs], xflen);
		usb_ep0_in_queue_data(xflen);

		/* Move on */
		g_usb.ctrl.xfer.ofs += xflen;

		/* If we're done, setup the OUT ack */
		if (xflen < EP0_PKT_LEN) {
			usb_ep0_out_queue_data();
			g_usb.ctrl.state = STATUS_DONE_OUT;
		}
	}

	/* Handle write requests */
	if (g_usb.ctrl.state == DATA_OUT) {
		/* Read off any data we got */
		uint32_t bds_out = usb_ep0_out_peek();

		if ((bds_out & USB_BD_STATE_MSK) == USB_BD_STATE_DONE_OK)
		{
			/* Read data from USB buffer */
			int xflen = (bds_out & USB_BD_LEN_MSK) - 2;
			usb_data_read(&g_usb.ctrl.xfer.data[g_usb.ctrl.xfer.ofs], 0, xflen);

			/* Move on */
			g_usb.ctrl.xfer.ofs += xflen;

			/* Done with that buffer */
			usb_ep0_out_clear();
		}

		/* Next ? */
		if (g_usb.ctrl.xfer.ofs == g_usb.ctrl.xfer.len)
		{
			/* Done, ACK with a ZLP */
			usb_ep0_in_queue_data(0);
			g_usb.ctrl.state = STATUS_DONE_IN;
		}
		else if ((bds_out & USB_BD_STATE_MSK) != USB_BD_STATE_RDY_DATA)
		{
			/* Submit next BD to fill */
			usb_ep0_out_queue_data();
		}
	}
}

static void
usb_handle_control_request(struct usb_ctrl_req *req)
{
	enum usb_fnd_resp rv = USB_FND_CONTINUE;

	/* Defaults */
	g_usb.ctrl.xfer.data = g_usb.ctrl.buf;
	g_usb.ctrl.xfer.len  = sizeof(g_usb.ctrl.buf);
	g_usb.ctrl.xfer.ofs     = 0;
	g_usb.ctrl.xfer.cb_data = NULL;
	g_usb.ctrl.xfer.cb_done = NULL;
	g_usb.ctrl.xfer.cb_ctx  = NULL;

	/* Dipatch to all handlers */
	rv = usb_dispatch_ctrl_req(req, &g_usb.ctrl.xfer);

	/* If the request isn't handled, answer with STALL */
	if (rv != USB_FND_SUCCESS)
		goto error;

	/* Buffer size vs request size checks */
	if (req->wLength > g_usb.ctrl.xfer.len) {
		if (!USB_REQ_IS_READ(req)) {
			/* If this is a OUT treansaction and no suitable buffer was
			 * provided, there isn't much we can do ... */
			USB_LOG_ERR("[!] Control request handler failed to provide enough buffer space");
			goto error;
		}
	} else {
		g_usb.ctrl.xfer.len = req->wLength;
	}

	/* Handle the 'data' stage now */
	g_usb.ctrl.state = USB_REQ_IS_READ(req) ? DATA_IN : DATA_OUT;
	usb_handle_control_data();

	return;

	/* Error path */
error:
#ifdef ULX5M_SERV_TEST
	ep0_diag.stalls++;
#endif
	g_usb.ctrl.state = STALL;
	usb_ep0_in_queue_stall();
	usb_ep0_out_queue_stall();
	return;
}


/* Internally exposed "API" */

void
usb_ep0_reset(void)
{
#ifdef ULX5M_SERV_TEST
	ep0_diag.bus_resets++;
	ep0_diag.snapshot_valid = false;
#endif
	/* Reset internal state */
	g_usb.ctrl.state = IDLE;

	/* Configure EP0 */
	usb_ep_regs[0].out.status = USB_EP_TYPE_CTRL | USB_EP_BD_CTRL; /* Type=Control, control mode buffered */
	usb_ep_regs[0].in.status  = USB_EP_TYPE_CTRL | USB_EP_DT_BIT;  /* Type=Control, single buffered, DT=1 */

	/* Setup the BD pointers */
	usb_ep_regs[0].in.bd[0].ptr  = 0;
	usb_ep_regs[0].out.bd[0].ptr = 0;
	usb_ep_regs[0].out.bd[1].ptr = EP0_PKT_LEN;

	/* Clear BD for IN/OUT */
	usb_ep0_in_clear();
	usb_ep0_out_clear();

	/* Queue one buffer for SETUP */
	usb_ep0_setup_queue_data();
}

void
usb_ep0_poll(void)
{
	uint32_t bds_setup, bds_out, bds_in;
	bool acted;

	do {
		/* Not done anything yet */
		acted = false;

		/* Grab current EP status */
		bds_setup = usb_ep0_setup_peek();
		bds_out   = usb_ep0_out_peek();
		bds_in    = usb_ep0_in_peek();

#ifdef ULX5M_SERV_TEST
		/* Count each latched IN error once; don't rearm the BD here. */
		if ((bds_in & USB_BD_STATE_MSK) == USB_BD_STATE_DONE_ERR) {
			if (!ep0_diag.in_err_seen)
				ep0_diag.in_err++;
			ep0_diag.in_err_seen = true;
		} else if (ep0_diag.in_err_seen) {
			ep0_diag.in_err_seen = false;
		}
#endif

		/* Check for status IN stage finishing */
		if (g_usb.ctrl.state == STATUS_DONE_IN) {
			if ((bds_in & USB_BD_STATE_MSK) == USB_BD_STATE_DONE_OK) {
#ifdef ULX5M_SERV_TEST
				ep0_diag.in_ok++;
#endif
				/* Return to IDLE */
				g_usb.ctrl.state = IDLE;
				usb_ep0_in_clear();

				/* Completion Callback */
				if (g_usb.ctrl.xfer.cb_done)
					g_usb.ctrl.xfer.cb_done(&g_usb.ctrl.xfer);

				/* Next event */
				acted = true;
			}
		}

		/* Check for status OUT stage finishing */
		else if (g_usb.ctrl.state == STATUS_DONE_OUT) {
			if ((bds_in & USB_BD_STATE_MSK) == USB_BD_STATE_DONE_OK) {
#ifdef ULX5M_SERV_TEST
				ep0_diag.in_ok++;
#endif
				/* Done with the last IN BD of this transfer */
				usb_ep0_in_clear();

				/* Next event */
				acted = true;
			}
			if ((bds_out & USB_BD_STATE_MSK) == USB_BD_STATE_DONE_OK) {
#ifdef ULX5M_SERV_TEST
				ep0_diag.status_out_ok++;
				if ((bds_out & USB_BD_LEN_MSK) != 2)
					ep0_diag.bad_status_len++;
#endif
				/* Sanity check */
				if ((bds_out & USB_BD_LEN_MSK) != 2)
					USB_LOG_ERR("[!] Got a non ZLP as a status stage packet ?!?\n");

				/* A successful STATUS OUT completes this control read even
				 * if the device missed the host's ACK of the final IN DATA.
				 * Discard any still-ready IN BD so it cannot be retransmitted
				 * after the host has already finished the transfer.
				 */
#ifdef ULX5M_SERV_TEST
				usb_ep0_in_clear();
#endif
				/* Return to IDLE */
				g_usb.ctrl.state = IDLE;
				usb_ep0_out_clear();

				/* Completion Callback */
				if (g_usb.ctrl.xfer.cb_done)
					g_usb.ctrl.xfer.cb_done(&g_usb.ctrl.xfer);

				/* Next event */
				acted = true;
			}
		}

		/* Check for STALL needing a refresh */
		else if (g_usb.ctrl.state == STALL) {
			if ((bds_in & USB_BD_STATE_MSK) != USB_BD_STATE_RDY_STALL) {
				usb_ep0_in_queue_stall();
				acted = true;
			}
			if ((bds_out & USB_BD_STATE_MSK) != USB_BD_STATE_RDY_STALL) {
				usb_ep0_out_queue_stall();
				acted = true;
			}
		}

		/* If any of the above was acted upon, we need a refresh */
		if (acted)
			continue;

		/* Retry any RX error on both setup and data buffers */
		if ((bds_setup & USB_BD_STATE_MSK) == USB_BD_STATE_DONE_ERR) {
#ifdef ULX5M_SERV_TEST
			ep0_diag.setup_err++;
#endif
			USB_LOG_ERR("[!] Retry SETUP error\n");
			usb_ep0_setup_queue_data();
			acted = true;
			continue;
		}

		if ((bds_out & USB_BD_STATE_MSK) == USB_BD_STATE_DONE_ERR) {
#ifdef ULX5M_SERV_TEST
			ep0_diag.out_err++;
#endif
			USB_LOG_ERR("[!] Retry OUT error\n");
			usb_ep0_out_queue_data();
			acted = true;
			continue;
		}

		/* Check for SETUP */
		if ((bds_setup & USB_BD_STATE_MSK) == USB_BD_STATE_DONE_OK) {
#ifdef ULX5M_SERV_TEST
			uint8_t prior_state = (uint8_t)g_usb.ctrl.state;
			uint8_t prior_request = g_usb.ctrl.req.bRequest;
			ep0_diag.setup_ok++;
			/* Diagnostic requests capture the pre-SETUP state below,
			 * after decoding the new request from endpoint RAM. */
			if (g_usb.ctrl.state != IDLE && g_usb.ctrl.state != STALL)
				ep0_diag.setup_busy++;
#endif
			/* Really setup ? */
			if (!(bds_setup & USB_BD_IS_SETUP)) {
				USB_LOG_ERR("[!] Got non-SETUP in the SETUP BD !?!\n");
			}

			/* Were we waiting for this ? */
			if ((g_usb.ctrl.state != IDLE) && (g_usb.ctrl.state != STALL)) {
				USB_LOG_ERR("[!] Got SETUP while busy !??\n");
			}

			/* Clear descriptors */
			usb_ep0_out_clear();
			usb_ep0_in_clear();

			/* Make sure DT=1 for IN endpoint after a SETUP */
			usb_ep_regs[0].in.status = USB_EP_TYPE_CTRL | USB_EP_DT_BIT;  /* Type=Control, single buffered, DT=1 */

			/* We acked it, need to handle it */
			usb_data_read(&g_usb.ctrl.req, EP0_PKT_LEN, sizeof(struct usb_ctrl_req));
#ifdef ULX5M_SERV_TEST
			if (g_usb.ctrl.req.bmRequestType == 0xc0u &&
			    (g_usb.ctrl.req.bRequest == USB_EP0_DIAG_REQ ||
			     g_usb.ctrl.req.bRequest == USB_EP0_DIAG_SHORT_REQ)) {
				if (!ep0_diag.snapshot_valid) {
					ep0_diag.before_state = (uint8_t)prior_state;
					ep0_diag.before_request = prior_request;
					ep0_diag.before_in_csr = bds_in;
					ep0_diag.before_out_csr = bds_out;
					usb_ep0_diag_latch_hw();
					ep0_diag.snapshot_valid = true;
				}
			} else {
				ep0_diag.snapshot_valid = false;
			}
#endif
			usb_handle_control_request(&g_usb.ctrl.req);

			/* Release the lockout and allow new SETUP */
			usb_regs->ar = USB_AR_CEL_RELEASE;
			usb_ep0_setup_queue_data();

			return;
		}

		/* Process data stage */
		if (((bds_out & USB_BD_STATE_MSK) == USB_BD_STATE_DONE_OK)) {
			/* Sanity check */
			if (g_usb.ctrl.state != DATA_OUT) {
#ifdef ULX5M_SERV_TEST
				ep0_diag.unexpected_out++;
#endif
				USB_LOG_ERR("[!] Got unexpected DATA !?!\n");
				usb_ep0_out_clear();
			} else {
				/* Process data */
				usb_handle_control_data();
			}

			/* Next event */
			acted = true;
			continue;
		}

		if ((bds_in & USB_BD_STATE_MSK) == USB_BD_STATE_DONE_OK) {
			/* Sanity check */
			if (g_usb.ctrl.state != DATA_IN) {
#ifdef ULX5M_SERV_TEST
				ep0_diag.unexpected_in++;
#endif
				USB_LOG_ERR("[!] Got ack for DATA we didn't send !?!\n");
				usb_ep0_in_clear();
			} else {
#ifdef ULX5M_SERV_TEST
				ep0_diag.in_ok++;
#endif
				/* Process data */
				usb_handle_control_data();
			}

			/* Next event */
			acted = true;
			continue;
		}
	} while (acted);
}
