`timescale 1ns/1ps
`default_nettype none
module CC_CFG_CTRL (
    input wire CLK, EN, VALID, RECFG,
    input wire [7:0] DATA
);
    integer recfg_rises = 0;
    always @(posedge RECFG) begin
        if (CLK !== 1'b0 || EN !== 1'b0 || VALID !== 1'b0 || DATA !== 8'b0)
            $fatal(1, "v65 unexpectedly uses configuration-byte stream");
        recfg_rises = recfg_rises + 1;
    end
endmodule

module tb_ulx5m_v65_multiboot_probe;
    reg clk25 = 1'b0;
    always #5 clk25 = ~clk25;
    wire [7:0] led_n;
    top_ulx5m_gs_v65_multiboot_probe #(
        .RECFG_BITS(8), .HEARTBEAT_BIT(4)
    ) dut (.clk25(clk25), .led_n(led_n));
    integer heart_transitions = 0;
    reg last_heart = 0;
    always @(negedge clk25) begin
        if (led_n[6] !== 1'b1 || led_n[5:0] !== 6'd0)
            $fatal(1, "unexpected primary LEDs");
        if (led_n[7] != last_heart)
            heart_transitions = heart_transitions + 1;
        last_heart = led_n[7];
    end
    initial begin
        repeat (255) @(posedge clk25);
        #1;
        if (dut.recfg !== 1'b1 || dut.cfg_i.recfg_rises != 1)
            $fatal(1, "RECFG did not assert exactly once after 255 clocks");
        repeat (120) @(posedge clk25);
        #1;
        if (dut.cfg_i.recfg_rises != 1 || !dut.recfg)
            $fatal(1, "RECFG not held stable");
        if (heart_transitions < 5)
            $fatal(1, "primary heartbeat stopped after RECFG");
        $display("[PASS] v65 upstream-equivalent RECFG-only source; no user SPI pins");
        $finish;
    end
endmodule
`default_nettype wire
