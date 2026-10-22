`timescale 1ns / 1ps
`default_nettype none
module tb_ulx5m_btn2_boot_select;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg btn2_n = 1'b1;
    wire mode_valid, dfu_selected, btn2_pressed;
    always #10 clk = ~clk;
    ulx5m_btn2_boot_select #(.HOLD_BITS(5)) dut (
        .clk(clk), .rst(rst), .btn2_n(btn2_n),
        .mode_valid(mode_valid), .dfu_selected(dfu_selected),
        .btn2_pressed(btn2_pressed)
    );

    task restart(input reg btn_held);
        begin
            @(negedge clk);
            rst = 1'b1;
            btn2_n = !btn_held;
            repeat (4) @(negedge clk);
            rst = 1'b0;
        end
    endtask
    task check_selected(input reg expected_dfu);
        begin
            wait (mode_valid == 1'b1);
            @(negedge clk);
            if (dfu_selected !== expected_dfu)
                $fatal(1, "Expected DFU=%b, got %b", expected_dfu, dfu_selected);
        end
    endtask
    initial begin
        #30000;
        $fatal(1, "BTN2 selector timed out");
    end
    initial begin
        // BTN2 unpressed throughout startup -> normal boot.
        restart(1'b0);
        check_selected(1'b0);
        btn2_n = 1'b0;
        repeat (40) @(negedge clk);
        if (dfu_selected !== 1'b0) $fatal(1, "Late BTN2 changed mode");

        // BTN2 held through startup -> latched DFU, even after release.
        restart(1'b1);
        check_selected(1'b1);
        btn2_n = 1'b1;
        repeat (40) @(negedge clk);
        if (dfu_selected !== 1'b1) $fatal(1, "BTN2 release changed mode");

        // BTN2 pressed late: not held through entire sample window.
        restart(1'b0);
        repeat (20) @(negedge clk);
        btn2_n = 1'b0;
        check_selected(1'b0);

        // BTN2 released early: reject even if pressed again before latch.
        restart(1'b1);
        repeat (17) @(negedge clk);
        btn2_n = 1'b1;
        repeat (5) @(negedge clk);
        btn2_n = 1'b0;
        check_selected(1'b0);
        $display("[PASS] BTN2 startup hold, normal, late press, early release, latch");
        $finish;
    end
endmodule
`default_nettype wire
