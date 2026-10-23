`timescale 1ns / 1ps
`default_nettype none
module tb_ulx5m_normal_boot_reset;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg mode_valid = 1'b0;
    wire fw_reset;

    always #10 clk = ~clk;

    ulx5m_normal_boot_reset dut (
        .clk(clk), .rst(rst), .mode_valid(mode_valid),
        .fw_reset(fw_reset)
    );

    initial begin
        #1;
        if (fw_reset !== 1'b1) $fatal(1, "Power-on reset not asserted");
        repeat (3) @(negedge clk);
        rst = 1'b0;
        repeat (3) @(negedge clk);
        if (fw_reset !== 1'b1)
            $fatal(1, "Firmware ran before BTN2 mode latch");

        // Make the mode valid between clock edges. No early release.
        #3 mode_valid = 1'b1;
        #2;
        if (fw_reset !== 1'b1)
            $fatal(1, "Release occurred before a rising clock edge");
        @(posedge clk);
        #1;
        if (fw_reset !== 1'b0) $fatal(1, "Latched mode did not release");

        // Assert reset between clock edges, independent of PLL clock.
        @(negedge clk);
        #3 rst = 1'b1;
        #1;
        if (fw_reset !== 1'b1)
            $fatal(1, "Global reset must assert immediately");
        mode_valid = 1'b0;
        repeat (2) @(negedge clk);
        rst = 1'b0;
        repeat (2) @(negedge clk);
        if (fw_reset !== 1'b1)
            $fatal(1, "Firmware released after reset without mode");
        mode_valid = 1'b1;
        @(posedge clk);
        #1;
        if (fw_reset !== 1'b0)
            $fatal(1, "Re-latched mode did not release");
        $display("[PASS] Normal-boot firmware reset: async assert, clocked release, no early execution");
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "Normal-boot reset test timeout");
    end
endmodule
`default_nettype wire
