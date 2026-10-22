/* Isolated SRAM-only BTN2 DFU startup gate for ULX5M-GS.
 * No flash boot handoff: unselected mode holds firmware/peripherals in reset.
 * BTN2 must be held continuously through the post-configuration window.
 */
`default_nettype none
module ulx5m_btn2_dfu_gate #(
    parameter integer HOLD_BITS = 21
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
    assign dfu_enable = mode_valid && dfu_selected && !rst;
    assign fw_reset = !dfu_enable;
endmodule
`default_nettype wire
