/*
 * Original ULX4M SoC source adapted for ULX5M-GS V005 USB probe
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

/*
 * ULX5M-GS V005: volatile JTAG-loaded USB enumeration probe.
 * Based on the existing ULX4M PicoRV32 / Wishbone / USB core topology.
 * There is deliberately NO connection to configuration flash.
 * Not a flash bootloader. Do not use for programming SPI flash.
 */
`default_nettype none
module top_ulx5m_gs_usb_probe (
    input  wire clk25,
    input  wire [2:0] btn_n,
    output wire [7:0] led_n,
    inout  wire usb_dp,
    inout  wire usb_dn,
    inout  wire usb_pull_p
);
    localparam integer RAM_AW = 13;
    localparam integer WB_N = 5;
    localparam integer WB_DW = 32;
    localparam integer WB_AW = 16;

    wire clk48, reset, locked;
    sysmgr_gatemate clocks (
        .clk_in(clk25), .rst_in(1'b0), .clk_48m(clk48),
        .rst_out(reset), .locked(locked)
    );

    wire mem_valid, mem_instr, mem_ready;
    wire bridge_valid, bridge_ready;
    wire [31:0] bridge_rdata;
    wire [31:0] mem_addr, mem_rdata, mem_wdata;
    wire [3:0] mem_wstrb;
    wire [RAM_AW-1:0] bram_addr;
    wire [31:0] bram_rdata, bram_wdata;
    wire [3:0] bram_wmsk;
    wire bram_we;

    wire [WB_AW-1:0] wb_addr;
    wire [WB_DW-1:0] wb_wdata;
    wire [WB_DW/8-1:0] wb_wmsk;
    wire [WB_DW*WB_N-1:0] wb_rdata_flat;
    wire [WB_DW-1:0] wb_rdata [0:WB_N-1];
    wire [WB_N-1:0] wb_cyc, wb_ack;
    wire wb_we;
    genvar i;
    generate for (i = 0; i < WB_N; i = i + 1) begin : gen_rdata
        assign wb_rdata_flat[i*WB_DW+:WB_DW] = wb_rdata[i];
    end endgenerate

    picorv32 #(
        .PROGADDR_RESET(32'h00000000),
        .STACKADDR(4 << RAM_AW),
        .BARREL_SHIFTER(0),
        .COMPRESSED_ISA(0),
        .ENABLE_REGS_DUALPORT(1),
        .ENABLE_COUNTERS(0),
        .ENABLE_COUNTERS64(0),
        .ENABLE_MUL(0),
        .ENABLE_DIV(0),
        .ENABLE_IRQ(0),
        .ENABLE_IRQ_QREGS(0),
        .CATCH_MISALIGN(0),
        .CATCH_ILLINSN(0)
    ) cpu_i (
        .clk(clk48), .resetn(~reset),
        .mem_valid(mem_valid), .mem_instr(mem_instr),
        .mem_ready(mem_ready), .mem_addr(mem_addr),
        .mem_wdata(mem_wdata), .mem_wstrb(mem_wstrb),
        .mem_rdata(mem_rdata)
    );

    // GateMate-specific response staging: isolate the synchronous BRAM output
    // from PicoRV32's instruction decode. Stall the bridge after it acknowledges
    // a request until the CPU has observed the registered response. This also
    // prevents repeated writes while the CPU is consuming that response.
    // USB and CPU still run from the same 48 MHz clock (no clock-domain crossing).
    soc_mem_response_reg response_i (
        .clk(clk48), .rst(reset),
        .cpu_valid(mem_valid), .cpu_ready(mem_ready), .cpu_rdata(mem_rdata),
        .bridge_valid(bridge_valid), .bridge_ready(bridge_ready),
        .bridge_rdata(bridge_rdata)
    );

    // Register Wishbone acknowledgements and read data before returning them
    // to PicoRV32. BRAM access remains on the original bridge handshake path.
    soc_bridge #(
        .RAM_AW(RAM_AW), .WB_N(WB_N),
        .WB_DW(WB_DW), .WB_AW(WB_AW), .WB_AI(2),
        .WB_REG(4)
    ) bridge_i (
        .pb_addr(mem_addr), .pb_rdata(bridge_rdata),
        .pb_wdata(mem_wdata), .pb_wstrb(mem_wstrb),
        .pb_valid(bridge_valid), .pb_ready(bridge_ready),
        .bram_addr(bram_addr), .bram_rdata(bram_rdata),
        .bram_wdata(bram_wdata), .bram_wmsk(bram_wmsk),
        .bram_we(bram_we), .wb_addr(wb_addr),
        .wb_wdata(wb_wdata), .wb_wmsk(wb_wmsk),
        .wb_rdata(wb_rdata_flat), .wb_cyc(wb_cyc),
        .wb_we(wb_we), .wb_ack(wb_ack),
        .clk(clk48), .rst(reset)
    );

    // Firmware is compiled into this word-addressed RAM image before
    // GateMate synthesis. No ECP5 ecpbram patching is needed.
    soc_bram #(.AW(RAM_AW), .INIT_FILE("build-ulx5m-gs/fw_ulx5m_probe.hex")) bram_i (
        .addr(bram_addr), .rdata(bram_rdata),
        .wdata(bram_wdata), .wmsk(bram_wmsk),
        .we(bram_we), .clk(clk48)
    );

    // Peripheral 0: minimal LED/button register block, without ECP5 pads.
    soc_ulx5m_misc misc_i (
        .led_n(led_n), .btn_n(btn_n), .locked(locked),
        .bus_addr(wb_addr[3:0]), .bus_wdata(wb_wdata),
        .bus_rdata(wb_rdata[0]), .bus_cyc(wb_cyc[0]),
        .bus_ack(wb_ack[0]), .bus_we(wb_we),
        .clk(clk48), .rst(reset)
    );

    // Peripheral 1: console UART (TX unconnected; RX idle).
    wire unused_uart_tx;
    uart_wb #(.DIV_WIDTH(16), .DW(WB_DW)) uart_i (
        .uart_tx(unused_uart_tx), .uart_rx(1'b1),
        .bus_addr(wb_addr[1:0]), .bus_wdata(wb_wdata),
        .bus_rdata(wb_rdata[1]), .bus_cyc(wb_cyc[1]),
        .bus_ack(wb_ack[1]), .bus_we(wb_we),
        .clk(clk48), .rst(reset)
    );

    wire [8:0] ep_tx_addr, ep_rx_addr;
    wire [31:0] ep_tx_data, ep_rx_data;
    wire ep_tx_we, ep_rx_re;
    wire usb_attach;

    // Peripheral 2: USB controller using the already-routed GateMate PHY.
    usb #(.TARGET("GATEMATE"), .EPDW(32),
           .MC_INIT_FILE("build-ulx5m-gs/usb_trans_mc.hex")) usb_i (
        .pad_dp(usb_dp), .pad_dn(usb_dn), .pad_pu(usb_attach),
        .ep_tx_addr_0(ep_tx_addr), .ep_tx_data_0(ep_tx_data),
        .ep_tx_we_0(ep_tx_we), .ep_rx_addr_0(ep_rx_addr),
        .ep_rx_data_1(ep_rx_data), .ep_rx_re_0(ep_rx_re),
        .ep_clk(clk48),
        .bus_addr(wb_addr[11:0]), .bus_din(wb_wdata[15:0]),
        .bus_dout(wb_rdata[2][15:0]),
        .bus_cyc(wb_cyc[2]), .bus_we(wb_we),
        .bus_ack(wb_ack[2]), .irq(), .sof(),
        .clk(clk48), .rst(reset)
    );
    assign wb_rdata[2][31:16] = 16'h0000;

    // USB full-speed D+ attach uses the V005 diode/1k resistor circuit.
    // High -> pull D+ up; disabled -> high-Z (never drive low).
    // USB_PULL_N is not used and must remain unconstrained/high-Z.
    CC_IOBUF #(.V_IO("3.3"), .PULLUP(1'b0), .PULLDOWN(1'b0)) attach_i (
        .IO(usb_pull_p), .A(1'b1), .T(~usb_attach | reset), .Y()
    );

    // Peripheral 3: endpoint RAM window shared with the USB controller.
    reg wb_ack_ep;
    always @(posedge clk48) begin
        if (reset)
            wb_ack_ep <= 1'b0;
        else
            wb_ack_ep <= wb_cyc[3] & ~wb_ack_ep;
    end
    assign wb_ack[3] = wb_ack_ep;
    assign ep_tx_addr = wb_addr[8:0];
    assign ep_tx_data = wb_wdata;
    assign ep_tx_we = wb_cyc[3] & ~wb_ack_ep & wb_we;
    assign ep_rx_addr = wb_addr[8:0];
    assign ep_rx_re = 1'b1;
    assign wb_rdata[3] = wb_cyc[3] ? ep_rx_data : 32'h00000000;

    // Peripheral 4: intentionally absent SPI/QSPI hardware.
    // Firmware never calls SPI; this provides a non-hanging bus response
    // if a stray read/write reaches the unmapped address. No flash pads.
    reg wb_ack_spi;
    always @(posedge clk48) begin
        if (reset)
            wb_ack_spi <= 1'b0;
        else
            wb_ack_spi <= wb_cyc[4] & ~wb_ack_spi;
    end
    assign wb_ack[4] = wb_ack_spi;
    assign wb_rdata[4] = 32'h00000000;
endmodule
`default_nettype wire
