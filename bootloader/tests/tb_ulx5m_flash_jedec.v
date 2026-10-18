/* Standalone flash JEDEC reader: SPI mode 0 and LED byte-select smoke test. */
`timescale 1ns/1ps
`default_nettype none
module tb_ulx5m_flash_jedec;
    reg clk = 1'b0;
    always #20 clk = ~clk;  // 25 MHz
    reg rst = 1'b1;
    reg btn_next_n = 1'b1;
    reg btn_index_n = 1'b1;
    reg miso = 1'b1;
    wire sck, cs_n, mosi, done;
    wire [7:0] display;
    wire [23:0] jedec_id;
    wire [1:0] byte_index;
    localparam [23:0] TEST_ID = 24'h5ac37e;
    integer edge_count = 0;
    reg [7:0] sent_cmd = 8'h00;

    ulx5m_flash_jedec_reader #(
        .STARTUP_BITS(4), .BTN_SAMPLE_BITS(4)
    ) dut (
        .clk(clk), .rst(rst), .btn_next_n(btn_next_n),
        .btn_index_n(btn_index_n),
        .miso(miso), .sck(sck), .cs_n(cs_n), .mosi(mosi),
        .display(display), .done(done), .jedec_id(jedec_id),
        .byte_index(byte_index)
    );

    // A serial-only JEDEC-ID flash model. Data is presented after the 0x9f
    // opcode and is stable before the next rising SCK edge.
    always @(posedge sck) begin
        if (cs_n)
            $fatal(1, "[FAIL] SPI clock while CS is inactive");
        if (edge_count < 8)
            sent_cmd = {sent_cmd[6:0], mosi};
        edge_count = edge_count + 1;
        if (edge_count > 32)
            $fatal(1, "[FAIL] additional SCK edges");
    end
    always @(negedge sck) begin
        if (!cs_n && edge_count >= 8 && edge_count < 32)
            miso = TEST_ID[23-(edge_count-8)];
    end

    initial begin
        repeat (4) @(negedge clk);
        rst = 1'b0;
        wait(done);
        #1;
        if (edge_count !== 32 || sent_cmd !== 8'h9f)
            $fatal(1, "[FAIL] SPI command: edges=%0d command=%02x", edge_count, sent_cmd);
        if (!cs_n || sck)
            $fatal(1, "[FAIL] SPI bus not idle after read");
        if (jedec_id !== TEST_ID || display !== 8'h5a)
            $fatal(1, "[FAIL] JEDEC ID: got %06x display %02x", jedec_id, display);

        btn_index_n = 1'b0;
        #1;
        if (display !== 8'h81)
            $fatal(1, "[FAIL] index display 0");
        btn_index_n = 1'b1;
        btn_next_n = 1'b0;
        repeat (80) @(negedge clk);
        if (byte_index !== 1 || display !== 8'hc3)
            $fatal(1, "[FAIL] second JEDEC byte");
        btn_next_n = 1'b1;
        repeat (80) @(negedge clk);
        btn_next_n = 1'b0;
        repeat (80) @(negedge clk);
        if (byte_index !== 2 || display !== 8'h7e)
            $fatal(1, "[FAIL] third JEDEC byte");
        btn_index_n = 1'b0;
        #1;
        if (display !== 8'h84)
            $fatal(1, "[FAIL] index display 2");
        $display("[PASS] SPI 0x9f, 24-bit JEDEC read, 32 clocks, CS idle");
        $display("[PASS] manual LED byte selection and index indication");
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "[FAIL] SPI JEDEC test timeout");
    end
endmodule
`default_nettype wire
