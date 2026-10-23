`timescale 1ns/1ps
`default_nettype none
module tb_ulx5m_cfg_handoff_model;
    reg clk = 1'b0;
    always #10 clk = ~clk;
    reg rst = 1'b1;
    reg start = 1'b0;
    reg mode_valid = 1'b1;
    reg dfu_selected = 1'b0;
    reg integrity_ok = 1'b1;
    reg format_verified = 1'b1;
    reg policy_authorized = 1'b1;
    reg spi_exclusive = 1'b1;
    reg [31:0] image_bytes = 32'd4;
    reg [7:0] read_data = 8'd0;
    reg read_valid = 1'b0;
    reg read_error = 1'b0;
    wire read_request, cfg_en_model, cfg_valid_model, cfg_recfg_model;
    wire busy, done, failed, usb_quiesce_model;
    wire [7:0] cfg_data_model;
    integer cycle = 0;
    integer en_first = -1;
    integer valid_prev = -1;
    integer valid_total = 0;
    integer en_fall = -1;
    reg en_prev = 1'b0;
    reg [7:0] expected_data [0:3];

    ulx5m_cfg_handoff_model #(.READ_TIMEOUT(7), .MAX_BYTES(32'd8)) dut (
        .clk(clk), .rst(rst), .start(start), .mode_valid(mode_valid),
        .dfu_selected(dfu_selected), .integrity_ok(integrity_ok),
        .format_verified(format_verified), .policy_authorized(policy_authorized),
        .spi_exclusive(spi_exclusive), .image_bytes(image_bytes),
        .read_data(read_data), .read_valid(read_valid), .read_error(read_error),
        .read_request(read_request), .cfg_data_model(cfg_data_model),
        .cfg_en_model(cfg_en_model), .cfg_valid_model(cfg_valid_model),
        .cfg_recfg_model(cfg_recfg_model), .busy(busy), .done(done),
        .failed(failed), .usb_quiesce_model(usb_quiesce_model)
    );

    always @(negedge clk) begin
        cycle = cycle + 1;
        if (rst) begin
            en_first = -1;
            valid_prev = -1;
            valid_total = 0;
            en_fall = -1;
            en_prev = 1'b0;
        end else begin
            if (cfg_en_model && !en_prev)
                en_first = cycle;
            if (cfg_valid_model) begin
                if (!cfg_en_model || !cfg_recfg_model)
                    $fatal(1, "VALID without EN and RECFG");
                if (en_first < 0 || cycle - en_first < 3)
                    $fatal(1, "EN-to-first-VALID setup < 3 clocks");
                if (valid_prev >= 0 && cycle - valid_prev < 2)
                    $fatal(1, "VALID without an intervening idle clock");
                if (valid_total >= 4 || cfg_data_model !== expected_data[valid_total])
                    $fatal(1, "Byte mismatch at index %0d", valid_total);
                valid_total = valid_total + 1;
                valid_prev = cycle;
            end
            if (en_prev && !cfg_en_model) begin
                en_fall = cycle;
                if (done && (valid_prev < 0 || cycle - valid_prev < 8))
                    $fatal(1, "EN deasserted before 8 tail clocks");
            end
            en_prev = cfg_en_model;
        end
    end

    task reset_case;
        begin
            @(posedge clk); #1;
            rst = 1'b1;
            start = 1'b0;
            mode_valid = 1'b1;
            dfu_selected = 1'b0;
            integrity_ok = 1'b1;
            format_verified = 1'b1;
            policy_authorized = 1'b1;
            spi_exclusive = 1'b1;
            image_bytes = 32'd4;
            read_valid = 1'b0;
            read_error = 1'b0;
            repeat (3) @(posedge clk);
            @(negedge clk); #1 rst = 1'b0;
        end
    endtask

    task trigger;
        begin
            @(negedge clk); #1 start = 1'b1;
            @(negedge clk); #1 start = 1'b0;
        end
    endtask

    task offer(input [7:0] b);
        begin
            wait (read_request);
            @(negedge clk); #1;
            if (!read_request) $fatal(1, "Read source missed request");
            read_data = b;
            read_valid = 1'b1;
            @(negedge clk); #1 read_valid = 1'b0;
        end
    endtask

    task expect_fail;
        begin
            wait (failed);
            repeat (3) @(negedge clk);
            if (cfg_en_model || cfg_valid_model || read_request || done)
                $fatal(1, "Failure failed to stop the simulated interface");
        end
    endtask

    initial begin
        #200000;
        $fatal(1, "Overall handoff-model test timeout");
    end

    initial begin
        expected_data[0] = 8'hd9;
        expected_data[1] = 8'h01;
        expected_data[2] = 8'hed;
        expected_data[3] = 8'h96;

        reset_case();
        trigger();
        offer(8'hd9);
        offer(8'h01);
        offer(8'hed);
        offer(8'h96);
        wait (done);
        @(negedge clk); #2;
        if (valid_total != 4 || en_fall < 0 || cfg_en_model || failed)
            $fatal(1, "Valid 4-byte framing did not finish");
        $display("[PASS] Model timing: EN lead, interbyte gaps, 8-cycle tail");

        reset_case();
        integrity_ok = 1'b0;
        trigger(); expect_fail();
        if (valid_total != 0) $fatal(1, "Missing image streamed");
        $display("[PASS] Missing/invalid candidate blocked");

        reset_case();
        format_verified = 1'b0;
        trigger(); expect_fail();
        reset_case();
        policy_authorized = 1'b0;
        trigger(); expect_fail();
        reset_case();
        spi_exclusive = 1'b0;
        trigger(); expect_fail();
        $display("[PASS] Format/policy/SPI ownership gates");

        reset_case();
        dfu_selected = 1'b1;
        trigger(); expect_fail();
        if (usb_quiesce_model || valid_total != 0)
            $fatal(1, "DFU selection mishandled");
        $display("[PASS] BTN2-held DFU cannot hand off");

        reset_case();
        image_bytes = 32'd0;
        trigger(); expect_fail();
        reset_case();
        image_bytes = 32'd9;
        trigger(); expect_fail();
        $display("[PASS] Empty/out-of-range length blocked");

        reset_case();
        trigger();
        wait (read_request);
        @(negedge clk); #1 read_error = 1'b1;
        @(negedge clk); #1 read_error = 1'b0;
        expect_fail();
        $display("[PASS] Mock flash read error blocks streaming");

        reset_case();
        trigger();
        expect_fail();
        $display("[PASS] Mock flash read timeout blocks streaming");

        reset_case();
        trigger();
        offer(8'hd9);
        wait (read_request);
        @(negedge clk); #1 spi_exclusive = 1'b0;
        expect_fail();
        $display("[PASS] SPI ownership loss interrupts model");

        reset_case();
        trigger();
        wait (read_request);
        @(negedge clk); #1 rst = 1'b1;
        repeat (2) @(negedge clk);
        if (cfg_en_model || cfg_valid_model || read_request || done || failed)
            $fatal(1, "Reset did not clear in-flight attempt");
        $display("[PASS] Reset aborts before the first byte");

        reset_case();
        trigger();
        if (!busy || read_request) $fatal(1, "Lead phase not entered");
        @(negedge clk); #1 rst = 1'b1;
        repeat (2) @(negedge clk);
        if (cfg_en_model || cfg_valid_model || done || failed)
            $fatal(1, "Reset during EN lead did not abort");
        $display("[PASS] Reset aborts during EN lead");

        reset_case();
        trigger();
        offer(8'hd9);
        if (!cfg_valid_model) $fatal(1, "Expected first byte pulse");
        #2 rst = 1'b1;
        repeat (2) @(negedge clk);
        if (cfg_en_model || cfg_valid_model || done || failed)
            $fatal(1, "Reset during byte pulse did not abort");
        $display("[PASS] Reset aborts during byte pulse");

        reset_case();
        trigger();
        offer(8'hd9);
        offer(8'h01);
        offer(8'hed);
        offer(8'h96);
        @(negedge clk); #1;
        if (done || !busy || cfg_valid_model || read_request)
            $fatal(1, "Expected 8-cycle EN tail");
        @(negedge clk); #1 rst = 1'b1;
        repeat (2) @(negedge clk);
        if (cfg_en_model || cfg_valid_model || done || failed)
            $fatal(1, "Reset during EN tail did not abort");
        $display("[PASS] Reset aborts during EN tail");

        reset_case();
        trigger();
        offer(8'hd9);
        @(negedge clk); #1;
        if (!busy || read_request || cfg_valid_model)
            $fatal(1, "Expected interbyte idle state");
        rst = 1'b1;
        repeat (2) @(negedge clk);
        if (cfg_en_model || cfg_valid_model || done || failed)
            $fatal(1, "Reset during interbyte gap did not abort");
        $display("[PASS] Reset aborts during interbyte gap");

        reset_case();
        trigger();
        offer(8'hd9);
        wait (read_request);
        @(negedge clk); #1 read_error = 1'b1;
        expect_fail();
        $display("[PASS] Read error after a transmitted byte stops the model");

        reset_case();
        trigger();
        offer(8'hd9);
        expect_fail();
        $display("[PASS] Timeout after a transmitted byte stops the model");

        reset_case();
        trigger();
        offer(8'hd9);
        offer(8'h01);
        offer(8'hed);
        offer(8'h96);
        wait (done);
        @(negedge clk); #1 rst = 1'b1;
        repeat (2) @(negedge clk);
        if (cfg_en_model || cfg_valid_model || done || failed)
            $fatal(1, "Reset after done did not clear state");
        $display("[PASS] Reset clears completed state");

        reset_case();
        integrity_ok = 1'b0;
        trigger();
        expect_fail();
        @(negedge clk); #1 rst = 1'b1;
        repeat (2) @(negedge clk);
        if (cfg_en_model || cfg_valid_model || done || failed)
            $fatal(1, "Reset after failure did not clear state");
        $display("[PASS] Reset clears failed state");

        $display("[PASS] Simulation-only handoff controller: all checks");
        $finish;
    end
endmodule
`default_nettype wire
