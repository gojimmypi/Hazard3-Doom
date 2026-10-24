`timescale 1ns/1ps
`default_nettype none

// Test-only primitive stub. This test observes the actual Wishbone
// controller outputs; it does NOT model GateMate silicon reconfiguration.
module CC_CFG_CTRL (
    input wire [7:0] DATA,
    input wire CLK, EN, RECFG, VALID
);
endmodule

module tb_ulx5m_cfg_stream_payload;
    localparam integer MAX_BYTES = 500000;
    localparam [31:0] ARM_KEY = 32'h43464731;
    localparam [31:0] FINISH_KEY = 32'h454e4431;
    localparam [31:0] ABORT_KEY = 32'h41425431;
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
    reg [7:0] payload [0:MAX_BYTES-1];
    reg [1023:0] hex_path;
    integer size, abort_after, i, received = 0;
    integer en_lead = 0, gap_clocks = 100000;
    integer tail_clocks = 100000;
    reg en_prev = 0;

    ulx5m_cfg_stream_wb dut (
        .clk(clk), .rst(rst), .normal_mode(normal_mode),
        .spi_idle(spi_idle), .bus_addr(bus_addr), .bus_wdata(bus_wdata),
        .bus_rdata(bus_rdata), .bus_cyc(bus_cyc), .bus_we(bus_we),
        .bus_ack(bus_ack)
    );

    always @(posedge clk) begin
        if (dut.en) begin
            if (!en_prev)
                en_lead = 0;
            else
                en_lead = en_lead + 1;
        end
        if (dut.valid) begin
            if (!dut.en || !normal_mode || !spi_idle ||
                received >= size ||
                dut.data !== payload[received] ||
                (received == 0 && en_lead < 3) ||
                (received > 0 && gap_clocks < 2))
                $fatal(1, "Invalid VALID pulse at byte=%0d expected=%02x actual=%02x",
                       received, payload[received], dut.data);
            received = received + 1;
            gap_clocks = 0;
            tail_clocks = 0;
        end else begin
            if (gap_clocks < 100000)
                gap_clocks = gap_clocks + 1;
            if (tail_clocks < 100000)
                tail_clocks = tail_clocks + 1;
        end
        if (!dut.en && en_prev && received > 0 &&
            abort_after == 0 && tail_clocks < 8)
            $fatal(1, "EN withdrawn before eight tail cycles");
        if (dut.en && dut.cfg_i.RECFG !== 1'b1)
            $fatal(1, "GateMate RECFG input is not asserted");
        en_prev = dut.en;
    end

    task write_reg(input [2:0] addr, input [31:0] value);
    begin
        @(negedge clk);
        bus_addr = addr;
        bus_wdata = value;
        bus_we = 1;
        bus_cyc = 1;
        @(posedge clk); #1;
        if (!bus_ack)
            $fatal(1, "Missing Wishbone ACK on write addr=%0d", addr);
        @(negedge clk);
        bus_cyc = 0;
        bus_we = 0;
        @(posedge clk);
    end
    endtask

    task read_reg(input [2:0] addr, output [31:0] result);
    begin
        @(negedge clk);
        bus_addr = addr;
        bus_we = 0;
        bus_cyc = 1;
        @(posedge clk); #1;
        if (!bus_ack)
            $fatal(1, "Missing Wishbone ACK on read addr=%0d", addr);
        result = bus_rdata;
        @(negedge clk);
        bus_cyc = 0;
        @(posedge clk);
    end
    endtask

    task wait_ready;
        integer n;
        reg [31:0] status;
    begin
        status = 0;
        n = 0;
        while ((status & 32'h1) == 0 && n < 50) begin
            read_reg(0, status);
            if ((status & 32'h8) != 0)
                $fatal(1, "CFG controller error while awaiting READY");
            n = n + 1;
        end
        if (n == 50)
            $fatal(1, "CFG controller READY timeout");
    end
    endtask

    reg [31:0] readback;
    initial begin
        if (!$value$plusargs("HEX=%s", hex_path) ||
            !$value$plusargs("SIZE=%d", size))
            $fatal(1, "Need +HEX=path and +SIZE=decimal");
        if (size < 1 || size > MAX_BYTES)
            $fatal(1, "Fixture length out of range");
        abort_after = 0;
        if ($value$plusargs("ABORT_AFTER=%d", abort_after)) begin
            if (abort_after < 1 || abort_after > size)
                $fatal(1, "ABORT_AFTER out of range");
        end
        $readmemh(hex_path, payload, 0, size - 1);
        repeat (5) @(posedge clk);
        @(negedge clk); rst = 0; normal_mode = 1;
        repeat (5) @(posedge clk);
        write_reg(1, size);
        write_reg(2, ARM_KEY);
        wait_ready();
        for (i = 0; i < size; i = i + 1) begin
            // Model a 256-byte flash read in the middle of a stream.
            // EN remains high; VALID must not overlap selected flash.
            if (i != 0 && (i % 256) == 0) begin
                @(negedge clk); spi_idle = 0;
                repeat (6) @(posedge clk);
                #1;
                if (!dut.en || dut.valid || dut.state != 3'd2)
                    $fatal(1, "SPI flash-read gap disturbed controller at %0d", i);
                @(negedge clk); spi_idle = 1;
            end
            wait_ready();
            write_reg(3, {24'd0, payload[i]});
            wait_ready();
            if (received != i + 1)
                $fatal(1, "Missing configuration pulse at byte %0d", i);
            if (abort_after != 0 && received == abort_after) begin
                write_reg(2, ABORT_KEY);
                repeat (4) @(posedge clk);
                #1;
                if (dut.en || dut.valid || dut.state != 3'd7)
                    $fatal(1, "ABORT did not disable configuration");
                read_reg(0, readback);
                if ((readback & 32'h8) == 0)
                    $fatal(1, "Abort error status missing");
                $display("[PASS] %0d bytes accepted; ABORT blocks finish", received);
                @(negedge clk); normal_mode = 0;
                repeat (4) @(posedge clk);
                #1;
                if (dut.en || dut.valid || dut.state != 3'd0)
                    $fatal(1, "Normal-mode withdrawal did not restore IDLE");
                $display("[PASS] Mode withdrawal clears aborted state");
                $finish;
            end
        end
        read_reg(2, readback);
        if (readback !== size)
            $fatal(1, "Sent-count mismatch: %0d vs %0d", readback, size);
        write_reg(2, FINISH_KEY);
        repeat (18) @(posedge clk);
        #1;
        if (received != size || dut.state != 3'd6 || dut.en || dut.valid)
            $fatal(1, "Controller did not finish complete stream");
        read_reg(0, readback);
        if ((readback & 32'h4) == 0 || (readback & 32'h8) != 0)
            $fatal(1, "Done status missing or error set");
        $display("[PASS] Complete %0d-byte GateMate stream via Wishbone controller", size);
        $display("[PASS] EN lead, VALID gaps, SPI idle windows, EN tail");
        $display("[NOTE] Primitive is a stub: no FPGA reconfiguration was simulated");
        $finish;
    end
endmodule
`default_nettype wire
