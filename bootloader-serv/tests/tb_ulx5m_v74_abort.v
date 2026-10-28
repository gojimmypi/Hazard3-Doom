`timescale 1ns/1ps
`default_nettype none
module CC_CFG_CTRL (
    input wire CLK, EN, VALID, RECFG,
    input wire [7:0] DATA
);
endmodule

module tb_ulx5m_v74_abort;
    reg clk = 0;
    always #10 clk = ~clk;
    reg cfg_clk = 0;
    always #20 cfg_clk = ~cfg_clk;
    reg rst = 1;
    reg normal_mode = 0;
    reg spi_idle = 1;
    reg [2:0] bus_addr = 0;
    reg [31:0] bus_wdata = 0;
    reg bus_cyc = 0;
    reg bus_we = 0;
    wire [31:0] bus_rdata;
    wire bus_ack, release_spi;

    ulx5m_spi_active_reboot_wb dut (
        .clk(clk), .cfg_clk(cfg_clk), .rst(rst),
        .normal_mode(normal_mode), .spi_idle(spi_idle),
        .bus_addr(bus_addr), .bus_wdata(bus_wdata), .bus_rdata(bus_rdata),
        .bus_cyc(bus_cyc), .bus_we(bus_we), .bus_ack(bus_ack),
        .release_spi(release_spi)
    );

    task send_write(input [2:0] addr, input [31:0] value);
        begin
            @(negedge clk);
            bus_addr = addr; bus_wdata = value; bus_we = 1; bus_cyc = 1;
            @(negedge clk);
            bus_cyc = 0; bus_we = 0;
            repeat (3) @(negedge clk);
        end
    endtask

    initial begin
        repeat (4) @(negedge clk);
        rst = 0;
        normal_mode = 1;
        repeat (38) @(negedge clk);
        send_write(3'd1, 32'h41524d31);
        if (!dut.armed) $fatal(1, "ARM failed");
        send_write(3'd2, 32'h424f4f54);
        if (!release_spi || !dut.fired) $fatal(1, "BOOT failed");
        repeat (10) @(negedge cfg_clk);
        spi_idle = 0;
        repeat (5) @(negedge cfg_clk);
        spi_idle = 1;
        repeat (150) @(negedge cfg_clk);
        if (!dut.cfg_abort || dut.recfg || dut.cfg_en || dut.cfg_valid)
            $fatal(1, "Failed to abort unsafe SPI-busy handoff");
        if (!dut.error)
            $fatal(1, "CDC abort not reported to Wishbone domain");
        $display("[PASS] v74 synchronized SPI-busy abort blocks RECFG");
        $finish;
    end
endmodule
`default_nettype wire
