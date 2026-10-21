`timescale 1ns/1ps
module tb_ulx5m_serv_raw_capture;
    reg clk = 0;
    always #10 clk = ~clk;
    reg rst = 1;
    reg arm = 0;
    reg tx_data_pending = 0;
    reg tx_en = 0;
    reg tx_en_pad_d = 0;
    reg rx_hold = 0;
    reg [1:0] raw_dp = 2'b10;
    reg [1:0] raw_dn = 2'b01;
    reg rx_change = 1;
    reg rx_sync = 0;
    reg ack_valid = 0;
    reg ack_timeout = 0;
    reg rd_en = 0;
    reg [6:0] rd_addr = 0;
    wire [15:0] rd_data;
    wire [15:0] status, sample_count;

    usb_ep0_raw_capture dut (
        .clk(clk), .rst(rst), .arm(arm),
        .tx_data_pending(tx_data_pending), .tx_en(tx_en),
        .tx_en_pad_d(tx_en_pad_d), .rx_hold(rx_hold),
        .raw_dp(raw_dp), .raw_dn(raw_dn),
        .rx_change(rx_change), .rx_sync(rx_sync),
        .ack_valid(ack_valid), .ack_timeout(ack_timeout),
        .rd_en(rd_en), .rd_addr(rd_addr), .rd_data(rd_data),
        .status(status), .sample_count(sample_count)
    );

    task tick;
        begin @(posedge clk); #1; end
    endtask
    task tx_pulse;
        begin
            tx_data_pending = 1;
            tx_en = 1;
            repeat (5) tick();
            @(negedge clk); tx_en = 0;
            tick();
        end
    endtask
    initial begin
        repeat (3) tick();
        @(negedge clk); rst = 0;
        tx_pulse();
        repeat (12) tick();
        @(negedge clk); ack_valid = 1;
        tick();
        @(negedge clk); ack_valid = 0;
        if (status[3] || sample_count != 0)
            $fatal(1, "valid ACK should discard the capture");
        @(negedge clk); tx_data_pending = 0;
        repeat (3) tick();
        tx_pulse();
        repeat (12) tick();
        @(negedge clk); ack_timeout = 1;
        tick();
        @(negedge clk); ack_timeout = 0;
        if (!status[3] || sample_count == 0)
            $fatal(1, "timeout should freeze the capture");
        @(negedge clk); rd_en = 1;
        tick();
        @(negedge clk); rd_en = 0;
        if (rd_data !== 16'h9898)
            $fatal(1, "sample packing mismatch, got %h", rd_data);
        tx_pulse();
        repeat (8) tick();
        if (!status[3])
            $fatal(1, "frozen capture changed without rearm");
        @(negedge clk); arm = 1;
        tick();
        @(negedge clk); arm = 0;
        if (status[3] || sample_count != 0)
            $fatal(1, "rearm did not clear capture status");
        $display("[PASS] raw capture: ACK discard, timeout freeze, packing, readback, rearm");
        $finish;
    end
endmodule
