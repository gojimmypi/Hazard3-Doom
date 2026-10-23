/* Isolated SRAM-only BTN2 DFU startup gate for ULX5M-GS.
 * No flash boot handoff: unselected mode holds firmware/peripherals in reset.
 * BTN2 must be held continuously through the post-configuration window.
 */
`default_nettype none
module ulx5m_btn2_dfu_gate #(
    parameter integer HOLD_BITS = 21,
    parameter integer REGISTERED_RELEASE = 0
)(
    input  wire clk,
    input  wire rst,
    input  wire btn2_n,
    output wire fw_reset,
    output wire dfu_enable,
    output wire mode_valid,
    output wire dfu_selected,
    output wire btn2_pressed
);
    ulx5m_btn2_boot_select #(.HOLD_BITS(HOLD_BITS)) select_i (
        .clk(clk), .rst(rst), .btn2_n(btn2_n),
        .mode_valid(mode_valid), .dfu_selected(dfu_selected),
        .btn2_pressed(btn2_pressed)
    );
    generate if (REGISTERED_RELEASE == 2) begin : g_async_registered_release
        // Assert reset without waiting for a clock (PLL may be unlocked).
        // Release only on a clock edge after BTN2 mode selection is valid.
        // No combinational rst bypass drives the CPU/peripheral datapath.
        reg fw_reset_q = 1'b1;
        always @(posedge clk or posedge rst) begin
            if (rst)
                fw_reset_q <= 1'b1;
            else
                fw_reset_q <= !(mode_valid && dfu_selected);
        end
        assign fw_reset = fw_reset_q;
        assign dfu_enable = !fw_reset_q;
    end else if (REGISTERED_RELEASE != 0) begin : g_registered_release
        // Isolate the startup selector from the peripheral reset fanout.
        // The PLL/system reset still asserts the firmware reset immediately.
        // Only deassertion is registered on the shared firmware clock.
        reg fw_reset_q = 1'b1;
        always @(posedge clk) begin
            if (rst)
                fw_reset_q <= 1'b1;
            else
                fw_reset_q <= !(mode_valid && dfu_selected);
        end
        assign fw_reset = rst | fw_reset_q;
        assign dfu_enable = !fw_reset;
    end else begin : g_original_release
        // Preserve the routed, hardware-tested seed-38 variant by default.
        assign dfu_enable = mode_valid && dfu_selected && !rst;
        assign fw_reset = !dfu_enable;
    end endgenerate
endmodule
`default_nettype wire
