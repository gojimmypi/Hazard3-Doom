`timescale 1ns/1ps
`default_nettype none
module CC_CFG_CTRL (
    input wire CLK, EN, VALID, RECFG,
    input wire [7:0] DATA
);
    integer rises = 0;
    always @(posedge RECFG) begin
        if (CLK || EN || VALID || DATA != 8'd0)
            $fatal(1, "RECFG-only mode must not stream config bytes");
        rises = rises + 1;
    end
endmodule

module tb_ulx5m_spi_active_reboot;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1;
    reg normal_mode = 0;
    reg spi_idle = 0;
    reg [2:0] bus_addr = 0;
    reg [31:0] bus_wdata = 0;
    reg bus_cyc = 0, bus_we = 0;
    wire [31:0] bus_rdata;
    wire bus_ack;
    wire release_spi;
    reg release_seen_on_previous_clock = 1'b0;
    always @(posedge clk) release_seen_on_previous_clock <= release_spi;
    always @(posedge dut.recfg)
        if (!release_seen_on_previous_clock)
            $fatal(1, "RECFG asserted before SPI pins were released");
    integer seen;
    ulx5m_spi_active_reboot_wb dut (
        .clk(clk), .rst(rst), .normal_mode(normal_mode),
        .spi_idle(spi_idle), .bus_addr(bus_addr),
        .bus_wdata(bus_wdata), .bus_rdata(bus_rdata),
        .bus_cyc(bus_cyc), .bus_we(bus_we), .bus_ack(bus_ack),
        .release_spi(release_spi)
    );
    task wb_write;
        input [2:0] addr;
        input [31:0] data;
        begin
            @(negedge clk); bus_addr = addr; bus_wdata = data;
            bus_we = 1; bus_cyc = 1;
            @(negedge clk); bus_cyc = 0; bus_we = 0;
            repeat (3) @(negedge clk);
        end
    endtask
    task restart;
        begin
            @(negedge clk); rst = 1;
            repeat (3) @(negedge clk);
            rst = 0;
            repeat (3) @(negedge clk);
        end
    endtask
    initial begin
        repeat (3) @(negedge clk); rst = 0;
        spi_idle = 1;
        repeat (40) @(negedge clk);
        // DFU selection: writes cannot reconfigure the FPGA.
        wb_write(1, 32'h41524d31);
        wb_write(2, 32'h424f4f54);
        if (dut.recfg || dut.fired || release_spi) $fatal(1, "DFU mode rebooted");
        normal_mode = 1;
        repeat (40) @(negedge clk);
        // An unarmed request fails closed.
        wb_write(2, 32'h424f4f54);
        if (!dut.error || dut.recfg) $fatal(1, "Unarmed reboot");
        restart();
        repeat (40) @(negedge clk);
        // Arm becomes invalid if SPI chip select goes active.
        wb_write(1, 32'h41524d31);
        if (!dut.armed) $fatal(1, "Expected armed");
        spi_idle = 0;
        repeat (3) @(negedge clk);
        if (dut.armed == 1 || !dut.error) $fatal(1, "SPI busy not rejected");
        wb_write(2, 32'h424f4f54);
        if (dut.recfg) $fatal(1, "SPI busy triggered reboot");
        spi_idle = 1;
        restart();
        repeat (40) @(negedge clk);
        if (!dut.qualified) $fatal(1, "Expected stable idle");
        wb_write(1, 32'h41524d31);
        wb_write(2, 32'h424f4f54);
        if (!dut.recfg || !dut.fired || !release_spi || dut.cfg_i.rises != 1)
            $fatal(1, "No single RECFG event");
        wb_write(2, 32'h424f4f54);
        if (dut.cfg_i.rises != 1) $fatal(1, "Repeated RECFG");
        restart();
        if (dut.recfg || dut.fired || release_spi) $fatal(1, "Reboot request not reset");
        $display("[PASS] v47 SPI-active RECFG controller, six scenarios");
        $finish;
    end
endmodule
`default_nettype wire
