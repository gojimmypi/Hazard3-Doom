`timescale 1ns/1ps
`default_nettype none
module tb_ulx5m_v70_cfg_runtime_clear;
    reg clk = 1'b0;
    always #20 clk = ~clk;
    reg [3:0] flash_io = 4'b1010;
    reg flash_cs_n = 1'b1;
    reg flash_sck = 1'b0;
    wire [7:0] leds;
    integer cycles = 0;
    integer valid_bytes = 0;
    integer enabled_lead = 0;
    integer since_last_valid = 0;
    integer tail_cycles = 0;
    reg saw_recfg = 1'b0;
    reg prev_valid = 1'b0;
    reg [7:0] expected [0:26];

    top_ulx5m_gs_v70_cfg_runtime_clear_probe #(
        .RECFG_BITS(6), .HEARTBEAT_BIT(4)
    ) dut (
        .clk25(clk), .flash_io(flash_io),
        .flash_cs_n(flash_cs_n), .flash_sck(flash_sck), .led_n(leds)
    );

    // Passive primitive stub. This monitors the clocked interface only.
    // No simulation model of actual configuration-bank mode switching.
    initial begin
        expected[0] = 8'hdb; expected[1] = 8'h0c;
        expected[2] = 8'hb8; expected[3] = 8'h7e;
        expected[4] = 8'h17; expected[5] = 8'h10;
        expected[6] = 8'h00; expected[7] = 8'h20;
        expected[8] = 8'h04; expected[9] = 8'h01;
        expected[10] = 0; expected[11] = 0;
        expected[12] = 0; expected[13] = 0;
        expected[14] = 0; expected[15] = 0;
        expected[16] = 8'h5d; expected[17] = 8'h31;
        expected[18] = 0; expected[19] = 0;
        expected[20] = 0; expected[21] = 0;
        expected[22] = 8'h33;
        expected[23] = 0; expected[24] = 0;
        expected[25] = 0; expected[26] = 0;
    end

    always @(posedge clk) begin
        cycles = cycles + 1;
        if (dut.cfg_valid && !dut.cfg_en)
            $fatal(1,"VALID without EN");
        if (dut.cfg_valid) begin
            if (valid_bytes == 0 && enabled_lead < 3)
                $fatal(1,"fewer than 3 lead clocks");
            if (valid_bytes > 0 && since_last_valid < 1)
                $fatal(1,"missing idle clock between bytes");
            if (valid_bytes >= 27 || dut.cfg_data !== expected[valid_bytes])
                $fatal(1,"unexpected byte index=%0d byte=%02x", valid_bytes, dut.cfg_data);
            valid_bytes = valid_bytes + 1;
            since_last_valid = 0;
            tail_cycles = 0;
            prev_valid = 1;
        end else begin
            if (dut.cfg_en && valid_bytes == 0)
                enabled_lead = enabled_lead + 1;
            if (prev_valid)
                since_last_valid = since_last_valid + 1;
            if (dut.cfg_en && valid_bytes == 27)
                tail_cycles = tail_cycles + 1;
            prev_valid = 0;
        end
        if (dut.recfg) begin
            if (valid_bytes != 27 || tail_cycles < 8 || dut.cfg_en || dut.cfg_valid)
                $fatal(1,"RECFG before full command and >=8 idle tail clocks");
            if (!saw_recfg)
                $display("[PASS] v70 synthetic 27-byte CC_CFG_CTRL runtime-status frame + RECFG timing; hardware semantics UNPROVEN");
            saw_recfg = 1'b1;
        end
        if (cycles > 220) begin
            if (!saw_recfg) $fatal(1,"timeout waiting for RECFG");
            $finish;
        end
    end
endmodule

module CC_CFG_CTRL (
    input wire CLK, EN, VALID, RECFG,
    input wire [7:0] DATA
);
endmodule
`default_nettype wire
