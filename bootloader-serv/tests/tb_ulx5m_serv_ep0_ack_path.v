/*
 * Offline 48 MHz USB ACK receiver-path regression.
 * Drives NRZI full-speed symbols through the SIM PHY, real usb_rx_ll and
 * usb_rx_pkt. Only the unrelated transaction microcode/TX-completion
 * signals are forced to set up a pending EP0 DATA response window.
 * No hardware I/O or FPGA flash access.
 */
`timescale 1ns/1ps
`default_nettype none
module tb_ulx5m_serv_ep0_ack_path;
    reg clk = 1'b0;
    reg rst = 1'b1;
    always #10.417 clk = ~clk;

    tri pad_dp;
    tri pad_dn;
    reg host_dp = 1'b1;
    reg host_dn = 1'b0;
    assign pad_dp = host_dp;
    assign pad_dn = host_dn;
    wire [31:0] unused_ep_data;

    usb #(
        .TARGET("SIM"), .EPDW(32), .EP0_TRACE(1), .RX_TX_GUARD(1),
        .MC_INIT_FILE("build-ulx5m-gs/usb_trans_mc.hex")
    ) dut (
        .pad_dp(pad_dp), .pad_dn(pad_dn), .pad_pu(),
        .ep_tx_addr_0(9'b0), .ep_tx_data_0(32'b0), .ep_tx_we_0(1'b0),
        .ep_rx_addr_0(9'b0), .ep_rx_data_1(unused_ep_data),
        .ep_rx_re_0(1'b0), .ep_clk(clk),
        .bus_addr(12'b0), .bus_din(16'b0), .bus_dout(),
        .bus_cyc(1'b0), .bus_we(1'b0), .bus_ack(),
        .irq(), .sof(), .clk(clk), .rst(rst)
    );

    integer phy_change_events = 0;
    integer rx_sample_events = 0;
    integer rx_sync_events = 0;
    integer rx_ack_pid_events = 0;
    integer rx_ack_done_events = 0;
    integer rx_error_events = 0;
    always @(posedge clk) if (!rst) begin
        if (dut.phy_rx_chg)
            phy_change_events = phy_change_events + 1;
        if (dut.rxll_valid)
            rx_sample_events = rx_sample_events + 1;
        if (dut.rxll_valid && dut.rxll_sync)
            rx_sync_events = rx_sync_events + 1;
        if (dut.rxpkt_start && dut.rxpkt_pid == 4'h2)
            rx_ack_pid_events = rx_ack_pid_events + 1;
        if (dut.rxpkt_done_ok && dut.rxpkt_pid == 4'h2)
            rx_ack_done_events = rx_ack_done_events + 1;
        if (dut.rxpkt_done_err)
            rx_error_events = rx_error_events + 1;
    end

    // 4 clocks per USB bit at a nominal 48 MHz internal clock.
    task symbol;
        input [1:0] sym;
        begin
            @(negedge clk);
            host_dp = sym[1];
            host_dn = sym[0];
            repeat (4) @(posedge clk);
        end
    endtask

    // NRZI J=10 K=01, 0 toggles level and 1 keeps the level.
    reg nrzi_j;
    task nrzi_bit;
        input data_bit;
        begin
            if (!data_bit)
                nrzi_j = !nrzi_j;
            symbol(nrzi_j ? 2'b10 : 2'b01);
        end
    endtask

    task nrzi_byte;
        input [7:0] value;
        integer b;
        begin
            for (b = 0; b < 8; b = b + 1)
                nrzi_bit(value[b]);
        end
    endtask

    task usb_handshake;
        input [7:0] pid_byte;
        begin
            nrzi_j = 1'b1;
            symbol(2'b10);           // idle J
            nrzi_byte(8'h80);        // USB SYNC, LSB first
            nrzi_byte(pid_byte);     // ACK=0xd2; 0xc2 has corrupt PID complement
            symbol(2'b00);          // EOP: two SE0 bits then J
            symbol(2'b00);
            symbol(2'b10);
            repeat (20) @(posedge clk);
        end
    endtask

    // Model an EP0 DATA packet still driving the pads after pkt_done.
    // The old trace opened on pkt_done and counted this device EOP as if
    // it were the host EOP. GateMate registers the output enable in the IO.
    task begin_ep0_data_response;
        integer saved_eop;
        begin
            saved_eop = dut.g_ep0_trace.cnt_ack_eop;
            @(negedge clk);
            force dut.phy_tx_en = 1'b1;
            force dut.txpkt_pid = 4'h3;
            force dut.dbg_trans_ep0 = 1'b1;
            force dut.txpkt_done = 1'b1;
            @(negedge clk);
            release dut.txpkt_done;
            if (!dut.g_ep0_trace.ack_tx_pending ||
                dut.g_ep0_trace.ack_window)
                $fatal(1, "ACK window opened before TX output released");
            // Outgoing device EOP, delivered to the SIM input as echo.
            symbol(2'b00);
            symbol(2'b00);
            symbol(2'b10);
            if (dut.g_ep0_trace.cnt_ack_eop !== saved_eop)
                $fatal(1, "Our own TX EOP was counted as a host EOP");
            @(negedge clk);
            release dut.phy_tx_en;
            // The handshake task adds one J bit (four clocks); combined
            // with this gap, ACK SYNC begins only eight clocks after release.
            repeat (4) @(negedge clk);
            if (!dut.g_ep0_trace.ack_window ||
                dut.g_ep0_trace.ack_tx_pending ||
                dut.rx_ll_I.dec_rep_state_1[3])
                $fatal(1, "Receiver failed to rearm after the TX turnaround");
        end
    endtask

    // Opt-in full waveform when an assertion fails:
    //   vvp build-ulx5m-gs/flash-serv-ep0-ack-test.vvp +vcd
    initial if ($test$plusargs("vcd")) begin
        $dumpfile("build-ulx5m-gs/flash-serv-ep0-ack-test.vcd");
        $dumpvars(0, tb_ulx5m_serv_ep0_ack_path);
    end

    initial begin
        // Production RX LL now initializes decode history on reset.
        // Do not force receiver internals: this tests cold startup too.

        // Prevent an unrelated microcode-generated transmit while testing RX.
        force dut.trans_I.mc_opcode = 16'h0000;
        repeat (10) @(negedge clk);
        rst = 1'b0;
        repeat (25) @(posedge clk);

        // Valid ACK: both RX stages and the response-window trace must pass.
        begin_ep0_data_response();
        repeat (5) @(posedge clk);
        usb_handshake(8'hd2);
        if (rx_sync_events != 1 || rx_ack_pid_events != 1 ||
            rx_ack_done_events != 1 || rx_error_events != 0)
            $fatal(1, "valid ACK decode: phy_chg=%0d rx_samples=%0d sync=%0d pid=%0d done=%0d err=%0d phy=%b%b active=%b rx_state=%0d",
                   phy_change_events, rx_sample_events, rx_sync_events,
                   rx_ack_pid_events, rx_ack_done_events, rx_error_events,
                   dut.phy_rx_dp, dut.phy_rx_dn,
                   dut.rx_ll_I.samp_active, dut.rx_pkt_I.state);
        if (dut.g_ep0_trace.ack_window !== 1'b0 ||
            dut.g_ep0_trace.cnt_ack_sync !== 16'd1 ||
            dut.g_ep0_trace.cnt_ack_pid !== 16'd1 ||
            dut.g_ep0_trace.cnt_ack_eop !== 16'd1 ||
            dut.g_ep0_trace.cnt_ack !== 16'd1 ||
            dut.g_ep0_trace.last_ack_result[7:0] !== 8'h17)
            $fatal(1, "valid ACK trace: sync=%d pid=%d eop=%d ack=%d flags=%h",
                   dut.g_ep0_trace.cnt_ack_sync, dut.g_ep0_trace.cnt_ack_pid,
                   dut.g_ep0_trace.cnt_ack_eop, dut.g_ep0_trace.cnt_ack,
                   dut.g_ep0_trace.last_ack_result);

        // A corrupt ACK PID complement must not count as a valid host ACK.
        begin_ep0_data_response();
        repeat (5) @(posedge clk);
        usb_handshake(8'hc2);
        if (rx_sync_events != 2 || rx_ack_pid_events != 1 ||
            rx_ack_done_events != 1 || rx_error_events != 1)
            $fatal(1, "bad PID decode: sync=%0d pid=%0d done=%0d err=%0d",
                   rx_sync_events, rx_ack_pid_events, rx_ack_done_events,
                   rx_error_events);
        if (dut.g_ep0_trace.cnt_ack_rx_err !== 16'd1 ||
            dut.g_ep0_trace.cnt_ack_sync !== 16'd2 ||
            dut.g_ep0_trace.cnt_ack_pid !== 16'd1 ||
            dut.g_ep0_trace.last_ack_result[7:0] !== 8'h09)
            $fatal(1, "bad PID classification: flags=%h",
                   dut.g_ep0_trace.last_ack_result);

        // Check that the EP0 IN DONE_OK descriptor write qualifier is not
        // confused with an OUT descriptor write or a non-DONE state.
        @(negedge clk);
        force dut.eps_write_0 = 1'b1;
        force dut.eps_addr_0 = 8'h0c;  // EP0, IN, BD word 0
        force dut.eps_wrdata_0 = 16'h8000;  // DONE_OK
        @(negedge clk);
        release dut.eps_write_0;
        release dut.eps_addr_0;
        release dut.eps_wrdata_0;
        if (dut.g_ep0_trace.cnt_ack_bd_done !== 16'd1)
            $fatal(1, "EP0 IN DONE_OK writeback counter failed");

        // Host silence: let the transaction engine's real timeout regression
        // test cover countdown; here inject only its debug timeout pulse.
        begin_ep0_data_response();
        repeat (8) @(posedge clk);
        @(negedge clk);
        force dut.dbg_ack_timeout = 1'b1;
        @(negedge clk);
        release dut.dbg_ack_timeout;
        if (dut.g_ep0_trace.ack_window !== 1'b0 ||
            dut.g_ep0_trace.cnt_ack_timeout !== 16'd1 ||
            dut.g_ep0_trace.last_ack_result[8] !== 1'b0 ||
            dut.g_ep0_trace.last_ack_result[7:0] !== 8'h20)
            $fatal(1, "ACK timeout classification: flags=%h",
                   dut.g_ep0_trace.last_ack_result);

        $display("[PASS] GateMate TX/RX turnaround, clean host ACK/EOP, corrupt PID and timeout");
        $finish;
    end

    initial begin
        #400000;
        $fatal(1, "ACK-path simulation watchdog expired");
    end
endmodule
`default_nettype wire
