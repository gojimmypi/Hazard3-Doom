/*
 * bootloader/cores/usb/rtl/usb.v
 *
 * vim: ts=4 sw=4
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

`default_nettype none

module usb #(
	parameter         TARGET = "ICE40",
	parameter         MC_INIT_FILE = "usb_trans_mc.hex",
	parameter integer EPDW = 16,
	parameter integer EVT_DEPTH = 0,
	parameter integer EP0_TRACE = 0,
	parameter integer RX_TX_GUARD = 0,
	parameter integer EP0_RAW_FREE_READ = 0,

	/* Auto-set */
	parameter integer EPAW = 11 - $clog2(EPDW / 8)
)(
	// Pads
	inout  wire pad_dp,
	inout  wire pad_dn,
	output reg  pad_pu,

	// EP buffer interface
	input  wire [EPAW-1:0] ep_tx_addr_0,
	input  wire [EPDW-1:0] ep_tx_data_0,
	input  wire ep_tx_we_0,

	input  wire [EPAW-1:0] ep_rx_addr_0,
	output wire [EPDW-1:0] ep_rx_data_1,
	input  wire ep_rx_re_0,

	input  wire ep_clk,

	// Bus interface
	input  wire [11:0] bus_addr,
	input  wire [15:0] bus_din,
	output wire [15:0] bus_dout,
	input  wire bus_cyc,
	input  wire bus_we,
	output wire bus_ack,

	// IRQ
	output wire irq,

	// SOF indication
	output wire sof,

	// Common
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// PHY
	wire phy_rx_dp;
	wire phy_rx_dn;
	wire phy_rx_chg;
	wire [1:0] phy_iddr_dp, phy_iddr_dn;

	wire phy_tx_dp;
	wire phy_tx_dn;
	wire phy_tx_en;
	reg [2:0] tx_en_history;
	// GateMate TX enable is registered again in the IO buffer. The RX
	// decoder must not consume our own DATA/EOP, including PHY latency.
	always @(posedge clk or posedge rst)
		if (rst)
			tx_en_history <= 3'b000;
		else
			tx_en_history <= {tx_en_history[1:0], phy_tx_en};
	wire rx_tx_hold = RX_TX_GUARD && (phy_tx_en || (|tx_en_history));

	// TX Low-Level
	wire txll_start;
	wire txll_bit;
	wire txll_last;
	wire txll_ack;

	// TX Packet
	wire txpkt_start;
	wire txpkt_done;
	wire [3:0] txpkt_pid;
	wire [9:0] txpkt_len;
	wire [7:0] txpkt_data;
	wire txpkt_data_ack;

	// RX Low-Level
	wire [1:0] rxll_sym;
	wire rxll_bit;
	wire rxll_valid;
	wire rxll_eop;
	wire rxll_sync;
	wire rxll_bs_skip;
	wire rxll_bs_err;

	// RX Packet
	wire rxpkt_start;
	wire rxpkt_done_ok;
	wire rxpkt_done_err;

	wire [ 3:0] rxpkt_pid;
	wire rxpkt_is_sof;
	wire rxpkt_is_token;
	wire rxpkt_is_data;
	wire rxpkt_is_handshake;

	wire [10:0] rxpkt_frameno;
	wire [ 6:0] rxpkt_addr;
	wire [ 3:0] rxpkt_endp;

	wire [ 7:0] rxpkt_data;
	wire rxpkt_data_stb;

	// EP Buffers
	wire [10:0] buf_tx_addr_0;
	wire [ 7:0] buf_tx_data_1;
	wire buf_tx_rden_0;

	wire [10:0] buf_rx_addr_0;
	wire [ 7:0] buf_rx_data_0;
	wire buf_rx_wren_0;

	// EP Status
	wire eps_read_0;
	wire eps_zero_0;
	wire eps_write_0;
	wire [ 7:0] eps_addr_0;
	wire [15:0] eps_wrdata_0;
	wire [15:0] eps_rddata_3;

	wire eps_bus_ready;
	reg  eps_bus_read;
	wire eps_bus_zero;
	reg  eps_bus_write;
	wire [15:0] eps_bus_dout;

	// Config / Status registers
	reg  cr_pu_ena;
	reg  cr_cel_ena;
	reg  cr_addr_chk;
	reg  [ 6:0] cr_addr;

	wire cel_state;
	reg  cel_rel;

	// Bus interface
	reg  csr_bus_req;
	wire csr_bus_clear;
	wire csr_bus_ack;
	reg  [15:0] csr_bus_dout;
	wire [15:0] csr_readout;

	reg  cr_bus_we;

	reg  eps_bus_req;
	wire eps_bus_clear;
	reg  eps_bus_ack_wait;
	wire eps_bus_req_ok;
	reg  [2:0] eps_bus_req_ok_dly;

	wire [15:0] evt_rd_data;
	wire evt_rd_rdy;
	reg  evt_rd_ack;

	// Events
	wire [11:0] evt_data;
	wire evt_stb;
	wire dbg_trans_ep0;
	wire dbg_ack_timeout;
	wire [15:0] ep0_trace_rdata;
	wire [15:0] ep0_trace_dout;
	wire csr_trace_ack;
	wire csr_trace_sel = EP0_TRACE && (|bus_addr[7:5]) && !bus_addr[11];

	// Out-of-band conditions
	wire oob_se0;
	wire oob_sof;

	reg  [19:0] timeout_suspend;	//  3 ms with no activity
	reg  [19:0] timeout_reset;		// 10 ms SE0

	wire usb_suspend;
	wire usb_reset;
	reg  rst_pending;
	reg  rst_clear;

	// Start-Of-Frame indication
	reg  sof_ind;
	reg  sof_pending;
	reg  sof_clear;


	// PHY
	// ---

	usb_phy #(
		.TARGET(TARGET)
	) phy_I (
		.pad_dp(pad_dp),
		.pad_dn(pad_dn),
		.rx_dp(phy_rx_dp),
		.rx_dn(phy_rx_dn),
		.rx_chg(phy_rx_chg),
		.dbg_iddr_dp(phy_iddr_dp),
		.dbg_iddr_dn(phy_iddr_dn),
		.tx_dp(phy_tx_dp),
		.tx_dn(phy_tx_dn),
`ifdef SIM
		.tx_en(1'b0),
`else
		.tx_en(phy_tx_en),
`endif
		.clk(clk),
		.rst(rst)
	);


	// TX
	// --

	usb_tx_ll tx_ll_I (
		.phy_tx_dp(phy_tx_dp),
		.phy_tx_dn(phy_tx_dn),
		.phy_tx_en(phy_tx_en),
		.ll_start(txll_start),
		.ll_bit(txll_bit),
		.ll_last(txll_last),
		.ll_ack(txll_ack),
		.clk(clk),
		.rst(rst)
	);

	usb_tx_pkt tx_pkt_I (
		.ll_start(txll_start),
		.ll_bit(txll_bit),
		.ll_last(txll_last),
		.ll_ack(txll_ack),
		.pkt_start(txpkt_start),
		.pkt_done(txpkt_done),
		.pkt_pid(txpkt_pid),
		.pkt_len(txpkt_len),
		.pkt_data(txpkt_data),
		.pkt_data_ack(txpkt_data_ack),
		.clk(clk),
		.rst(rst)
	);


	// RX
	// --

	usb_rx_ll rx_ll_I (
		.phy_rx_dp(phy_rx_dp),
		.phy_rx_dn(phy_rx_dn),
		.phy_rx_chg(phy_rx_chg),
		.rx_inhibit(rx_tx_hold),
		.ll_sym(rxll_sym),
		.ll_bit(rxll_bit),
		.ll_valid(rxll_valid),
		.ll_eop(rxll_eop),
		.ll_sync(rxll_sync),
		.ll_bs_skip(rxll_bs_skip),
		.ll_bs_err(rxll_bs_err),
		.clk(clk),
		.rst(rst)
	);

	usb_rx_pkt rx_pkt_I (
		.ll_sym(rxll_sym),
		.ll_bit(rxll_bit),
		.ll_valid(rxll_valid),
		.ll_eop(rxll_eop),
		.ll_sync(rxll_sync),
		.ll_bs_skip(rxll_bs_skip),
		.ll_bs_err(rxll_bs_err),
		.pkt_start(rxpkt_start),
		.pkt_done_ok(rxpkt_done_ok),
		.pkt_done_err(rxpkt_done_err),
		.pkt_pid(rxpkt_pid),
		.pkt_is_sof(rxpkt_is_sof),
		.pkt_is_token(rxpkt_is_token),
		.pkt_is_data(rxpkt_is_data),
		.pkt_is_handshake(rxpkt_is_handshake),
		.pkt_frameno(rxpkt_frameno),
		.pkt_addr(rxpkt_addr),
		.pkt_endp(rxpkt_endp),
		.pkt_data(rxpkt_data),
		.pkt_data_stb(rxpkt_data_stb),
		.inhibit(phy_tx_en),
		.clk(clk),
		.rst(rst)
	);


	// Transaction control
	// -------------------

	usb_trans #(.MC_INIT_FILE(MC_INIT_FILE)) trans_I (
		.txpkt_start(txpkt_start),
		.txpkt_done(txpkt_done),
		.txpkt_pid(txpkt_pid),
		.txpkt_len(txpkt_len),
		.txpkt_data(txpkt_data),
		.txpkt_data_ack(txpkt_data_ack),
		.rxpkt_start(rxpkt_start),
		.rxpkt_done_ok(rxpkt_done_ok),
		.rxpkt_done_err(rxpkt_done_err),
		.rxpkt_pid(rxpkt_pid),
		.rxpkt_is_sof(rxpkt_is_sof),
		.rxpkt_is_token(rxpkt_is_token),
		.rxpkt_is_data(rxpkt_is_data),
		.rxpkt_is_handshake(rxpkt_is_handshake),
		.rxpkt_frameno(rxpkt_frameno),
		.rxpkt_addr(rxpkt_addr),
		.rxpkt_endp(rxpkt_endp),
		.rxpkt_data(rxpkt_data),
		.rxpkt_data_stb(rxpkt_data_stb),
		.buf_tx_addr_0(buf_tx_addr_0),
		.buf_tx_data_1(buf_tx_data_1),
		.buf_tx_rden_0(buf_tx_rden_0),
		.buf_rx_addr_0(buf_rx_addr_0),
		.buf_rx_data_0(buf_rx_data_0),
		.buf_rx_wren_0(buf_rx_wren_0),
		.eps_read_0(eps_read_0),
		.eps_zero_0(eps_zero_0),
		.eps_write_0(eps_write_0),
		.eps_addr_0(eps_addr_0),
		.eps_wrdata_0(eps_wrdata_0),
		.eps_rddata_3(eps_rddata_3),
		.cr_addr_chk(cr_addr_chk),
		.cr_addr(cr_addr),
		.evt_data(evt_data),
		.evt_stb(evt_stb),
		.dbg_trans_ep0(dbg_trans_ep0),
		.dbg_ack_timeout(dbg_ack_timeout),
		.cel_state(cel_state),
		.cel_rel(cel_rel),
		.cel_ena(cr_cel_ena),
		.clk(clk),
		.rst(rst)
	);


	// EP buffers
	// ----------

	usb_ep_buf #(
		.TARGET(TARGET),
		.RWIDTH(8),
		.WWIDTH(EPDW)
	) tx_buf_I (
		.rd_addr_0(buf_tx_addr_0),
		.rd_data_1(buf_tx_data_1),
		.rd_en_0(buf_tx_rden_0),
		.rd_clk(clk),
		.wr_addr_0(ep_tx_addr_0),
		.wr_data_0(ep_tx_data_0),
		.wr_en_0(ep_tx_we_0),
		.wr_clk(ep_clk)
	);

	usb_ep_buf #(
		.TARGET(TARGET),
		.RWIDTH(EPDW),
		.WWIDTH(8)
	) rx_buf_I (
		.rd_addr_0(ep_rx_addr_0),
		.rd_data_1(ep_rx_data_1),
		.rd_en_0(ep_rx_re_0),
		.rd_clk(ep_clk),
		.wr_addr_0(buf_rx_addr_0),
		.wr_data_0(buf_rx_data_0),
		.wr_en_0(buf_rx_wren_0),
		.wr_clk(clk)
	);


	// EP Status / Buffer Descriptors
	// ------------------------------

	usb_ep_status ep_status_I (
		.p_addr_0(eps_addr_0),
		.p_read_0(eps_read_0),
		.p_zero_0(eps_zero_0),
		.p_write_0(eps_write_0),
		.p_din_0(eps_wrdata_0),
		.p_dout_3(eps_rddata_3),
		.s_addr_0(bus_addr[7:0]),
		.s_read_0(eps_bus_read),
		.s_zero_0(eps_bus_zero),
		.s_write_0(eps_bus_write),
		.s_din_0(bus_din),
		.s_dout_3(eps_bus_dout),
		.s_ready_0(eps_bus_ready),
		.clk(clk),
		.rst(rst)
	);


	// SERV EP0 hardware trace (optional; reads only, no control feedback)
	// ---------------------------------------------------------------
	// CSR word offsets 0x20..0x30, physical bytes USB_CORE_BASE+0x80..0xC0.
	// Counters are 16-bit modulo; snapshots must be compared over short runs.
	// Packet counters classify the currently selected endpoint as EP0.
	// The trace CSR read is pipelined: address -> bank mux -> output mux -> ACK.
	// This keeps the new counter mux off the SERV -> Wishbone response path.
	generate if (EP0_TRACE) begin : g_ep0_trace
		reg [7:0] trace_addr_q;
		reg trace_pending_q;
		reg trace_bank_valid_q;
		reg trace_ack_q;
		reg [15:0] trace_dout_q;
		assign csr_trace_ack = trace_ack_q && bus_cyc && csr_trace_sel;
		assign ep0_trace_dout = trace_dout_q;

		// Split trace readback into two registered mux stages. The first
		// stage selects one of four counters per bank; the second selects
		// the bank or the synchronous capture RAM output. The normal CSR
		// bus and USB transaction engine are unaffected.
		always @(posedge clk or posedge rst) begin
			if (rst) begin
				trace_addr_q <= 0;
				trace_pending_q <= 1'b0;
				trace_bank_valid_q <= 1'b0;
				trace_ack_q <= 1'b0;
				trace_dout_q <= 0;
			end else if (!bus_cyc || !csr_trace_sel || trace_ack_q) begin
				trace_pending_q <= 1'b0;
				trace_bank_valid_q <= 1'b0;
				trace_ack_q <= 1'b0;
			end else if (!trace_pending_q) begin
				trace_addr_q <= bus_addr[7:0];
				trace_pending_q <= 1'b1;
			end else if (!trace_bank_valid_q) begin
				trace_bank_valid_q <= 1'b1;
			end else begin
				trace_dout_q <= ep0_trace_rdata;
				trace_ack_q <= 1'b1;
			end
		end
		reg [15:0] cnt_in_token;
		reg [15:0] cnt_data_start;
		reg [15:0] cnt_data_done;
		reg [15:0] cnt_ack;
		reg [15:0] cnt_nak;
		reg [15:0] cnt_stall;
		reg [15:0] cnt_rx_err;
		reg [15:0] last_data_len;
		reg [15:0] last_tx_pid;
		reg [15:0] cnt_ack_sync;
		reg [15:0] cnt_ack_pid;
		reg [15:0] cnt_ack_eop;
		reg [15:0] cnt_ack_rx_err;
		reg [15:0] cnt_ack_timeout;
		reg [15:0] cnt_ack_bd_done;
		reg [15:0] last_ack_result;
		reg ack_window;
		reg ack_tx_pending;
		reg saw_line_chg;
		reg [15:0] cnt_ack_line_chg;
		reg saw_sync;
		reg saw_pid;
		reg saw_eop;
		// Record EP0 DATA completion, but arm the receive window only after
		// the GateMate IO buffer has actually released D+/D-. It ends on an
		// RX result, receive timeout or subsequent traffic.
		wire ep0_in_token = rxpkt_done_ok && rxpkt_is_token &&
			(rxpkt_pid == 4'h9) && (rxpkt_endp == 4'h0) &&
			(!cr_addr_chk || (rxpkt_addr == cr_addr));
		wire ack_line_chg = ack_window && !rx_tx_hold && phy_rx_chg;
		wire ack_sync = ack_window && rxll_valid && rxll_sync;
		wire ack_pid = ack_window && rxpkt_start &&
			rxpkt_is_handshake && (rxpkt_pid == 4'h2);
		wire ack_eop = ack_window && rxll_valid && rxll_eop;
		wire ack_valid = ack_window && rxpkt_done_ok &&
			rxpkt_is_handshake && (rxpkt_pid == 4'h2);
		wire ack_timeout = ack_window && dbg_ack_timeout;
		wire ack_close = rxpkt_done_ok || rxpkt_done_err ||
			ack_timeout || txpkt_start || ep0_in_token;
		// IN BD word 0 (DONE_OK), not merely a decoded USB ACK.
		wire ack_bd_done = eps_write_0 && (eps_addr_0[7:4] == 0) &&
			(eps_addr_0[3:2] == 2'b11) &&
			(eps_wrdata_0[15:13] == 3'b100);

		// The raw IDDR trace is passive: no feedback to USB control.
		wire raw_arm = bus_cyc && bus_we && !trace_pending_q &&
			(bus_addr[7:0] == 8'h3f);
		wire raw_read = bus_cyc && !bus_we &&
			(bus_addr[7:6] == 2'b01 || bus_addr[7:6] == 2'b10);
		wire [15:0] raw_rdata;
		wire [15:0] raw_status;
		wire [15:0] raw_count;
		usb_ep0_raw_capture #(.FREE_RUNNING_READ(EP0_RAW_FREE_READ)) raw_capture_I (
			.clk(clk), .rst(rst), .arm(raw_arm),
			.tx_data_pending(ack_tx_pending),
			.tx_en(phy_tx_en), .tx_en_pad_d(tx_en_history[0]),
			.rx_hold(rx_tx_hold),
			.raw_dp(phy_iddr_dp), .raw_dn(phy_iddr_dn),
			.rx_change(phy_rx_chg), .rx_sync(rxll_valid && rxll_sync),
			.ack_valid(ack_valid), .ack_timeout(ack_timeout),
			.rd_en(raw_read),
			.rd_addr({bus_addr[7], bus_addr[5:0]}),
			.rd_data(raw_rdata), .status(raw_status),
			.sample_count(raw_count)
		);

		wire data_pid = (txpkt_pid == 4'h3) || (txpkt_pid == 4'hb);
		always @(posedge clk or posedge rst) begin
			if (rst) begin
				cnt_in_token <= 0;
				cnt_data_start <= 0;
				cnt_data_done <= 0;
				cnt_ack <= 0;
				cnt_nak <= 0;
				cnt_stall <= 0;
				cnt_rx_err <= 0;
				last_data_len <= 0;
				last_tx_pid <= 0;
				cnt_ack_sync <= 0;
				cnt_ack_pid <= 0;
				cnt_ack_eop <= 0;
				cnt_ack_rx_err <= 0;
				cnt_ack_timeout <= 0;
				cnt_ack_bd_done <= 0;
				last_ack_result <= 0;
				ack_window <= 1'b0;
				ack_tx_pending <= 1'b0;
				saw_line_chg <= 1'b0;
				cnt_ack_line_chg <= 0;
				saw_sync <= 1'b0;
				saw_pid <= 1'b0;
				saw_eop <= 1'b0;
			end else begin
				if (ep0_in_token)
					cnt_in_token <= cnt_in_token + 1'b1;
				if (dbg_trans_ep0 && txpkt_start && data_pid) begin
					cnt_data_start <= cnt_data_start + 1'b1;
					last_data_len <= {6'b0, txpkt_len};
				end
				if (dbg_trans_ep0 && txpkt_done && data_pid)
					cnt_data_done <= cnt_data_done + 1'b1;
				if (ack_valid)
					cnt_ack <= cnt_ack + 1'b1;
				if (dbg_trans_ep0 && txpkt_start && txpkt_pid == 4'ha)
					cnt_nak <= cnt_nak + 1'b1;
				if (dbg_trans_ep0 && txpkt_start && txpkt_pid == 4'he)
					cnt_stall <= cnt_stall + 1'b1;
				if (dbg_trans_ep0 && rxpkt_done_err)
					cnt_rx_err <= cnt_rx_err + 1'b1;
				if (dbg_trans_ep0 && txpkt_start)
					last_tx_pid <= {12'b0, txpkt_pid};
				if (ack_bd_done)
					cnt_ack_bd_done <= cnt_ack_bd_done + 1'b1;
				if (ack_line_chg) begin
					cnt_ack_line_chg <= cnt_ack_line_chg + 1'b1;
					saw_line_chg <= 1'b1;
				end
				if (ack_sync) begin
					cnt_ack_sync <= cnt_ack_sync + 1'b1;
					saw_sync <= 1'b1;
				end
				if (ack_pid) begin
					cnt_ack_pid <= cnt_ack_pid + 1'b1;
					saw_pid <= 1'b1;
				end
				if (ack_eop) begin
					cnt_ack_eop <= cnt_ack_eop + 1'b1;
					saw_eop <= 1'b1;
				end
				if (ack_window && rxpkt_done_err)
					cnt_ack_rx_err <= cnt_ack_rx_err + 1'b1;
				if (ack_timeout)
					cnt_ack_timeout <= cnt_ack_timeout + 1'b1;
				if (txpkt_done && dbg_trans_ep0 && data_pid) begin
					ack_tx_pending <= 1'b1;
				end else if (ack_tx_pending && !rx_tx_hold) begin
					ack_tx_pending <= 1'b0;
					ack_window <= 1'b1;
					saw_line_chg <= 1'b0;
					saw_sync <= 1'b0;
					saw_pid <= 1'b0;
					saw_eop <= 1'b0;
				end else if (ack_window && ack_close) begin
					ack_window <= 1'b0;
					// Bits: 0 SYNC, 1 ACK PID, 2 EOP, 3 RX error,
					// 4 valid ACK, 5 timeout, 6 superseded,
					// 7 complete non-ACK packet, 8 bus transition.
					last_ack_result <= {7'b0, (saw_line_chg || ack_line_chg),
						(rxpkt_done_ok && !ack_valid),
						(txpkt_start || ep0_in_token), ack_timeout,
						ack_valid, rxpkt_done_err,
						(saw_eop || ack_eop),
						(saw_pid || ack_pid),
						(saw_sync || ack_sync)};
				end
			end
		end
		// Stage 1: six small 4-to-1 muxes, registered independently.
		// These are updated on every clock; trace_bank_valid_q ensures
		// they are not consumed until trace_addr_q has been sampled.
		reg [15:0] trace_bank_20_q;
		reg [15:0] trace_bank_24_q;
		reg [15:0] trace_bank_28_q;
		reg [15:0] trace_bank_2c_q;
		reg [15:0] trace_bank_30_q;
		reg [15:0] trace_bank_34_q;
		always @(posedge clk) begin
			case (trace_addr_q[1:0])
				2'd0: begin
					trace_bank_20_q <= 16'he017;
					trace_bank_24_q <= cnt_ack;
					trace_bank_28_q <= last_data_len;
					trace_bank_2c_q <= cnt_ack_eop;
					trace_bank_30_q <= last_ack_result;
					trace_bank_34_q <= raw_count;
				end
				2'd1: begin
					trace_bank_20_q <= cnt_in_token;
					trace_bank_24_q <= cnt_nak;
					trace_bank_28_q <= last_tx_pid;
					trace_bank_2c_q <= cnt_ack_rx_err;
					trace_bank_30_q <= cnt_ack_line_chg;
					trace_bank_34_q <= 16'h0000;
				end
				2'd2: begin
					trace_bank_20_q <= cnt_data_start;
					trace_bank_24_q <= cnt_stall;
					trace_bank_28_q <= cnt_ack_sync;
					trace_bank_2c_q <= cnt_ack_timeout;
					trace_bank_30_q <= 16'h5257; // 'WR' raw waveform marker
					trace_bank_34_q <= 16'h0000;
				end
				default: begin
					trace_bank_20_q <= cnt_data_done;
					trace_bank_24_q <= cnt_rx_err;
					trace_bank_28_q <= cnt_ack_pid;
					trace_bank_2c_q <= cnt_ack_bd_done;
					trace_bank_30_q <= raw_status;
					trace_bank_34_q <= 16'h0000;
				end
			endcase
		end

		// Stage 2: select between already registered 4-word banks or
		// the independently clocked raw-capture BRAM read result.
		reg [15:0] rdata;
		always @(*) begin
			if (trace_addr_q[7:6] == 2'b01 || trace_addr_q[7:6] == 2'b10)
				rdata = raw_rdata;
			else case (trace_addr_q[7:2])
				6'h08: rdata = trace_bank_20_q;
				6'h09: rdata = trace_bank_24_q;
				6'h0a: rdata = trace_bank_28_q;
				6'h0b: rdata = trace_bank_2c_q;
				6'h0c: rdata = trace_bank_30_q;
				6'h0d: rdata = trace_bank_34_q;
				default: rdata = 16'h0000;
			endcase
		end
		assign ep0_trace_rdata = rdata;
	end else begin : g_no_ep0_trace
		assign ep0_trace_rdata = 16'h0000;
		assign ep0_trace_dout = 16'h0000;
		assign csr_trace_ack = 1'b0;
	end endgenerate

	// CSR & Bus Interface
	// -------------------

	// Request lines for registers and strobes for actions
	always @(posedge clk)
		if (csr_bus_clear) begin
			csr_bus_req <= 1'b0;
			cr_bus_we   <= 1'b0;
			cel_rel     <= 1'b0;
			rst_clear   <= 1'b0;
			sof_clear   <= 1'b0;
			evt_rd_ack  <= 1'b0;
		end else begin
			csr_bus_req <= 1'b1;
			cr_bus_we   <= (!csr_trace_sel) & (bus_addr[1:0] == 2'b00) &  bus_we;
			cel_rel     <= (!csr_trace_sel) & (bus_addr[1:0] == 2'b01) &  bus_we & bus_din[13];
			rst_clear   <= (!csr_trace_sel) & (bus_addr[1:0] == 2'b01) &  bus_we & bus_din[ 9];
			sof_clear   <= (!csr_trace_sel) & (bus_addr[1:0] == 2'b01) &  bus_we & bus_din[ 8];
			evt_rd_ack  <= (!csr_trace_sel) & (bus_addr[1:0] == 2'b10) & ~bus_we & evt_rd_rdy;
		end

	// Read mux for CSR
	assign csr_readout = {
		cr_pu_ena,
		irq,
		cel_state,
		cr_cel_ena,
		usb_suspend,
		usb_reset,
		rst_pending,
		sof_pending,
		cr_addr_chk,
		cr_addr
	};

	always @(*)
		if (csr_trace_ack)
			csr_bus_dout = ep0_trace_dout;
		else if (csr_bus_ack)
			case (bus_addr[1:0])
				2'b00:   csr_bus_dout = csr_readout;
				2'b10:   csr_bus_dout = evt_rd_data;
				default: csr_bus_dout = 16'h0000;
			endcase
		else
			csr_bus_dout = 16'h0000;

	// CSR Clear/Ack
	assign csr_bus_ack   = csr_bus_req & ~csr_trace_sel;
	assign csr_bus_clear = ~bus_cyc | csr_bus_ack | csr_trace_ack | bus_addr[11];

	// Write regs
	always @(posedge clk)
		if (rst) begin
			cr_pu_ena  <= 1'b0;
			cr_cel_ena <= 1'b0;
			cr_addr_chk<= 1'b0;
			cr_addr    <= 7'd0;
		end else if (cr_bus_we) begin
			cr_pu_ena  <= bus_din[15];
			cr_cel_ena <= bus_din[12];
			cr_addr_chk<= bus_din[7];
			cr_addr    <= bus_din[6:0];
		end

	// Request lines for EP Status access
	always @(posedge clk)
		if (eps_bus_clear) begin
			eps_bus_read  <= 1'b0;
			eps_bus_write <= 1'b0;
			eps_bus_req   <= 1'b0;
		end else begin
			eps_bus_read  <=  bus_addr[11] & ~bus_we;
			eps_bus_write <=  bus_addr[11] &  bus_we;
			eps_bus_req   <=  bus_addr[11];
		end

	assign eps_bus_zero = ~eps_bus_read;

	// EPS Clear
	assign eps_bus_clear = ~bus_cyc | eps_bus_ack_wait | (eps_bus_req & eps_bus_ready);

	// Track when request are accepted by the RAM
	assign eps_bus_req_ok = (eps_bus_req & eps_bus_ready);

	always @(posedge clk)
		eps_bus_req_ok_dly <= { eps_bus_req_ok_dly[1:0], eps_bus_req_ok & ~bus_we };

	// ACK wait state tracking
	always @(posedge clk or posedge rst)
		if (rst)
			eps_bus_ack_wait <= 1'b0;
		else
			eps_bus_ack_wait <= ((eps_bus_ack_wait & ~bus_we) | eps_bus_req_ok) & ~eps_bus_req_ok_dly[2];

	// Bus Ack
	assign bus_ack = csr_bus_ack | csr_trace_ack |
		(eps_bus_ack_wait & (bus_we | eps_bus_req_ok_dly[2]));

	// Output is simply the OR of all local units since we force them to zero if
	// they're not accessed
	assign bus_dout = csr_bus_dout | eps_bus_dout;


	// Event handling
	// --------------

	generate
		if (EVT_DEPTH == 0) begin
			// We just save the # of notify since last read
			reg [3:0] evt_cnt;

			always @(posedge clk or posedge rst)
				if (rst)
					evt_cnt <= 4'h0;
				else
					evt_cnt <= evt_rd_ack ? { 3'b000, evt_stb } : (evt_cnt + evt_stb);

			assign evt_rd_rdy = 1'b1;
			assign evt_rd_data = { evt_cnt, 12'h000 };

			assign irq = (evt_cnt != 4'h0);

		end else if (EVT_DEPTH == 1) begin
			// Save the latest value and # of notify since last read
			reg [11:0] evt_last;
			reg [ 3:0] evt_cnt;

			always @(posedge clk or posedge rst)
				if (rst)
					evt_cnt <= 4'h0;
				else
					evt_cnt <= evt_rd_ack ? { 3'b000, evt_stb } : (evt_cnt + evt_stb);

			always @(posedge clk)
				if (evt_stb)
					evt_last <= evt_data;

			assign evt_rd_rdy = 1'b1;
			assign evt_rd_data = { evt_cnt, evt_last };

			assign irq = (evt_cnt != 4'h0);

		end else if (EVT_DEPTH > 1) begin
			// Small shift-reg FIFO
			wire [11:0] ef_wdata;
			wire [11:0] ef_rdata;
			wire ef_wren;
			wire ef_full;
			wire ef_rden;
			wire ef_empty;

			reg  ef_overflow;

			assign ef_wdata = evt_data;
			assign ef_wren  = evt_stb & ~ef_full;

			always @(posedge clk or posedge rst)
				if (rst)
					ef_overflow <= 1'b0;
				else
					ef_overflow <= (ef_overflow & ~evt_rd_ack) | (evt_stb & ef_full);

			assign evt_rd_rdy = ~ef_empty;
			assign evt_rd_data = { ~ef_empty, ef_overflow, 2'b00, ef_rdata };
			assign ef_rden = evt_rd_ack;

			assign irq = ~ef_rden;

			fifo_sync_shift #(
				.DEPTH(EVT_DEPTH),
				.WIDTH(12)
			) evt_fifo_I (
				.wr_data(ef_wdata),
				.wr_ena(ef_wren),
				.wr_full(ef_full),
				.rd_data(ef_rdata),
				.rd_ena(ef_rden),
				.rd_empty(ef_empty),
				.clk(clk),
				.rst(rst)
			);

		end
	endgenerate


	// USB reset/suspend
	// -----------------

	// Detect some conditions for triggers
	assign oob_se0 = ~phy_rx_dp & ~phy_rx_dn;
	assign oob_sof = rxpkt_start & rxpkt_is_sof;

	// Suspend timeout counter
	always @(posedge clk)
		if (oob_sof | usb_reset)
			timeout_suspend <= 20'hdcd80;	// 3 ms
		else if (TARGET == "GATEMATE") begin
			// Shorter 48 MHz carry path; other targets retain their original logic.
			timeout_suspend[9:0] <= timeout_suspend[9:0] + timeout_suspend[19];
			timeout_suspend[19:10] <= timeout_suspend[19:10] + (timeout_suspend[19] & (&timeout_suspend[9:0]));
		end else
			timeout_suspend <= timeout_suspend + timeout_suspend[19];

	assign usb_suspend = ~timeout_suspend[19];

	// Reset timeout counter
	always @(posedge clk)
		if (~oob_se0)
			timeout_reset <= 20'hf4480;	// 1 ms SE0; host reset may last only 10 ms
		else if (TARGET == "GATEMATE") begin
			// Shorter 48 MHz carry path; other targets retain their original logic.
			timeout_reset[9:0] <= timeout_reset[9:0] + timeout_reset[19];
			timeout_reset[19:10] <= timeout_reset[19:10] + (timeout_reset[19] & (&timeout_reset[9:0]));
		end else
			timeout_reset <= timeout_reset + timeout_reset[19];

	assign usb_reset = ~timeout_reset[19];

	always @(posedge clk or posedge rst)
		if (rst)
			rst_pending <= 1'b1;
		else
			rst_pending <= (rst_pending & ~rst_clear) | usb_reset;

	// Detection pin
	always @(posedge clk)
		if (rst)
			pad_pu <= 1'b0;
		else
			pad_pu <= cr_pu_ena;


	// Misc
	// ----

	always @(posedge clk)
		sof_ind <= rxpkt_start & rxpkt_is_sof;

	always @(posedge clk)
		sof_pending <= (sof_pending & ~sof_clear) | (rxpkt_start & rxpkt_is_sof);

	assign sof = sof_ind;

endmodule // usb

`default_nettype wire
