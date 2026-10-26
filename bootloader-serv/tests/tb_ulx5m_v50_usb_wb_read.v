/* Reproduce v47 stale BTN2 register contamination of USB read data.
 * Real soc_bridge + real soc_ulx5m_misc; no USB PHY or flash access.
 * SELECTED=0 is the broken v47 behavior, SELECTED=1 is the v50 fix.
 */
`timescale 1ns/1ps
`default_nettype none
module tb_ulx5m_v50_usb_wb_read;
    parameter integer SELECTED = 1;
    reg clk = 0;
    reg rst = 1;
    always #5 clk = ~clk;

    reg [31:0] pb_addr = 32'd0;
    reg pb_valid = 0;
    wire [31:0] pb_rdata;
    wire pb_ready;
    wire [15:0] wb_addr;
    wire [31:0] wb_wdata;
    wire [3:0] wb_wmsk;
    wire wb_we;
    wire [5:0] wb_cyc;
    wire [5:0] wb_ack;
    wire [31:0] misc_rdata;
    wire misc_ack;
    wire [7:0] unused_leds;
    reg usb_ack = 0;
    wire [12:0] unused_bram_addr;
    wire [31:0] unused_bram_wdata;
    wire [3:0] unused_bram_wmsk;
    wire unused_bram_we;
    wire [31:0] usb_rdata = wb_cyc[2] ? 32'h00008000 : 32'd0;
    wire [191:0] responses = {32'd0, 32'd0, 32'd0,
                              usb_rdata, 32'd0, misc_rdata};

    soc_ulx5m_misc misc_i (
        .led_n(unused_leds), .btn_n(3'b101), .locked(1'b1),
        .mode_valid(1'b1), .dfu_selected(1'b1),
        .bus_addr(wb_addr[3:0]), .bus_wdata(wb_wdata),
        .bus_rdata(misc_rdata), .bus_cyc(wb_cyc[0]),
        .bus_ack(misc_ack), .bus_we(wb_we), .clk(clk), .rst(rst)
    );
    always @(posedge clk)
        if (rst) usb_ack <= 0;
        else usb_ack <= wb_cyc[2] && !usb_ack;
    assign wb_ack = {3'd0, usb_ack, 1'b0, misc_ack};

    soc_bridge #(
        .RAM_AW(13), .WB_N(6), .WB_DW(32), .WB_AW(16),
        .WB_AI(2), .WB_REG(4), .BRAM_REG(1),
        .WB_DECODE_RDATA(SELECTED)
    ) bridge_i (
        .pb_addr(pb_addr), .pb_rdata(pb_rdata),
        .pb_wdata(32'd0), .pb_wstrb(4'd0),
        .pb_valid(pb_valid), .pb_ready(pb_ready),
        .bram_addr(unused_bram_addr), .bram_rdata(32'd0),
        .bram_wdata(unused_bram_wdata), .bram_wmsk(unused_bram_wmsk),
        .bram_we(unused_bram_we),
        .wb_addr(wb_addr), .wb_wdata(wb_wdata),
        .wb_wmsk(wb_wmsk), .wb_rdata(responses),
        .wb_cyc(wb_cyc), .wb_we(wb_we), .wb_ack(wb_ack),
        .clk(clk), .rst(rst)
    );

    task read_reg(input [31:0] address, input [31:0] expected);
        integer cycles;
        begin
            @(negedge clk);
            pb_addr = address;
            pb_valid = 1;
            cycles = 0;
            while (!pb_ready && cycles < 16) begin
                @(negedge clk);
                cycles = cycles + 1;
            end
            if (!pb_ready)
                $fatal(1, "Wishbone read timed out at %h", address);
            if (pb_rdata !== expected)
                $fatal(1, "Read %h returned %h, expected %h", address, pb_rdata, expected);
            pb_valid = 0;
            repeat (4) @(negedge clk);
        end
    endtask

    initial begin
        #5000;
        $fatal(1, "Simulation timed out");
    end
    initial begin
        repeat (4) @(negedge clk);
        rst = 0;
        read_reg(32'h80000004, 32'h00000003);
        if (misc_rdata !== 32'h00000003)
            $fatal(1, "Real misc peripheral did not retain BTN2 value");
        if (SELECTED == 0) begin
            read_reg(32'h82000000, 32'h00008003);
            $display("[PASS] v47 bug reproduced: stale 0x3 contaminated USB CSR");
        end else begin
            read_reg(32'h82000000, 32'h00008000);
            $display("[PASS] v50 fix: USB CSR excludes inactive BTN2 mode read");
        end
        $finish;
    end
endmodule
`default_nettype wire
