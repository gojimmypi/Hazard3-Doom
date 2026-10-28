`timescale 1ns/1ps
`default_nettype none
module CC_CFG_CTRL (
    input wire CLK, EN, VALID, RECFG,
    input wire [7:0] DATA
);
endmodule

module tb_ulx5m_v78_v72_startup_hold;
    reg clk = 1'b0;
    always #5 clk = ~clk;
    reg rst = 1'b1;
    reg normal_mode = 1'b0;
    reg spi_idle = 1'b1;
    reg [2:0] bus_addr = 3'd0;
    reg [31:0] bus_wdata = 32'd0;
    reg bus_cyc = 1'b0;
    reg bus_we = 1'b0;
    wire [31:0] bus_rdata;
    wire bus_ack, release_spi;
    integer elapsed = 0;
    integer first_release = -1;
    integer first_recfg = -1;
    integer bytes_seen = 0;
    reg [7:0] expected [0:26];

    ulx5m_spi_active_reboot_wb #(.V78_BOOT_DELAY_CYCLES(160)) dut (
        .clk(clk), .rst(rst), .normal_mode(normal_mode), .spi_idle(spi_idle),
        .bus_addr(bus_addr), .bus_wdata(bus_wdata), .bus_rdata(bus_rdata),
        .bus_cyc(bus_cyc), .bus_we(bus_we), .bus_ack(bus_ack),
        .release_spi(release_spi)
    );

    task send_write(input [2:0] addr, input [31:0] value);
        begin
            @(negedge clk);
            bus_addr = addr;
            bus_wdata = value;
            bus_we = 1'b1;
            bus_cyc = 1'b1;
            @(negedge clk);
            bus_cyc = 1'b0;
            bus_we = 1'b0;
        end
    endtask

    always @(posedge clk) begin
        if (normal_mode && !rst) begin
            elapsed = elapsed + 1;
            if (release_spi && first_release < 0)
                first_release = elapsed;
            if (dut.cfg_valid) begin
                if (bytes_seen >= 27)
                    $fatal(1, "too many status command bytes");
                if (dut.cfg_data !== expected[bytes_seen])
                    $fatal(1, "status command byte %0d mismatch", bytes_seen);
                bytes_seen = bytes_seen + 1;
            end
            if (dut.recfg && first_recfg < 0) begin
                first_recfg = elapsed;
                if (bytes_seen != 27 || dut.cfg_en || dut.cfg_valid)
                    $fatal(1, "premature or malformed RECFG");
            end
            if (elapsed < 160 && (release_spi || dut.cfg_en || dut.cfg_valid || dut.recfg))
                $fatal(1, "handoff before the v72-equivalent startup hold");
        end else if (release_spi || dut.cfg_en || dut.cfg_valid || dut.recfg) begin
            $fatal(1, "DFU selection triggered normal configuration");
        end
    end

    initial begin
        $readmemh("build-ulx5m-gs/v73-normal-boot-dfu-hw-native/cmd.hex", expected);
        repeat (5) @(negedge clk);
        rst = 1'b0;
        // BTN2 is held: this must stay in USB DFU indefinitely.
        repeat (200) @(negedge clk);
        if (bytes_seen != 0 || release_spi)
            $fatal(1, "DFU selection unexpectedly ran the handoff");

        // After a cold-start mode selection, exercise firmware's old
        // ARM/BOOT writes. Neither is allowed to bypass the v72 hold.
        normal_mode = 1'b1;
        repeat (50) @(negedge clk);
        send_write(3'd1, 32'h41524d31);
        send_write(3'd2, 32'h424f4f54);
        if (dut.fired || release_spi)
            $fatal(1, "firmware bypassed the autonomous boot delay");

        repeat (480) @(negedge clk);
        if (first_release < 160 || first_recfg <= first_release || bytes_seen != 27)
            $fatal(1, "delayed normal handoff incomplete");
        $display("[PASS] v78 v72-equivalent startup hold; DFU isolated, ARM/BOOT blocked, 27 bytes and RECFG");
        $finish;
    end
endmodule
`default_nettype wire
