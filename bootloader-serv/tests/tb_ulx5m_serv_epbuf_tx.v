/*
 * Exercise the actual USB endpoint buffer RAM feeding the packet TX engine.
 *
 * This reproduces usb_trans's TX prefetch and address increments:
 *   buf_tx_rden_0 = txpkt_start_i | txpkt_data_ack;
 *   addr_inc      = txpkt_start_i | txpkt_data_ack;
 * The start pulse is the registered txpkt_start_i, so the synchronous
 * 32-bit-write / 8-bit-read RAM must supply each requested byte in time.
 *
 * TX pad signals are sampled after the extra GateMate output/OE register.
 * It does not model the analog CC_IOBUF pad or the complete microcode FSM.
 */
`timescale 1ns/1ps
`default_nettype none
module tb_ulx5m_serv_epbuf_tx;
    reg clk = 1'b0;
    always #10.417 clk = ~clk;
    reg rst = 1'b1;

    reg [8:0] ep_wr_addr = 0;
    reg [31:0] ep_wr_data = 0;
    reg ep_wr_en = 0;
    reg [10:0] tx_rd_addr = 0;
    reg pkt_start = 0;
    reg [3:0] pkt_pid = 4'h3;
    reg [9:0] pkt_len = 0;
    wire [7:0] pkt_data;
    wire pkt_data_ack, pkt_done;
    wire ll_start, ll_bit, ll_last, ll_ack;
    wire tx_dp, tx_dn, tx_en;
    reg pad_dp = 1'b1;
    reg pad_dn = 1'b0;
    reg pad_en = 1'b0;
    integer bytes_consumed = 0;

    usb_ep_buf #(.TARGET("GATEMATE"), .RWIDTH(8), .WWIDTH(32)) tx_ram (
        .rd_addr_0(tx_rd_addr), .rd_data_1(pkt_data),
        .rd_en_0(pkt_start | pkt_data_ack), .rd_clk(clk),
        .wr_addr_0(ep_wr_addr), .wr_data_0(ep_wr_data),
        .wr_en_0(ep_wr_en), .wr_clk(clk)
    );

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

    // usb_trans increments the read address on the prefetch and every
    // completed DATA byte; both happen at the clock edge of the read.
    always @(posedge clk) begin
        if (pkt_start) begin
            tx_rd_addr <= tx_rd_addr + 1'b1;
            bytes_consumed <= 0;
        end else if (pkt_data_ack) begin
            tx_rd_addr <= tx_rd_addr + 1'b1;
            bytes_consumed <= bytes_consumed + 1;
        end
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

    // Adversarial data: zeros, ones, and nontrivial CRC/bitstuff cases.
    function [7:0] payload_byte;
        input integer which;
        input integer idx;
        integer value;
        begin
            value = (idx * 29 + 7 + 17 * which) & 255;
            if ((idx % 11) == 0)
                value = 255;
            if ((idx % 13) == 1)
                value = 0;
            payload_byte = value[7:0];
        end
    endfunction

    task write_payload;
        input integer which;
        input integer length;
        input integer base;
        integer i, lane;
        reg [31:0] word;
        begin
            if ((base % 4) != 0)
                $fatal(1, "Expected word-aligned EP RAM base");
            for (i = 0; i < (length + 3) / 4; i = i + 1) begin
                word = 32'h5a3cc35a;
                for (lane = 0; lane < 4; lane = lane + 1)
                    if (4*i + lane < length)
                        word[8*lane +: 8] = payload_byte(which, 4*i + lane);
                @(negedge clk);
                ep_wr_addr = (base / 4) + i;
                ep_wr_data = word;
                ep_wr_en = 1'b1;
                @(negedge clk);
                ep_wr_en = 1'b0;
            end
            repeat (3) @(negedge clk);
        end
    endtask

    integer fd;
    integer cycle = 0;
    integer packet_index = -1;
    always @(negedge clk) begin
        cycle = cycle + 1;
        if (packet_index >= 0) begin
            $fdisplay(fd, "%0d,%0d,%0d,%0d,%0d", packet_index,
                      cycle, pad_en, pad_dp, pad_dn);
            // While EOP is still driven, the idle packet engine must
            // not leak an X onto the low-level bit-stuffing input.
            if (pad_en && (tx_pkt.state == 4'd0) &&
                (ll_bit !== 1'b0) && (ll_bit !== 1'b1))
                $fatal(1, "Packet %0d has unknown ll_bit during EOP", packet_index);
            if (pad_en && pkt_done && (ll_last !== 1'b0))
                $fatal(1, "Packet %0d held ll_last after final ACK", packet_index);
        end
    end

    task send_packet;
        input integer which;
        input integer length;
        input integer base;
        integer waits;
        begin
            write_payload(which, length, base);
            @(negedge clk);
            pkt_pid = (which % 2) ? 4'hb : 4'h3;
            pkt_len = length;
            tx_rd_addr = base;
            packet_index = which;
            pkt_start = 1'b1;
            @(negedge clk);
            pkt_start = 1'b0;
            waits = 0;
            while (!pkt_done && waits < 10000) begin
                @(negedge clk);
                waits = waits + 1;
            end
            if (!pkt_done)
                $fatal(1, "Packet %0d TX stalled", which);
            waits = 0;
            while (pad_en && waits < 100) begin
                @(negedge clk);
                waits = waits + 1;
            end
            if (pad_en) begin
                $display("[DEBUG] Packet %0d length=%0d base=%0d time=%0t waited=%0d",
                         which, length, base, $time, waits);
                $display("[DEBUG] PAD: en=%b dp=%b dn=%b; PHY: en=%b dp=%b dn=%b",
                         pad_en, pad_dp, pad_dn, tx_en, tx_dp, tx_dn);
                $display("[DEBUG] TX_LL: state=%b active=%b out_active=%b",
                         tx_ll.state, tx_ll.active, tx_ll.out_active);
                $display("[DEBUG] TX_LL: br_cnt=%b br_now=%b bs_cnt=%b bs_now=%b",
                         tx_ll.br_cnt, tx_ll.br_now, tx_ll.bs_cnt, tx_ll.bs_now);
                $display("[DEBUG] TX_LL: ll_ack=%b ll_last=%b ll_bit=%b",
                         ll_ack, ll_last, ll_bit);
                $display("[DEBUG] TX_PKT: state=%0d next=%0d shift_bit=%b",
                         tx_pkt.state, tx_pkt.state_nxt, tx_pkt.shift_bit);
                $display("[DEBUG] TX_PKT: shift_data=%02x last_byte=%b",
                         tx_pkt.shift_data, tx_pkt.shift_last_byte);
                $display("[DEBUG] TX_PKT: len=%0d pkt_done=%b data_ack=%b",
                         tx_pkt.len, pkt_done, pkt_data_ack);
                $display("[DEBUG] EP_RAM: rd_addr=%0d data=%02x bytes_consumed=%0d",
                         tx_rd_addr, pkt_data, bytes_consumed);
                $fatal(1, "Packet %0d never released output", which);
            end
            repeat (12) @(negedge clk);
            packet_index = -1;
            if (bytes_consumed !== length)
                $fatal(1, "Packet %0d consumed %0d bytes, wanted %0d",
                       which, bytes_consumed, length);
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build-ulx5m-gs/flash-serv-epbuf-tx-debug.vcd");
            $dumpvars(0, tb_ulx5m_serv_epbuf_tx);
            $display("[INFO] Writing debug VCD: build-ulx5m-gs/flash-serv-epbuf-tx-debug.vcd");
        end
        fd = $fopen("build-ulx5m-gs/flash-serv-epbuf-tx-waveform.csv", "w");
        if (!fd)
            $fatal(1, "Could not open endpoint buffer TX waveform");
        $fdisplay(fd, "packet,cycle,en,dp,dn");
        repeat (12) @(negedge clk);
        rst = 1'b0;
        repeat (12) @(negedge clk);
        // Repeatedly rewrite EP0's address-zero buffer, plus nonzero offsets.
        if ($test$plusargs("only_packet2")) begin
            $display("[INFO] Isolated packet 2 test after reset");
            send_packet(2, 18, 0);
            $fclose(fd);
            $display("[PASS] Isolated packet 2 completed (waveform decoder not run)");
            $finish;
        end
        send_packet(0, 8,   0);
        send_packet(1, 16,  0);
        send_packet(2, 18,  0);
        send_packet(3, 64,  64);
        send_packet(4, 18, 128);
        send_packet(5, 8,  64);
        send_packet(6, 18,  0);
        send_packet(7, 0,   0);
        $fclose(fd);
        $display("[PASS] EP RAM 32-bit writes -> byte-prefetch TX, 8 packets");
        $finish;
    end
endmodule
`default_nettype wire
