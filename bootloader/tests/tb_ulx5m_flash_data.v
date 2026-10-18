/* Simulate one SPI 0x03 read of flash addresses 0x000000..0x00001f. */
`timescale 1ns/1ps
`default_nettype none
module tb_ulx5m_flash_data;
    reg clk = 1'b0;
    always #20 clk = ~clk;  // 25 MHz
    reg rst = 1'b1;
    reg btn_next_n = 1'b1;
    reg btn_index_n = 1'b1;
    reg miso = 1'b1;
    wire sck, cs_n, mosi, done;
    wire [7:0] display;
    wire [4:0] byte_index;
    reg [7:0] flash_bytes [0:31];
    integer edge_count = 0;
    integer i;
    reg [7:0] opcode = 0;
    reg [23:0] address = 0;
    time last_sck_rise = 0;

    ulx5m_flash_data_reader #(
        .STARTUP_BITS(4), .BTN_SAMPLE_BITS(4)
    ) dut (
        .clk(clk), .rst(rst), .btn_next_n(btn_next_n),
        .btn_index_n(btn_index_n), .miso(miso), .sck(sck),
        .cs_n(cs_n), .mosi(mosi), .display(display), .done(done),
        .byte_index(byte_index)
    );

    initial begin
        for (i = 0; i < 32; i = i + 1)
            flash_bytes[i] = (8'h31 + i * 8'h25);
    end

    // The flash receives 0x03 + 24-bit address, then returns 32 bytes.
    always @(posedge sck) begin
        if (cs_n)
            $fatal(1, "[FAIL] SPI clock with CS high");
        if (edge_count > 0 && $time - last_sck_rise != 160)
            $fatal(1, "[FAIL] unexpected SPI bit period");
        last_sck_rise = $time;
        if (edge_count < 8)
            opcode = {opcode[6:0], mosi};
        else if (edge_count < 32)
            address = {address[22:0], mosi};
        else if (mosi !== 1'b0)
            $fatal(1, "[FAIL] MOSI not low during data read");
        edge_count = edge_count + 1;
        if (edge_count > 288)
            $fatal(1, "[FAIL] too many SPI clocks");
    end
    always @(negedge sck) begin
        if (!cs_n && edge_count >= 32 && edge_count < 288)
            miso = flash_bytes[(edge_count - 32) >> 3]
                               [7 - ((edge_count - 32) & 7)];
    end

    initial begin
        repeat (4) @(negedge clk);
        rst = 1'b0;
        wait(done);
        #1;
        if (edge_count !== 288 || opcode !== 8'h03 || address !== 24'h000000)
            $fatal(1, "[FAIL] SPI command: clocks=%0d cmd=%02x addr=%06x",
                   edge_count, opcode, address);
        if (!cs_n || sck)
            $fatal(1, "[FAIL] SPI bus not idle after read");

        for (i = 0; i < 32; i = i + 1) begin
            if (byte_index !== i || display !== flash_bytes[i])
                $fatal(1, "[FAIL] flash byte[%0d] got %02x expected %02x",
                       i, display, flash_bytes[i]);
            btn_index_n = 1'b0;
            #1;
            if (display !== (8'h80 | i))
                $fatal(1, "[FAIL] byte index [%0d] displayed %02x", i, display);
            btn_index_n = 1'b1;
            btn_next_n = 1'b0;
            repeat (80) @(negedge clk);
            btn_next_n = 1'b1;
            repeat (80) @(negedge clk);
        end
        if (byte_index !== 0 || display !== flash_bytes[0])
            $fatal(1, "[FAIL] index did not wrap after 32 bytes");
        if (edge_count !== 288 || !cs_n || sck)
            $fatal(1, "[FAIL] SPI activity after read completed");

        $display("[PASS] SPI 0x03, 24-bit zero address, 32 bytes, 288 clocks");
        $display("[PASS] 6.25 MHz SCK, byte selection, offset and wrap");
        $display("[PASS] single transaction, no writes, CS idle after read");
        $finish;
    end

    initial begin
        #500000;
        $fatal(1, "[FAIL] SPI flash-data test timeout");
    end
endmodule
`default_nettype wire
