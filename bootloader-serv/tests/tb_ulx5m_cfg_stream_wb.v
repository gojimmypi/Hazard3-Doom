`timescale 1ns/1ps
`default_nettype none
module CC_CFG_CTRL (
    input wire [7:0] DATA,
    input wire CLK, EN, RECFG, VALID
);
endmodule

module tb_ulx5m_cfg_stream_wb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1;
    reg normal_mode = 0;
    reg spi_idle = 1;
    reg [2:0] bus_addr = 0;
    reg [31:0] bus_wdata = 0;
    reg bus_cyc = 0, bus_we = 0;
    wire [31:0] bus_rdata;
    wire bus_ack;
    integer pulses = 0, en_cycles = 0, off_cycles = 0;
    integer cycles_since_valid = 100;
    reg [7:0] expected [0:2];
    ulx5m_cfg_stream_wb dut (
        .clk(clk), .rst(rst), .normal_mode(normal_mode),
        .spi_idle(spi_idle), .bus_addr(bus_addr),
        .bus_wdata(bus_wdata), .bus_rdata(bus_rdata),
        .bus_cyc(bus_cyc), .bus_ack(bus_ack), .bus_we(bus_we)
    );
    always @(posedge clk) begin
        if (dut.en)
            en_cycles = en_cycles + 1;
        else
            off_cycles = off_cycles + 1;
        if (dut.valid) begin
            if (!dut.en || pulses >= 3 ||
                dut.data !== expected[pulses] ||
                (pulses == 0 && en_cycles < 3) ||
                (pulses > 0 && cycles_since_valid < 2)) begin
                $display("[FAIL] Invalid byte sequence/spacing pulse=%0d", pulses);
                $fatal(1);
            end
            pulses = pulses + 1;
            cycles_since_valid = 0;
        end else
            cycles_since_valid = cycles_since_valid + 1;
    end
    task write_reg(input [2:0] addr, input [31:0] value);
    begin
        @(negedge clk);
        bus_addr = addr; bus_wdata = value; bus_we = 1; bus_cyc = 1;
        @(posedge clk); #1;
        if (!bus_ack) $fatal(1, "Missing WB acknowledge");
        @(negedge clk);
        bus_cyc = 0; bus_we = 0;
        @(posedge clk);
    end
    endtask
    task read_reg(input [2:0] addr, input [31:0] expected_data);
    begin
        @(negedge clk);
        bus_addr = addr; bus_we = 0; bus_cyc = 1;
        @(posedge clk); #1;
        if (!bus_ack || bus_rdata !== expected_data)
            $fatal(1, "Wishbone read mismatch addr=%0d got=%h expected=%h",
                   addr, bus_rdata, expected_data);
        @(negedge clk);
        bus_cyc = 0;
        @(posedge clk);
    end
    endtask
    task wait_ready;
        integer n;
    begin
        n = 0;
        while ((dut.state != 3'd2 || dut.idle_cycles < 3) && n < 100) begin
            @(posedge clk); n = n + 1;
        end
        if (n == 100) $fatal(1, "Controller READY timeout");
    end
    endtask
    initial begin
        expected[0] = 8'hd9;
        expected[1] = 8'h01;
        expected[2] = 8'hed;
        repeat (5) @(posedge clk);
        @(negedge clk); rst=0; normal_mode=1;
        repeat (5) @(posedge clk);
        write_reg(1, 3);
        write_reg(2, 32'h43464731);
`ifndef ULX5M_ENABLE_CFG_STREAM
        if (dut.state != 3'd7 || dut.en || dut.valid)
            $fatal(1, "Default build must reject configuration arm");
        read_reg(0, 32'h00000008);
        read_reg(1, 32'h00000000);
        read_reg(2, 32'h00000000);
        write_reg(3, 32'h000000d9);
        if (dut.state != 3'd7 || dut.en || dut.valid || pulses != 0)
            $fatal(1, "Disabled stream accepted a payload byte");
        @(negedge clk); normal_mode = 0;
        repeat (3) @(posedge clk);
        if (dut.state != 3'd0 || dut.en || dut.valid)
            $fatal(1, "Mode withdrawal did not clear disabled error");
        @(negedge clk); normal_mode = 1;
        repeat (3) @(posedge clk);
        read_reg(0, 32'h00000000);
        $display("[PASS] Disabled configuration responder rejects writes and resets");
        $display("[PASS] Non-reconfig build rejects every arm");
`else
        wait_ready();
        write_reg(3, expected[0]);
        wait_ready();
        write_reg(3, expected[1]);
        wait_ready();
        write_reg(3, expected[2]);
        wait_ready();
        write_reg(2, 32'h454e4431);
        repeat (15) @(posedge clk);
        if (dut.state != 3'd6 || dut.en || pulses != 3)
            $fatal(1, "Invalid stream completion");
        $display("[PASS] CC_CFG_CTRL 3-byte lead/gap/tail model");
        @(negedge clk); normal_mode=0;
        repeat (3) @(posedge clk);
        if (dut.en || dut.valid || dut.state != 0)
            $fatal(1, "Normal-mode withdrawal must reset stream");
        $display("[PASS] Mode withdrawal resets stream controller");
        @(negedge clk); normal_mode=1;
        repeat (5) @(posedge clk);
        write_reg(1, 2);
        write_reg(2, 32'h43464731);
        wait_ready();
        // A flash read while EN is high is expected: firmware fills its
        // next 256-byte buffer between configuration byte pulses.
        @(negedge clk); spi_idle=0;
        repeat (6) @(posedge clk);
        #1;
        if (dut.state != 3'd2 || !dut.en || dut.valid || pulses != 3)
            $fatal(1, "SPI read between bytes aborted active controller");
        @(negedge clk); spi_idle=1;
        repeat (5) @(posedge clk);
        #1;
        if (dut.state != 3'd2 || !dut.en)
            $fatal(1, "Controller did not recover from flash-read gap");
        $display("[PASS] SPI flash read between bytes is permitted");
        // Force a SPI collision after accepting a Wishbone data byte but
        // BEFORE the next clock edge that would raise CFG VALID.
        @(negedge clk);
        bus_addr=3; bus_wdata=32'h000000a5; bus_we=1; bus_cyc=1;
        @(posedge clk); #1;
        if (!bus_ack || dut.state != 3'd3)
            $fatal(1, "Expected PULSE before SPI collision");
        @(negedge clk);
        bus_cyc=0; bus_we=0; spi_idle=0;
        @(posedge clk); #1;
        if (dut.state != 3'd7 || dut.en || dut.valid || pulses != 3)
            $fatal(1, "SPI collision did not stop configuration pulse");
        $display("[PASS] SPI collision before VALID aborts without a pulse");
        @(negedge clk); normal_mode=0; spi_idle=1;
        repeat (3) @(posedge clk);
        #1;
        if (dut.state != 3'd0 || dut.en || dut.valid)
            $fatal(1, "Mode withdrawal did not clear collision error");
        @(negedge clk); normal_mode=1;
        repeat (5) @(posedge clk);
        write_reg(1, 2);
        write_reg(2, 32'h43464731);
        wait_ready();
        write_reg(1, 32'd3); // Cannot alter the length after ARM.
        #1;
        if (dut.state != 3'd7 || dut.en || dut.valid)
            $fatal(1, "Illegal length update left CFG EN asserted");
        $display("[PASS] Invalid write after ARM terminates CFG EN");
`endif
        $finish;
    end
endmodule
`default_nettype wire
