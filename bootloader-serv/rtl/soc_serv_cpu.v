/*
 * SERV RV32I adapter for the ULX5M-GS read-only GateMate diagnostic.
 *
 * SERV has separate instruction and data buses. The existing SoC bridge
 * accepts one PicoRV32-style request at a time. SERV never asserts both
 * bus cycles simultaneously, so they can be multiplexed without arbitration.
 * Acknowledgements are gated by the active cycle, as required by SERV.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */
`default_nettype none
module soc_serv_cpu (
    input  wire clk,
    input  wire rst,
    output wire mem_valid,
    output wire mem_instr,
    input  wire mem_ready,
    output wire [31:0] mem_addr,
    output wire [31:0] mem_wdata,
    output wire [3:0] mem_wstrb,
    input  wire [31:0] mem_rdata
);
    wire [31:0] ibus_addr;
    wire ibus_cyc;
    wire [31:0] dbus_addr, dbus_wdata;
    wire [3:0] dbus_sel;
    wire dbus_we, dbus_cyc;

    // The existing registered response stage delivers one ACK per request.
    // Never forward an ACK to an inactive SERV bus.
    assign mem_valid = ibus_cyc | dbus_cyc;
    assign mem_instr = ibus_cyc;
    assign mem_addr = ibus_cyc ? ibus_addr : dbus_addr;
    assign mem_wdata = dbus_wdata;
    assign mem_wstrb = (dbus_cyc && dbus_we && !ibus_cyc) ? dbus_sel : 4'b0000;

    serv_rf_top #(
        .RESET_PC(32'h00000000),
        .COMPRESSED(1'b0),
        .ALIGN(1'b0),
        .MDU(1'b0),
        .PRE_REGISTER(0),
        .RESET_STRATEGY("MINI"),
        .WITH_CSR(0),
        .W(1)
    ) cpu_i (
        .clk(clk), .i_rst(rst), .i_timer_irq(1'b0),
        .o_ibus_adr(ibus_addr), .o_ibus_cyc(ibus_cyc),
        .i_ibus_rdt(mem_rdata),
        .i_ibus_ack(mem_ready && ibus_cyc),
        .o_dbus_adr(dbus_addr), .o_dbus_dat(dbus_wdata),
        .o_dbus_sel(dbus_sel), .o_dbus_we(dbus_we),
        .o_dbus_cyc(dbus_cyc), .i_dbus_rdt(mem_rdata),
        .i_dbus_ack(mem_ready && dbus_cyc && !ibus_cyc),
        .i_ext_rd(32'h00000000), .i_ext_ready(1'b0),
        .o_ext_rs1(), .o_ext_rs2(), .o_ext_funct3(),
        .o_mdu_valid()
    );

`ifndef SYNTHESIS
    always @(posedge clk)
        if (!rst && ibus_cyc && dbus_cyc)
            $fatal(1, "SERV asserted instruction and data bus together");
`endif
endmodule
`default_nettype wire
