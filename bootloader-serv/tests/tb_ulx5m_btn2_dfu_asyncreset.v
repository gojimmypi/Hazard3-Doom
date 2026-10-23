`timescale 1ns/1ps
`default_nettype none
module tb_ulx5m_btn2_dfu_asyncreset;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg btn2_n = 1'b1;
    reg usb_attach_request = 1'b1;
    wire fw_reset, dfu_enable, mode_valid, dfu_selected, btn2_pressed;
    wire usb_pull_enable = usb_attach_request && !fw_reset;

    always #10 clk = ~clk;
    ulx5m_btn2_dfu_gate #(.HOLD_BITS(5), .REGISTERED_RELEASE(2)) dut (
        .clk(clk), .rst(rst), .btn2_n(btn2_n),
        .fw_reset(fw_reset), .dfu_enable(dfu_enable),
        .mode_valid(mode_valid), .dfu_selected(dfu_selected),
        .btn2_pressed(btn2_pressed)
    );

    // Changing selection must not expose the USB pull-up before the latch.
    always @(negedge clk) begin
        if (!rst && !mode_valid && (!fw_reset || usb_pull_enable))
            $fatal(1, "USB attached before BTN2 selection");
    end

    task restart(input reg held);
        begin
            @(negedge clk);
            rst = 1'b1;
            btn2_n = !held;
            #1;
            if (fw_reset !== 1'b1 || usb_pull_enable !== 1'b0)
                $fatal(1, "Reset assertion did not disconnect USB");
            repeat (5) @(negedge clk);
            rst = 1'b0;
        end
    endtask

    task expect_mode(input reg dfu);
        begin
            wait (mode_valid === 1'b1);
            #1;
            if (dfu_selected !== dfu)
                $fatal(1, "Incorrect latched mode");
            if (dfu && (fw_reset !== 1'b1 || usb_pull_enable !== 1'b0))
                $fatal(1, "Registered reset released too soon");
            @(posedge clk);
            #1;
            if (dfu_enable !== dfu || fw_reset !== !dfu ||
                usb_pull_enable !== dfu)
                $fatal(1, "Incorrect registered release after latch");
        end
    endtask

    initial begin
        #60000;
        $fatal(1, "BTN2 async-reset test timed out");
    end

    initial begin
        // BTN2 absent at startup: normal-mode placeholder remains in reset.
        restart(1'b0);
        expect_mode(1'b0);
        btn2_n = 1'b0;
        repeat (50) @(negedge clk);
        if (!fw_reset || usb_pull_enable || dfu_enable)
            $fatal(1, "Late BTN2 enabled DFU");

        // Hold BTN2 through startup, then release without disabling DFU.
        restart(1'b1);
        repeat (20) @(negedge clk);
        if (!fw_reset || usb_pull_enable)
            $fatal(1, "Premature USB attach");
        expect_mode(1'b1);
        btn2_n = 1'b1;
        repeat (40) @(negedge clk);
        if (fw_reset || !dfu_enable || !usb_pull_enable)
            $fatal(1, "BTN2 release disabled DFU");

        // PLL/system reset must disconnect USB immediately, without a clock.
        @(negedge clk);
        #2;
        rst = 1'b1;
        #1; // No clock edge between reset assertion and this check.
        if (!fw_reset || usb_pull_enable || dfu_enable)
            $fatal(1, "Async system reset did not immediately disconnect USB");
        repeat (5) @(negedge clk);
        rst = 1'b0;

        // Releasing BTN2 during the hold window must select normal mode.
        restart(1'b1);
        repeat (20) @(negedge clk);
        btn2_n = 1'b1;
        repeat (5) @(negedge clk);
        btn2_n = 1'b0;
        expect_mode(1'b0);
        if (!fw_reset || usb_pull_enable)
            $fatal(1, "Early BTN2 release enabled DFU");

        $display("[PASS] BTN2 async reset: deferred release, immediate assertion, USB attach guard");
        $finish;
    end
endmodule
`default_nettype wire
