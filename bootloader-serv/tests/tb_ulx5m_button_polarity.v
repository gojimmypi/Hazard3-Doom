`timescale 1ns / 1ps
`default_nettype none
module tb_ulx5m_button_polarity;
    reg clk25 = 0;
    always #20 clk25 = ~clk25;
    reg [2:0] btn_n = 3'b111;
    wire [7:0] led_n;
    reg saw_heartbeat_high = 0;
    reg saw_heartbeat_low = 0;
    integer pins;

    top_ulx5m_gs_button_polarity #(.HEARTBEAT_BIT(3)) dut (
        .clk25(clk25), .btn_n(btn_n), .led_n(led_n)
    );

    always @(negedge clk25) begin
        if (led_n[7])
            saw_heartbeat_high = 1;
        else
            saw_heartbeat_low = 1;
    end

    task check_levels;
        input [2:0] levels;
        begin
            btn_n = levels;
            repeat (4) @(negedge clk25);
            if (led_n[2:0] !== levels)
                $fatal(1, "Raw levels mismatch: pins=%b LEDs=%b", levels, led_n[2:0]);
            if (led_n[5:3] !== (~levels))
                $fatal(1, "Inverted levels mismatch: pins=%b LEDs=%b", levels, led_n[5:3]);
            if (led_n[6] !== 1'b1)
                $fatal(1, "Probe marker D6 is not on");
        end
    endtask

    initial begin
        // Test all combinations to detect swapped or inverted LED mapping.
        for (pins = 0; pins < 8; pins = pins + 1)
            check_levels(pins[2:0]);
        if (!saw_heartbeat_high || !saw_heartbeat_low)
            $fatal(1, "Heartbeat D7 did not toggle");
        $display("[PASS] Raw and inverse LEDs match all eight button input combinations");
        $display("[PASS] D6 probe marker and D7 heartbeat");
        $display("[BLOCK] No CC_CFG_CTRL, flash, JTAG, or USB simulation");
        $finish;
    end
endmodule
`default_nettype wire
