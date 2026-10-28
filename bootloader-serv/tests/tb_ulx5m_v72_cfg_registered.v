`timescale 1ns/1ps
`default_nettype none
module tb_ulx5m_v72_cfg_registered;
    reg clk = 1'b0;
    always #20 clk = ~clk;
    reg [3:0] flash_io = 4'b1010;
    reg flash_cs_n = 1'b1;
    reg flash_sck = 1'b0;
    wire [7:0] led_n;
    integer cycles = 0;
    integer sent = 0;
    integer lead = 0;
    integer gap = 0;
    integer tail = 0;
    integer quiet = 0;
    reg started = 1'b0;
    reg saw_recfg = 1'b0;
    reg [7:0] expected [0:26];

    initial $readmemh("build-ulx5m-gs/v72-registered-probe/cmd.hex", expected);
    top_ulx5m_gs_v72_cfg_registered_probe #(
        .RECFG_BITS(6), .HEARTBEAT_BIT(4)
    ) dut (
        .clk25(clk), .flash_io(flash_io),
        .flash_cs_n(flash_cs_n), .flash_sck(flash_sck), .led_n(led_n)
    );

    always @(posedge clk) begin
        cycles = cycles + 1;
        if (dut.cfg_valid && !dut.cfg_en)
            $fatal(1, "VALID without EN");
        if (dut.cfg_valid) begin
            if (sent == 0 && lead < 3)
                $fatal(1, "EN lead shorter than three clocks");
            if (sent > 0 && gap < 1)
                $fatal(1, "missing interbyte idle clock");
            if (sent >= 27 || dut.cfg_data !== expected[sent])
                $fatal(1, "unexpected byte number %0d: %02x", sent, dut.cfg_data);
            sent = sent + 1;
            started = 1'b1;
            gap = 0;
            tail = 0;
        end else begin
            if (!started && dut.cfg_en)
                lead = lead + 1;
            if (started && sent < 27)
                gap = gap + 1;
            if (sent == 27 && dut.cfg_en)
                tail = tail + 1;
            if (sent == 27 && !dut.cfg_en && !dut.recfg)
                quiet = quiet + 1;
        end
        if (dut.recfg) begin
            if (sent != 27 || tail < 8 || quiet < 16 || dut.cfg_en || dut.cfg_valid)
                $fatal(1, "RECFG before complete command, EN tail or settle period");
            if (!saw_recfg)
                $display("[PASS] v72 registered 27 bytes, EN tail=%0d, quiet=%0d; silicon behavior NOT modeled", tail, quiet);
            saw_recfg = 1;
        end
        if (cycles > 220) begin
            if (!saw_recfg)
                $fatal(1, "timeout waiting for RECFG");
            $finish;
        end
    end
endmodule

// Passive interface stub. This is not a GateMate configuration simulator.
module CC_CFG_CTRL (
    input wire CLK, EN, VALID, RECFG,
    input wire [7:0] DATA
);
endmodule
`default_nettype wire
