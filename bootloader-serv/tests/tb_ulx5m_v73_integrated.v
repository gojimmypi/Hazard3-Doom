`timescale 1ns/1ps
`default_nettype none
module CC_CFG_CTRL (
    input wire CLK, EN, VALID, RECFG,
    input wire [7:0] DATA
);
    // GateMate configuration primitive stub: observations made in test top.
endmodule

module tb_ulx5m_v73_integrated;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1;
    reg normal_mode = 0;
    reg spi_idle = 1;
    reg [2:0] bus_addr = 0;
    reg [31:0] bus_wdata = 0;
    reg bus_cyc = 0;
    reg bus_we = 0;
    wire [31:0] bus_rdata;
    wire bus_ack, release_spi;
    integer cycles = 0, nbytes = 0, lead = 0, since_valid = 100;
    integer tail = 0, quiet = 0, first_valid = -1, last_valid = -1;
    integer first_en = -1, first_release = -1, first_recfg = -1;
    reg en_was_high = 0;
    reg [7:0] expected [0:26];
    reg recfg_seen = 0;

    ulx5m_spi_active_reboot_wb dut (
        .clk(clk), .rst(rst), .normal_mode(normal_mode), .spi_idle(spi_idle),
        .bus_addr(bus_addr), .bus_wdata(bus_wdata), .bus_rdata(bus_rdata),
        .bus_cyc(bus_cyc), .bus_we(bus_we), .bus_ack(bus_ack),
        .release_spi(release_spi)
    );

    task send_write(input [2:0] addr, input [31:0] value);
        begin
            @(negedge clk);
            bus_addr = addr; bus_wdata = value; bus_we = 1; bus_cyc = 1;
            @(negedge clk);
            bus_cyc = 0; bus_we = 0;
            repeat (3) @(negedge clk);
        end
    endtask

    always @(posedge clk) begin
        cycles = cycles + 1;
        if (release_spi && first_release == -1)
            first_release = cycles;
        if (dut.cfg_en && first_en == -1)
            first_en = cycles;
        if (dut.cfg_en && !en_was_high)
            lead = cycles;
        if (dut.cfg_valid) begin
            if (!dut.cfg_en) $fatal(1, "VALID without EN");
            if (nbytes >= 27) $fatal(1, "too many config bytes");
            if (nbytes != 0 && cycles - last_valid < 4)
                $fatal(1, "missing interbyte idle");
            if (nbytes == 0) first_valid = cycles;
            if (dut.cfg_data !== expected[nbytes])
                $fatal(1, "byte %0d mismatch %02x vs %02x", nbytes, dut.cfg_data, expected[nbytes]);
            nbytes = nbytes + 1;
            last_valid = cycles;
        end
        if (en_was_high && !dut.cfg_en)
            tail = cycles - last_valid - 1;
        if (dut.recfg && !recfg_seen) begin
            recfg_seen = 1;
            first_recfg = cycles;
            if (nbytes != 27) $fatal(1, "RECFG before last command byte");
            if (dut.cfg_en || dut.cfg_valid) $fatal(1, "RECFG with EN or VALID");
        end
        en_was_high = dut.cfg_en;
    end

    initial begin
        $readmemh("build-ulx5m-gs/v73-normal-boot-dfu-hw-native/cmd.hex", expected);
        repeat (4) @(negedge clk);
        rst = 0;
        // DFU mode must never authorize a boot, even on valid ARM/BOOT.
        send_write(3'd1, 32'h41524d31);
        send_write(3'd2, 32'h424f4f54);
        repeat (50) @(negedge clk);
        if (release_spi || dut.recfg || dut.cfg_en)
            $fatal(1, "DFU selected but started secondary handoff");
        normal_mode = 1;
        repeat (38) @(negedge clk);
        send_write(3'd1, 32'h41524d31);
        if (!dut.armed) $fatal(1, "ARM not accepted");
        send_write(3'd2, 32'h424f4f54);
        if (!release_spi || !dut.fired) $fatal(1, "BOOT not accepted");
        repeat (360) @(negedge clk);
        if (!recfg_seen || nbytes != 27) $fatal(1, "configuration not completed");
        if (first_en - first_release < 64) $fatal(1, "SPI pad release gap too short");
        if (first_valid - first_en < 8) $fatal(1, "EN lead gap too short");
        if (tail < 16) $fatal(1, "EN tail too short: %0d", tail);
        if (first_recfg - (last_valid + tail + 1) < 32)
            $fatal(1, "post-EN quiet gap too short");
        $display("[PASS] v73 DFU gate, ARM/BOOT, 27 bytes, release, lead, gap, tail, settle, RECFG");
        $display("[PASS] v75a single-clock paced command stream: 64/8/3/16/32");
        $finish;
    end
endmodule
`default_nettype wire
