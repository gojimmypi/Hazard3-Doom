`timescale 1ns/1ps
`default_nettype none
module tb_ulx5m_normal_boot_wb_decode;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1;
    reg [31:0] pb_addr = 32'h82000000;
    reg pb_valid = 0;
    reg [5:0] wb_ack = 0;
    reg [191:0] wb_rdata = 0;
    wire [5:0] wb_cyc;
    wire [31:0] pb_rdata;
    wire pb_ready;
    wire [12:0] bram_addr;
    wire [31:0] bram_wdata;
    wire [3:0] bram_wmsk;
    wire bram_we;
    wire [15:0] wb_addr;
    wire [31:0] wb_wdata;
    wire [3:0] wb_wmsk;
    wire wb_we;
    integer i;
    soc_bridge #(
        .RAM_AW(13), .WB_N(6), .WB_DW(32), .WB_AW(16), .WB_AI(2),
        .WB_REG(4), .BRAM_REG(1), .WB_DECODE_RDATA(1)
    ) dut (
        .pb_addr(pb_addr), .pb_rdata(pb_rdata), .pb_wdata(32'd0),
        .pb_wstrb(4'd0), .pb_valid(pb_valid), .pb_ready(pb_ready),
        .bram_addr(bram_addr), .bram_rdata(32'd0),
        .bram_wdata(bram_wdata), .bram_wmsk(bram_wmsk), .bram_we(bram_we),
        .wb_addr(wb_addr), .wb_wdata(wb_wdata), .wb_wmsk(wb_wmsk),
        .wb_rdata(wb_rdata), .wb_cyc(wb_cyc), .wb_we(wb_we),
        .wb_ack(wb_ack), .clk(clk), .rst(rst)
    );
    task check_read(input integer n, input [31:0] value);
    begin
        @(negedge clk);
        rst=1; pb_valid=0; wb_ack=0;
        @(posedge clk);
        @(negedge clk);
        rst=0;
        pb_addr=32'h80000000 | (n << 24);
        pb_valid=1;
        #1;
        if (wb_cyc !== (6'b000001 << n) ||
            dut.wb_rdata_or !== value)
            $fatal(1, "Selected bus %0d returned %h, expected %h",
                   n, dut.wb_rdata_or, value);
        @(negedge clk);
        wb_ack=(6'b000001 << n);
        @(posedge clk); #1;
        if (!pb_ready || pb_rdata !== value)
            $fatal(1, "Registered bus %0d read = %h, expected %h",
                   n, pb_rdata, value);
    end
    endtask
    initial begin
        // Every inactive responder deliberately retains nonzero stale data.
        wb_rdata[0*32+:32] = 32'h00000003; // BTN2 mode read
        wb_rdata[1*32+:32] = 32'h11111111;
        wb_rdata[2*32+:32] = 32'h12345678; // USB CSR
        wb_rdata[3*32+:32] = 32'h33333333;
        wb_rdata[4*32+:32] = 32'h44444444; // flash data
        wb_rdata[5*32+:32] = 32'h00000011; // CFG capability and ready
        check_read(2, 32'h12345678);
        check_read(4, 32'h44444444);
        check_read(5, 32'h00000011);
        check_read(0, 32'h00000003);
        @(negedge clk);
        pb_valid=0; wb_ack=0;
        @(posedge clk); #1;
        if (dut.wb_rdata_or !== 32'h00000000)
            $fatal(1, "Inactive Wishbone responders leaked data");
        $display("[PASS] Selected USB, SPI, CFG and BTN2 readback isolated");
        $finish;
    end
endmodule
`default_nettype wire
