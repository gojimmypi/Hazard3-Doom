`timescale 1ns/1ps
`default_nettype none
module CC_CFG_CTRL (
    input wire CLK, EN, VALID, RECFG,
    input wire [7:0] DATA
);
    integer recfg_rises = 0;
    always @(posedge RECFG) begin
        if (CLK !== 1'b0 || EN !== 1'b0 || VALID !== 1'b0 || DATA !== 8'b0)
            $fatal(1, "v66 unexpectedly streams a configuration command");
        recfg_rises = recfg_rises + 1;
    end
endmodule

module tb_ulx5m_v66_cfg_pin_sense_probe;
    reg clk25 = 1'b0;
    always #5 clk25 = ~clk25;
    wire [7:0] led_n;
    reg [3:0] flash_io = 4'b0000;
    reg flash_cs_n = 1'b1;
    reg flash_sck = 1'b0;
    top_ulx5m_gs_v66_cfg_pin_sense_probe #(
        .RECFG_BITS(8), .HEARTBEAT_BIT(4)
    ) dut (
        .clk25(clk25), .led_n(led_n), .flash_io(flash_io),
        .flash_cs_n(flash_cs_n), .flash_sck(flash_sck)
    );
    integer transitions = 0;
    reg last_heart = 0;
    always @(negedge clk25) begin
        if (led_n[6] !== 1'b1 || led_n[4:0] !== 5'd0)
            $fatal(1, "v66 D6 or D4..D0 primary witness changed");
        if (led_n[7] != last_heart)
            transitions = transitions + 1;
        last_heart = led_n[7];
    end
    initial begin
        repeat (30) @(posedge clk25);
        flash_io = 4'b0001;
        repeat (3) @(posedge clk25);
        #1;
        if (led_n[5] !== 1'b0)
            $fatal(1, "input sense parity did not respond to flash IO0");
        repeat (222) @(posedge clk25);
        #1;
        if (dut.recfg !== 1'b1 || dut.cfg_i.recfg_rises != 1)
            $fatal(1, "RECFG did not assert after 255 clocks");
        repeat (80) @(posedge clk25);
        #1;
        if (dut.cfg_i.recfg_rises != 1 || transitions < 5)
            $fatal(1, "RECFG/primary heartbeat failure");
        $display("[PASS] v66 input-only six-pin RECFG logic simulation (not physical bank-mode proof)");
        $finish;
    end
endmodule
`default_nettype wire
