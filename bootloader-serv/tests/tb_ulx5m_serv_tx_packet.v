/*
 * Independent USB DATA transmitter waveform test.
 * Runs real usb_tx_pkt and usb_tx_ll, including the extra registered
 * GateMate output and tristate stage. No receiver or host ACK is forced.
 * Samples pad-level signals at 48 MHz for external CRC/bitstuff decoding.
 */
`timescale 1ns/1ps
`default_nettype none
module tb_ulx5m_serv_tx_packet;
    reg clk = 1'b0;
    always #10.417 clk = ~clk;
    reg rst = 1'b1;
    reg pkt_start = 1'b0;
    reg [3:0] pkt_pid = 4'h3;
    reg [9:0] pkt_len = 0;
    reg [7:0] pkt_bytes [0:63];
    integer data_index = 0;
    wire [7:0] pkt_data = pkt_bytes[data_index];
    wire pkt_data_ack, pkt_done;
    wire ll_start, ll_bit, ll_last, ll_ack;
    wire tx_dp, tx_dn, tx_en;
    reg pad_dp = 1'b1;
    reg pad_dn = 1'b0;
    reg pad_en = 1'b0;

    usb_tx_pkt tx_pkt (
        .ll_start(ll_start), .ll_bit(ll_bit), .ll_last(ll_last),
        .ll_ack(ll_ack), .pkt_start(pkt_start), .pkt_done(pkt_done),
        .pkt_pid(pkt_pid), .pkt_len(pkt_len),
        .pkt_data(pkt_data), .pkt_data_ack(pkt_data_ack),
        .clk(clk), .rst(rst)
    );
    usb_tx_ll tx_ll (
        .phy_tx_dp(tx_dp), .phy_tx_dn(tx_dn), .phy_tx_en(tx_en),
        .ll_start(ll_start), .ll_bit(ll_bit), .ll_last(ll_last),
        .ll_ack(ll_ack), .clk(clk), .rst(rst)
    );

    // GateMate usb_phy: register both output data and active-low OE.
    // This models the digital boundary, not analog rise/fall or CC_IOBUF.
    always @(posedge clk) begin
        if (rst) begin
            pad_dp <= 1'b0;
            pad_dn <= 1'b0;
            pad_en <= 1'b0;
        end else begin
            pad_dp <= tx_dp;
            pad_dn <= tx_dn;
            pad_en <= tx_en;
        end
    end

    always @(posedge clk) begin
        if (pkt_start)
            data_index <= 0;
        else if (pkt_data_ack)
            data_index <= data_index + 1;
    end

    integer fd;
    integer cycle = 0;
    integer sample_packet = -1;
    always @(negedge clk) begin
        cycle = cycle + 1;
        if (sample_packet >= 0)
            $fdisplay(fd, "%0d,%0d,%0d,%0d,%0d", sample_packet,
                      cycle, pad_en, pad_dp, pad_dn);
    end

    task send_data;
        input integer which;
        input integer length;
        input [3:0] pid;
        integer wait_cycles;
        begin
            @(negedge clk);
            pkt_pid = pid;
            pkt_len = length;
            sample_packet = which;
            pkt_start = 1'b1;
            @(negedge clk);
            pkt_start = 1'b0;
            wait_cycles = 0;
            while (!pkt_done && wait_cycles < 10000) begin
                @(negedge clk);
                wait_cycles = wait_cycles + 1;
            end
            if (!pkt_done)
                $fatal(1, "TX packet %0d stalled", which);
            // pkt_done is earlier than the physical EOP/tristate release.
            wait_cycles = 0;
            while (pad_en && wait_cycles < 100) begin
                @(negedge clk);
                wait_cycles = wait_cycles + 1;
            end
            if (pad_en)
                $fatal(1, "TX packet %0d never released pad", which);
            repeat (12) @(negedge clk);
            sample_packet = -1;
            if (data_index !== length)
                $fatal(1, "TX packet %0d consumed %0d bytes, expected %0d",
                       which, data_index, length);
        end
    endtask

    integer i;
    initial begin
        fd = $fopen("build-ulx5m-gs/flash-serv-tx-waveform.csv", "w");
        if (fd == 0)
            $fatal(1, "Failed to open TX waveform output");
        $fdisplay(fd, "packet,cycle,en,dp,dn");
        for (i = 0; i < 64; i = i + 1) begin
            pkt_bytes[i] = (i * 29 + 7) & 8'hff;
            if ((i % 11) == 0)
                pkt_bytes[i] = 8'hff;
            if ((i % 13) == 1)
                pkt_bytes[i] = 8'h00;
        end
        repeat (12) @(negedge clk);
        rst = 1'b0;
        repeat (16) @(negedge clk);
        send_data(0, 0, 4'h3);   // ZLP, DATA0
        send_data(1, 8, 4'hb);   // DATA1
        send_data(2, 16, 4'h3);  // DATA0
        send_data(3, 18, 4'hb);  // DATA1, descriptor length
        send_data(4, 27, 4'h3);  // DATA0, descriptor length
        send_data(5, 64, 4'hb);  // max packet size
        $fclose(fd);
        $display("[INFO] Recorded six real TX packets and GateMate register latency");
        $finish;
    end
endmodule
`default_nettype wire
