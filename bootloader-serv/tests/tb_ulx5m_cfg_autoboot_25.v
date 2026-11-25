`timescale 1ns/1ps
`default_nettype none
module CC_CFG_CTRL (
    input wire CLK, EN, VALID, RECFG,
    input wire [7:0] DATA
);
endmodule

module tb_ulx5m_cfg_autoboot_25;
    reg clk25 = 1'b0;
    reg clk48 = 1'b0;
    reg run_pll = 1'b1;
    reg normal_mode = 1'b0;
    wire release_spi;
    reg [7:0] expected [0:26];
    integer bytes_seen = 0;
    integer cycles = 0;
    integer last_valid_cycle = -100;
    integer first_en_cycle = -100;
    integer last_valid_end = -100;
    integer first_recfg_cycle = -100;
    reg prev_en = 1'b0;
    reg prev_valid = 1'b0;
    always #20 clk25 = ~clk25;
    always begin
        #10.416;
        if (run_pll)
            clk48 = ~clk48;
    end

    ulx5m_cfg_autoboot_25 #(.STARTUP_BITS(6)) dut (
        .clk25(clk25), .normal_mode(normal_mode),
        .release_spi(release_spi)
    );

    always @(posedge clk25) begin
        cycles = cycles + 1;
        if (dut.cfg_en && !prev_en)
            first_en_cycle = cycles;
        if (dut.cfg_valid) begin
            if (!dut.cfg_en || !release_spi)
                $fatal(1, "byte without EN and SPI release");
            if (bytes_seen >= 27 || dut.cfg_data !== expected[bytes_seen])
                $fatal(1, "bad command byte %0d", bytes_seen);
            if (bytes_seen > 0 && cycles - last_valid_cycle < 2)
                $fatal(1, "no idle cycle between bytes");
            if (bytes_seen == 0 && cycles - first_en_cycle < 3)
                $fatal(1, "EN lead too short");
            last_valid_cycle = cycles;
            bytes_seen = bytes_seen + 1;
        end
        if (prev_en && !dut.cfg_en) begin
            if (bytes_seen != 27 || cycles - last_valid_cycle < 9)
                $fatal(1, "EN tail too short");
            last_valid_end = cycles;
        end
        if (dut.cfg_recfg && first_recfg_cycle < 0) begin
            first_recfg_cycle = cycles;
            if (bytes_seen != 27 || dut.cfg_en || dut.cfg_valid ||
                last_valid_end < 0 || cycles - last_valid_end < 16)
                $fatal(1, "RECFG without full, settled command");
        end
        prev_en = dut.cfg_en;
        prev_valid = dut.cfg_valid;
    end

    initial begin
        $readmemh("build-ulx5m-gs/bootloader/cmd.hex", expected);
        repeat (100) @(negedge clk25);
        if (release_spi || bytes_seen || dut.cfg_recfg)
            $fatal(1, "DFU mode caused SPI release or configuration");
        @(negedge clk48);
        normal_mode = 1'b1;
        wait (bytes_seen == 18);
        // Model complete 48 MHz clock loss during the CHG_STATUS packet.
        run_pll = 1'b0;
        normal_mode = 1'b0;
        wait (first_recfg_cycle >= 0);
        repeat (4) @(negedge clk25);
        if (bytes_seen != 27 || !release_spi)
            $fatal(1, "configuration did not finish on reference clock");
        $display("[PASS] independent 25 MHz CMD/RECFG; DFU quiet; PLL stopped after byte 18");
        $finish;
    end
    initial begin
        #25000;
        $fatal(1, "25 MHz autoboot timeout");
    end
endmodule
`default_nettype wire
