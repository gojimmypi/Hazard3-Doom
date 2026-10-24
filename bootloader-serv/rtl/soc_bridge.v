/*
 * bootloader/rtl/soc_bridge.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019  Sylvain Munaut <tnt@246tNt.com>
 * All rights reserved.
 *
 * BSD 3-clause, see LICENSE.bsd
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the <organization> nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

`default_nettype none

module soc_bridge #(
	parameter integer RAM_AW = 12,
	parameter integer WB_N   =  8,
	parameter integer WB_DW  = 32,
	parameter integer WB_AW  = 16,
	parameter integer WB_AI  =  2,
	parameter integer WB_REG = 0,	// [0] = cyc / [1] = addr/wdata/wstrb / [2] = ack/rdata
	parameter integer BRAM_REG = 0,	// Register BRAM request and delay ACK (GateMate timing)
	parameter integer WB_DECODE_RDATA = 0 // Mask inactive read-data responders
)(
	/* PicoRV32 bus */
	input  wire [31:0] pb_addr,
	output wire [31:0] pb_rdata,
	input  wire [31:0] pb_wdata,
	input  wire [ 3:0] pb_wstrb,
	input  wire pb_valid,
	output wire pb_ready,

	/* BRAM */
	output wire [RAM_AW-1:0] bram_addr,
	input  wire [31:0] bram_rdata,
	output wire [31:0] bram_wdata,
	output wire [ 3:0] bram_wmsk,
	output wire        bram_we,

	/* Wishbone buses */
	output wire [WB_AW-1:0] wb_addr,
	output wire [WB_DW-1:0] wb_wdata,
	output wire [(WB_DW/8)-1:0] wb_wmsk,
	input  wire [(WB_DW*WB_N)-1:0] wb_rdata,
	output wire [WB_N-1:0] wb_cyc,
	output wire wb_we,
	input  wire [WB_N-1:0] wb_ack,

	/* Clock / Reset */
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	wire ram_sel;
	reg  ram_rdy;
	wire [31:0] ram_rdata;

	(* keep="true" *) wire [WB_N-1:0] wb_match;
	(* keep="true" *) wire wb_cyc_rst;

	reg  [31:0] wb_rdata_or;
	wire [31:0] wb_rdata_out;
	wire wb_rdy;


	// RAM access
	// ----------

	assign ram_rdata = ~pb_addr[31] ? bram_rdata : 32'h00000000;

	assign ram_sel = pb_valid & ~pb_addr[31];

	generate if (BRAM_REG) begin : g_bram_reg
		// Register the request before the BRAM port. With synchronous BRAM
		// reads, the read data becomes valid on the following clock edge;
		// issue the ACK only after that edge. This removes the direct
		// PicoRV32 address/write-mask -> BRAM write-enable timing path.
		reg [RAM_AW-1:0] addr_q;
		reg [31:0] wdata_q;
		reg [3:0] wmsk_q;
		reg we_q;
		reg pending_q;
		wire issue = ram_sel & ~pending_q & ~ram_rdy;

		assign bram_addr = addr_q;
		assign bram_wdata = wdata_q;
		assign bram_wmsk = wmsk_q;
		assign bram_we = we_q;

		always @(posedge clk) begin
			if (rst) begin
				pending_q <= 1'b0;
				ram_rdy <= 1'b0;
				we_q <= 1'b0;
			end else begin
				pending_q <= issue;
				ram_rdy <= pending_q;
				we_q <= 1'b0;
				if (issue) begin
					addr_q <= pb_addr[RAM_AW+1:2];
					wdata_q <= pb_wdata;
					wmsk_q <= pb_wstrb;
					we_q <= (|pb_wstrb) & ~pb_addr[17];
				end
			end
		end
	end else begin : g_bram_direct
		// Preserve the existing ULX3S/ULX4M and USB-probe handshake.
		assign bram_addr = pb_addr[RAM_AW+1:2];
		assign bram_wdata = pb_wdata;
		assign bram_wmsk = pb_wstrb;
		assign bram_we = pb_valid & ~pb_addr[31] & |pb_wstrb & ~pb_addr[17];

		always @(posedge clk)
			ram_rdy <= ram_sel && ~ram_rdy;
	end endgenerate


	// Wishbone
	// --------
	// wb[x] = 0x8x000000 - 0x8xffffff

	// Access Cycle
	genvar i;
	for (i=0; i<WB_N; i=i+1)
		assign wb_match[i] = (pb_addr[27:24] == i);

	if (WB_REG & 1) begin
		// Register
		reg [WB_N-1:0] wb_cyc_reg;
		always @(posedge clk)
			if (wb_cyc_rst)
				wb_cyc_reg <= 0;
			else
				wb_cyc_reg <= wb_match & ~wb_ack;
		assign wb_cyc = wb_cyc_reg;
	end else begin
		// Direct connection
		assign wb_cyc = wb_cyc_rst ? { WB_N{1'b0} } : wb_match;
	end

	// Addr / Write-Data / Write-Mask / Write-Enable
	if (WB_REG & 2) begin
		// Register
		reg [WB_AW-1:0] wb_addr_reg;
		reg [WB_DW-1:0] wb_wdata_reg;
		reg [(WB_DW/8)-1:0] wb_wmsk_reg;
		reg wb_we_reg;

		always @(posedge clk)
		begin
			wb_addr_reg  <= pb_addr[WB_AW+WB_AI-1:WB_AI];
			wb_wdata_reg <= pb_wdata[WB_DW-1:0];
			wb_wmsk_reg  <= pb_wstrb[(WB_DW/8)-1:0];
			wb_we_reg    <= |pb_wstrb;
		end

		assign wb_addr  = wb_addr_reg;
		assign wb_wdata = wb_wdata_reg;
		assign wb_wmsk  = wb_wmsk_reg;
		assign wb_we    = wb_we_reg;
	end else begin
		// Direct connection
		assign wb_addr  = pb_addr[WB_AW+WB_AI-1:WB_AI];
		assign wb_wdata = pb_wdata[WB_DW-1:0];
		assign wb_wmsk  = pb_wstrb[(WB_DW/8)-1:0];
		assign wb_we    = |pb_wstrb;
	end

	// Ack / Read-Data
	always @(*)
	begin : wb_or
		integer i;
		wb_rdata_or = 0;
		for (i=0; i<WB_N; i=i+1)
			if (!WB_DECODE_RDATA || wb_cyc[i])
				wb_rdata_or[WB_DW-1:0] = wb_rdata_or[WB_DW-1:0] | wb_rdata[WB_DW*i+:WB_DW];
	end

	if (WB_REG & 4) begin
		// Register
		reg wb_rdy_reg;
		reg [31:0] wb_rdata_reg;

		always @(posedge clk)
			wb_rdy_reg <= |wb_ack;

		always @(posedge clk)
			if (wb_cyc_rst)
				wb_rdata_reg <= 32'h00000000;
			else
				wb_rdata_reg <= wb_rdata_or;

		assign wb_cyc_rst = ~pb_valid | ~pb_addr[31] | wb_rdy_reg;
		assign wb_rdy = wb_rdy_reg;
		assign wb_rdata_out = wb_rdata_reg;
	end else begin
		// Direct connection
		assign wb_cyc_rst = ~pb_valid | ~pb_addr[31];
		assign wb_rdy = |wb_ack;
		assign wb_rdata_out = wb_rdata_or;
	end


	// Final data combining
	// --------------------

	assign pb_rdata = ram_rdata | wb_rdata_out;
	assign pb_ready = ram_rdy | wb_rdy;

endmodule // soc_bridge

`default_nettype wire
