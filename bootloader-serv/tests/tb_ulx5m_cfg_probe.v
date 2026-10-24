`timescale 1ns / 1ps
`default_nettype none
// This is ONLY a timing/byte sink, not a GateMate configuration model.
module CC_CFG_CTRL(
    input wire CLK, EN, VALID, RECFG,
    input wire [7:0] DATA
);
endmodule

module tb_ulx5m_cfg_probe;
    localparam integer SIZE = 3026;
    reg clk25 = 0;
    always #20 clk25 = ~clk25;
    reg btn3_n = 0;
    wire [7:0] led_n;
    reg [7:0] expected [0:SIZE-1];
    integer accepted = 0;
    integer en_cycles = 0;
    integer idle_cycles = 0;
    integer tail_cycles = 0;
    integer timeout_cycles = 0;
    reg ever_enabled = 0;

    top_ulx5m_gs_cfg_probe #(.HOLD_BITS(4)) dut (
        .clk25(clk25), .btn3_n(btn3_n), .led_n(led_n)
    );

    initial $readmemh("build-ulx5m-gs/cfg-probe/walking-led.hex", expected);

    always @(posedge clk25) begin
        if (dut.en) begin
            ever_enabled = 1;
            en_cycles = en_cycles + 1;
            if (!dut.valid)
                idle_cycles = idle_cycles + 1;
            if (accepted == SIZE && !dut.valid)
                tail_cycles = tail_cycles + 1;
        end
        if (dut.valid) begin
            if (!dut.en || !dut.cfg_i.RECFG)
                $fatal(1, "VALID without EN/RECFG");
            if (accepted == 0 && en_cycles < 3)
                $fatal(1, "EN lead shorter than three clocks");
            if (accepted != 0 && idle_cycles < 1)
                $fatal(1, "VALID gap missing");
            if (accepted >= SIZE || dut.data !== expected[accepted])
                $fatal(1, "Byte mismatch at %0d", accepted);
            accepted = accepted + 1;
            idle_cycles = 0;
            tail_cycles = 0;
        end
        if (ever_enabled && !dut.en) begin
            if (accepted != SIZE || tail_cycles < 8)
                $fatal(1, "Incomplete stream or EN tail: bytes=%0d tail=%0d",
                       accepted, tail_cycles);
            $display("[PASS] 3026 exact configuration bytes, EN/VALID lead/gaps/tail");
            $display("[NOTE] CFG primitive stub; no physical reconfiguration occurred");
            $finish;
        end
    end

    initial begin
        // Power-up with BTN3 held must NEVER be sufficient to start.
        repeat (60) @(negedge clk25);
        if (dut.en || accepted != 0)
            $fatal(1, "Auto-configured while button was held at power-up");
        btn3_n = 1;
        repeat (100) @(negedge clk25);
        if (dut.en || accepted != 0 || !dut.button_armed)
            $fatal(1, "Not safely armed by release, or started early");
        $display("[PASS] BTN3 release required; no automatic configuration");
        btn3_n = 0;
        repeat (40) @(negedge clk25);
        btn3_n = 1;
        while (accepted < SIZE && timeout_cycles < 25000) begin
            @(negedge clk25);
            timeout_cycles = timeout_cycles + 1;
        end
        if (accepted != SIZE)
            $fatal(1, "Timed out after %0d accepted bytes", accepted);
        repeat (32) @(negedge clk25);
        $fatal(1, "Expected EN tail completion");
    end
endmodule
`default_nettype wire
