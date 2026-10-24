/* Combined normal-boot USB reset gating; no USB PHY or flash writes. */
`timescale 1ns/1ps
`default_nettype none
module tb_ulx5m_normal_boot_usb_gate;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg btn2_n = 1'b1;
    wire mode_valid, dfu_selected, btn2_pressed;
    wire fw_reset;
    wire dfu_enable = mode_valid && dfu_selected && !rst;
    wire usb_core_reset = fw_reset | ~dfu_enable;

    always #5 clk = ~clk;

    ulx5m_btn2_boot_select #(.HOLD_BITS(4)) select_i (
        .clk(clk), .rst(rst), .btn2_n(btn2_n),
        .mode_valid(mode_valid), .dfu_selected(dfu_selected),
        .btn2_pressed(btn2_pressed)
    );
    ulx5m_normal_boot_reset normal_reset_i (
        .clk(clk), .rst(rst), .mode_valid(mode_valid),
        .fw_reset(fw_reset)
    );

    initial begin
        #10000;
        $fatal(1, "USB gate test timeout");
    end

    initial begin
        // DFU selection: hold BTN2 throughout the startup window.
        btn2_n = 1'b0;
        #22 rst = 1'b0;
        if (!usb_core_reset) $fatal(1, "USB enabled before selection");
        wait (mode_valid);
        repeat (3) @(posedge clk);
        #1;
        if (!dfu_selected || fw_reset || usb_core_reset)
            $fatal(1, "DFU selection failed to release USB");
        btn2_n = 1'b1;
        repeat (5) @(posedge clk);
        #1;
        if (!dfu_selected || usb_core_reset || btn2_pressed)
            $fatal(1, "BTN2 release changed latched DFU mode");
        $display("[PASS] BTN2 held at startup; USB enabled after latch and release");

        // Global reset must assert the USB reset without waiting for clk.
        #2 rst = 1'b1;
        #1;
        if (!usb_core_reset || !fw_reset)
            $fatal(1, "Global reset did not immediately disable USB");
        btn2_n = 1'b1;
        repeat (3) @(posedge clk);
        #1 rst = 1'b0;
        wait (mode_valid);
        repeat (3) @(posedge clk);
        #1;
        if (dfu_selected || fw_reset || !usb_core_reset)
            $fatal(1, "Normal mode did not keep USB in reset");
        btn2_n = 1'b0;
        repeat (5) @(posedge clk);
        #1;
        if (dfu_selected || !usb_core_reset || !btn2_pressed)
            $fatal(1, "Late BTN2 press altered normal mode USB isolation");
        $display("[PASS] BTN2 released at startup; USB remains disabled");
        $display("[PASS] Global reset immediately disables USB");
        $finish;
    end
endmodule
`default_nettype wire
