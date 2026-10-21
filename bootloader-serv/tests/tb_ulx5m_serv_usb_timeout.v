// USB transaction receive-timeout regression.
// This tests the actual usb_trans RTL with its microcode input forced to
// a single timeout-load opcode; it does not model USB packet traffic.
`timescale 1ns/1ps
`default_nettype none

module tb_ulx5m_serv_usb_timeout;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg rxpkt_start = 1'b0;
    integer i;
    integer timeout_pulses;
    integer first_pulse;

    always #10 clk = ~clk;

    usb_trans #(
        .MC_INIT_FILE("build-ulx5m-gs/usb_trans_mc-timeout-test.hex")
    ) dut (
        .txpkt_done(1'b0),
        .txpkt_data_ack(1'b0),
        .rxpkt_start(rxpkt_start),
        .rxpkt_done_ok(1'b0),
        .rxpkt_done_err(1'b0),
        .rxpkt_pid(4'b0),
        .rxpkt_is_sof(1'b0),
        .rxpkt_is_token(1'b0),
        .rxpkt_is_data(1'b0),
        .rxpkt_is_handshake(1'b0),
        .rxpkt_frameno(11'b0),
        .rxpkt_addr(7'b0),
        .rxpkt_endp(4'b0),
        .rxpkt_data(8'b0),
        .rxpkt_data_stb(1'b0),
        .buf_tx_data_1(8'b0),
        .eps_rddata_3(16'b0),
        .cr_addr_chk(1'b0),
        .cr_addr(7'b0),
        .cel_rel(1'b0),
        .cel_ena(1'b0),
        .clk(clk),
        .rst(rst)
    );

    task load_timeout;
        begin
            @(negedge clk);
            force dut.mc_opcode = 16'h70c8; // EVT_RTO(200)
            @(posedge clk);
            #1;
            if (dut.rto_cnt !== 10'h3c8)
                $fatal(1, "timeout load incorrect: got %h expected 3c8", dut.rto_cnt);
            @(negedge clk);
            force dut.mc_opcode = 16'h0000; // NOP while timer runs
        end
    endtask

    initial begin
        // Avoid executing the actual production microcode in this unit test.
        force dut.mc_opcode = 16'h0000;
        repeat (4) @(negedge clk);
        rst = 1'b0;

        load_timeout();
        timeout_pulses = 0;
        first_pulse = 0;
        for (i = 1; i <= 230; i = i + 1) begin
            @(posedge clk);
            #1;
            if (dut.rto_now) begin
                timeout_pulses = timeout_pulses + 1;
                first_pulse = i;
            end
        end
        if (timeout_pulses != 1 || first_pulse != 201)
            $fatal(1, "timeout missing/incorrect: pulses=%0d first_cycle=%0d",
                   timeout_pulses, first_pulse);
        if (dut.evt[3] !== 1'b1)
            $fatal(1, "timeout event did not reach transaction engine");

        // Starting a receive packet must cancel a pending timeout.
        load_timeout();
        // Simulate an ACK PID arriving after the old 70-cycle timeout.
        repeat (90) @(posedge clk);
        @(negedge clk);
        rxpkt_start = 1'b1;
        @(posedge clk);
        #1;
        if (dut.rto_cnt[9] !== 1'b0)
            $fatal(1, "RX packet start failed to cancel timeout");
        @(negedge clk);
        rxpkt_start = 1'b0;
        for (i = 0; i < 230; i = i + 1) begin
            @(posedge clk);
            #1;
            if (dut.rto_now)
                $fatal(1, "cancelled timeout fired");
        end

        // A subsequent timeout can be armed and fired normally.
        load_timeout();
        timeout_pulses = 0;
        for (i = 1; i <= 230; i = i + 1) begin
            @(posedge clk);
            #1;
            if (dut.rto_now)
                timeout_pulses = timeout_pulses + 1;
        end
        if (timeout_pulses != 1)
            $fatal(1, "rearmed timeout did not fire once");

        $display("[PASS] USB receive timeout 200-clock window fires, accepts late PID and rearms");
        $finish;
    end
endmodule

`default_nettype wire
