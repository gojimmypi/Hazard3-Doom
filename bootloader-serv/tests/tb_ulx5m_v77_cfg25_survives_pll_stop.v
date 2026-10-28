`timescale 1ns/1ps
`default_nettype none
module CC_CFG_CTRL (
    input wire CLK, EN, VALID, RECFG,
    input wire [7:0] DATA
);
endmodule

module tb_ulx5m_v77_cfg25_survives_pll_stop;
    reg clk48 = 1'b0;
    reg cfg_clk = 1'b0;
    reg run_clk48 = 1'b1;
    always #20 cfg_clk = ~cfg_clk;
    always begin
        #10.416;
        if (run_clk48)
            clk48 = ~clk48;
    end
    reg rst = 1'b1;
    reg normal_mode = 1'b0;
    reg spi_idle = 1'b1;
    wire [31:0] bus_rdata;
    wire bus_ack, release_spi;
    reg [7:0] expected [0:26];
    integer nbytes = 0;
    integer cfg_cycles = 0;
    integer prev_valid = -100;
    reg stopped_pll = 1'b0;

    ulx5m_spi_active_reboot_wb dut (
        .clk(clk48), .cfg_clk(cfg_clk), .rst(rst),
        .normal_mode(normal_mode), .spi_idle(spi_idle),
        .bus_addr(3'b0), .bus_wdata(32'b0),
        .bus_rdata(bus_rdata), .bus_cyc(1'b0),
        .bus_we(1'b0), .bus_ack(bus_ack),
        .release_spi(release_spi)
    );

    always @(posedge cfg_clk) begin
        cfg_cycles = cfg_cycles + 1;
        if (dut.cfg_valid) begin
            if (!dut.cfg_en) $fatal(1, "VALID without EN");
            if (nbytes >= 27) $fatal(1, "too many bytes");
            if (cfg_cycles - prev_valid < 4)
                $fatal(1, "missing interbyte idle clock");
            if (dut.cfg_data !== expected[nbytes])
                $fatal(1, "config byte mismatch: %0d", nbytes);
            nbytes = nbytes + 1;
            prev_valid = cfg_cycles;
        end
    end

    initial begin
        $readmemh("build-ulx5m-gs/v73-normal-boot-dfu-hw-native/cmd.hex", expected);
        repeat (10) @(negedge cfg_clk);
        rst = 1'b0;
        // While in BTN2 DFU mode, the independent oscillator must NOT boot.
        repeat (40) @(negedge cfg_clk);
        if (nbytes || dut.cfg_en || dut.recfg)
            $fatal(1, "DFU mode incorrectly triggered configuration");
        @(negedge clk48);
        normal_mode = 1'b1;
        wait (nbytes == 18);
        // The CHG_STATUS packet is 18 bytes. Drop PLL0 before the nine
        // trailing sync/idle bytes or the final RECFG request.
        run_clk48 = 1'b0;
        stopped_pll = 1'b1;
        repeat (100) @(negedge cfg_clk);
        if (!stopped_pll || !dut.recfg || dut.cfg_en || dut.cfg_valid)
            $fatal(1, "config did not reach RECFG after PLL clock stopped");
        if (nbytes != 27)
            $fatal(1, "incorrect config byte count");
        $display("[PASS] v77: DFU isolated, 27 bytes, PLL48 stopped, CFG25 still asserted RECFG");
        $finish;
    end
    initial begin
        #50000;
        $fatal(1, "v77 configuration timeout");
    end
endmodule
`default_nettype wire
