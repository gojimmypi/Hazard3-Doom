/*
 * Verify the SERV-only EP0 trace CSR read pipeline and ACK latency.
 * Runs with a disconnected PHY; it does not simulate USB packets.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */
`timescale 1ns/1ps
`default_nettype none
module tb_ulx5m_serv_ep0_trace_csr;
    reg clk = 1'b0;
    reg rst = 1'b1;
    always #5 clk = ~clk;

    reg [11:0] bus_addr = 0;
    reg [15:0] bus_din = 0;
    reg bus_cyc = 1'b0;
    reg bus_we = 1'b0;
    wire [15:0] bus_dout;
    wire bus_ack;
    wire [31:0] ep_rx_data;
    wire pad_pu;
    tri1 pad_dp;
    tri0 pad_dn;

    usb #(
        .TARGET("SIM"),
        .EPDW(32),
        .EP0_TRACE(1),
`ifdef ULX5M_RAW_FREE_READ_TEST
        .EP0_RAW_FREE_READ(1),
`endif
        .MC_INIT_FILE("build-ulx5m-gs/usb_trans_mc.hex")
    ) dut (
        .pad_dp(pad_dp), .pad_dn(pad_dn), .pad_pu(pad_pu),
        .ep_tx_addr_0(9'b0), .ep_tx_data_0(32'b0), .ep_tx_we_0(1'b0),
        .ep_rx_addr_0(9'b0), .ep_rx_data_1(ep_rx_data),
        .ep_rx_re_0(1'b0), .ep_clk(clk),
        .bus_addr(bus_addr), .bus_din(bus_din), .bus_dout(bus_dout),
        .bus_cyc(bus_cyc), .bus_we(bus_we), .bus_ack(bus_ack),
        .irq(), .sof(), .clk(clk), .rst(rst)
    );

    task read_word;
        input [11:0] address;
        input [15:0] expected;
        input integer expected_cycles;
        input [15:0] mask;
        integer cycles;
        begin
            @(negedge clk);
            bus_addr = address;
            bus_cyc = 1'b1;
            bus_we = 1'b0;
            cycles = 0;
            while (!bus_ack && cycles < 6) begin
                @(negedge clk);
                cycles = cycles + 1;
            end
            if (!bus_ack || cycles != expected_cycles ||
                (bus_dout & mask) !== (expected & mask))
                $fatal(1, "[FAIL] CSR %03x cycles=%0d ack=%b data=%04x expected=%04x mask=%04x/%0d",
                       address, cycles, bus_ack, bus_dout, expected, mask, expected_cycles);
            bus_cyc = 1'b0;
            @(negedge clk);
            if (bus_ack)
                $fatal(1, "[FAIL] CSR ACK held after transaction");
        end
    endtask

    task write_word;
        input [11:0] address;
        input [15:0] value;
        input integer expected_cycles;
        integer cycles;
        begin
            @(negedge clk);
            bus_addr = address;
            bus_din = value;
            bus_cyc = 1'b1;
            bus_we = 1'b1;
            cycles = 0;
            while (!bus_ack && cycles < 6) begin
                @(negedge clk);
                cycles = cycles + 1;
            end
            if (!bus_ack || cycles != expected_cycles)
                $fatal(1, "[FAIL] CSR write %03x cycles=%0d expected=%0d",
                       address, cycles, expected_cycles);
            bus_cyc = 1'b0;
            @(negedge clk);
            bus_we = 1'b0;
        end
    endtask

    initial begin
        repeat (5) @(negedge clk);
        rst = 1'b0;
        // Normal control registers retain their original ACK latency.
        // Other status bits (reset pending, suspend) are not constant here.
        write_word(12'h000, 16'h8000, 1);
        read_word(12'h000, 16'h8000, 1, 16'h8000);
        read_word(12'h020, 16'he017, 3, 16'hffff);

        // Verify the entire trace mux including the unmapped range.
        // Set counters directly to isolate CSR readback from packet parsing.
        @(negedge clk);
        dut.g_ep0_trace.cnt_in_token = 16'h1234;
        dut.g_ep0_trace.cnt_data_start = 16'h0203;
        dut.g_ep0_trace.cnt_data_done = 16'h0405;
        dut.g_ep0_trace.cnt_ack = 16'h0607;
        dut.g_ep0_trace.cnt_nak = 16'h0809;
        dut.g_ep0_trace.cnt_stall = 16'h0a0b;
        dut.g_ep0_trace.cnt_rx_err = 16'h0c0d;
        dut.g_ep0_trace.last_data_len = 16'h0012;
        dut.g_ep0_trace.last_tx_pid = 16'h000b;
        read_word(12'h021, 16'h1234, 3, 16'hffff);
        read_word(12'h022, 16'h0203, 3, 16'hffff);
        read_word(12'h023, 16'h0405, 3, 16'hffff);
        read_word(12'h024, 16'h0607, 3, 16'hffff);
        read_word(12'h025, 16'h0809, 3, 16'hffff);
        read_word(12'h026, 16'h0a0b, 3, 16'hffff);
        read_word(12'h027, 16'h0c0d, 3, 16'hffff);
        read_word(12'h028, 16'h0012, 3, 16'hffff);
        read_word(12'h029, 16'h000b, 3, 16'hffff);
        dut.g_ep0_trace.cnt_ack_sync = 16'h1111;
        dut.g_ep0_trace.cnt_ack_pid = 16'h2222;
        dut.g_ep0_trace.cnt_ack_eop = 16'h3333;
        dut.g_ep0_trace.cnt_ack_rx_err = 16'h4444;
        dut.g_ep0_trace.cnt_ack_timeout = 16'h5555;
        dut.g_ep0_trace.cnt_ack_bd_done = 16'h6666;
        dut.g_ep0_trace.last_ack_result = 16'h0071;
        dut.g_ep0_trace.cnt_ack_line_chg = 16'h7777;
        read_word(12'h02a, 16'h1111, 3, 16'hffff);
        read_word(12'h02b, 16'h2222, 3, 16'hffff);
        read_word(12'h02c, 16'h3333, 3, 16'hffff);
        read_word(12'h02d, 16'h4444, 3, 16'hffff);
        read_word(12'h02e, 16'h5555, 3, 16'hffff);
        read_word(12'h02f, 16'h6666, 3, 16'hffff);
        read_word(12'h030, 16'h0071, 3, 16'hffff);
        read_word(12'h031, 16'h7777, 3, 16'hffff);
        read_word(12'h032, 16'h5257, 3, 16'hffff);
        read_word(12'h033, 16'h0001, 3, 16'hffff);
        read_word(12'h034, 16'h0000, 3, 16'hffff);
        // Verify the synchronous raw RAM read path through the same CSR bus.
        @(negedge clk);
        dut.g_ep0_trace.raw_capture_I.ram[0] = 16'h1234;
        dut.g_ep0_trace.raw_capture_I.ram[127] = 16'h5678;
        read_word(12'h040, 16'h1234, 3, 16'hffff);
        read_word(12'h0bf, 16'h5678, 3, 16'hffff);
        write_word(12'h03f, 16'h0001, 3);
        read_word(12'h033, 16'h0001, 3, 16'hffff);

        // An abandoned trace read must not assert a late bus ACK.
        @(negedge clk);
        bus_addr = 12'h021;
        bus_we = 1'b0;
        bus_cyc = 1'b1;
        repeat (2) @(negedge clk);
        if (bus_ack)
            $fatal(1, "[FAIL] early trace ACK before abort");
        bus_cyc = 1'b0;
        @(negedge clk);
        if (bus_ack)
            $fatal(1, "[FAIL] trace ACK survived aborted read");
        read_word(12'h021, 16'h1234, 3, 16'hffff);

        // Trace window is read-only and cannot modify pull-up control.
        write_word(12'h020, 16'h0000, 3);
        read_word(12'h000, 16'h8000, 1, 16'h8000);
        $display("[PASS] ACK CSR and raw capture register/RAM readback isolation");
        $finish;
    end
endmodule
`default_nettype wire
