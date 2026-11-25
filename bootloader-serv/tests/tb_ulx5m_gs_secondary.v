`timescale 1ns/1ps
module tb_ulx5m_gs_secondary;
    reg clk25 = 0;
    wire [7:0] led_n;
    integer step;
    reg [7:0] expected;

    always #5 clk25 = ~clk25;
    top_ulx5m_gs_secondary #(.STEP_TICKS(4)) dut (
        .clk25(clk25), .led_n(led_n)
    );

    initial begin
        #1;
        if (led_n !== 8'h02)
            $fatal(1, "incorrect initial D1 LED");
        for (step = 1; step <= 14; step = step + 1) begin
            repeat (4) @(posedge clk25);
            #1;
            expected = (8'h02 << (step % 7)) | (step % 2);
            if (led_n !== expected)
                $fatal(1, "step %0d: got %02x expected %02x", step, led_n, expected);
        end
        $display("[PASS] 14 LED steps, heartbeat and D1..D7 walking pattern");
        $finish;
    end
endmodule
