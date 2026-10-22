`timescale 1ns/1ps
`default_nettype none
module tb_ulx5m_btn2_dfu_gate;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg btn2_n = 1'b1;
    reg usb_attach_request = 1'b1;
    wire fw_reset, dfu_enable, mode_valid, dfu_selected, btn2_pressed;
    wire usb_pull_enable = usb_attach_request && !fw_reset;
    always #10 clk = ~clk;
    ulx5m_btn2_dfu_gate #(.HOLD_BITS(5)) dut (
        .clk(clk), .rst(rst), .btn2_n(btn2_n),
        .fw_reset(fw_reset), .dfu_enable(dfu_enable),
        .mode_valid(mode_valid), .dfu_selected(dfu_selected),
        .btn2_pressed(btn2_pressed)
    );
    task restart(input reg held);
        begin
            @(negedge clk);
            rst = 1'b1;
            btn2_n = !held;
            repeat (5) @(negedge clk);
            if (fw_reset !== 1'b1 || usb_pull_enable !== 1'b0)
                $fatal(1, "Not disconnected during selector reset");
            rst = 1'b0;
        end
    endtask
    task expect_mode(input reg dfu);
        begin
            wait (mode_valid == 1'b1);
            @(negedge clk);
            if (dfu_selected !== dfu || dfu_enable !== dfu ||
                fw_reset !== !dfu || usb_pull_enable !== dfu)
                $fatal(1, "Incorrect mode/gate after latch");
        end
    endtask
    initial begin
        #60000;
        $fatal(1, "BTN2 DFU gate timed out");
    end
    initial begin
        // Normal path: no CPU, USB or SPI activity; no late BTN2 override.
        restart(1'b0);
        expect_mode(1'b0);
        btn2_n = 1'b0;
        repeat (50) @(negedge clk);
        if (!fw_reset || usb_pull_enable || dfu_enable)
            $fatal(1, "Late BTN2 enabled the DFU path");

        // DFU path: button held through initial 2-flop + hold window.
        restart(1'b1);
        repeat (20) @(negedge clk);
        if (fw_reset !== 1'b1 || usb_pull_enable !== 1'b0)
            $fatal(1, "Premature USB attach");
        expect_mode(1'b1);
        btn2_n = 1'b1;
        repeat (40) @(negedge clk);
        if (fw_reset || !dfu_enable || !usb_pull_enable)
            $fatal(1, "BTN2 release reset running firmware");

        // Aborted hold selects normal and prevents USB attach.
        restart(1'b1);
        repeat (20) @(negedge clk);
        btn2_n = 1'b1;
        repeat (5) @(negedge clk);
        btn2_n = 1'b0;
        expect_mode(1'b0);
        if (!fw_reset || usb_pull_enable)
            $fatal(1, "Early BTN2 release enabled DFU");
        $display("[PASS] BTN2 DFU gate: held enables, released locks out, USB unattached until latch");
        $finish;
    end
endmodule
`default_nettype wire
