/* Latch the ULX5M BTN2 power-up request after configuration and PLL reset.
 * BTN2 is active-low. Selection is stable until the next FPGA reset.
 * This module decides mode only; it cannot change GateMate boot sources.
 */
`default_nettype none
module ulx5m_btn2_boot_select #(
    parameter integer HOLD_BITS = 21
)(
    input  wire clk,
    input  wire rst,
    input  wire btn2_n,
    output reg  mode_valid = 1'b0,
    output reg  dfu_selected = 1'b0,
    output wire btn2_pressed
);
    (* async_reg = "true" *) reg btn2_meta = 1'b1;
    (* async_reg = "true" *) reg btn2_sync = 1'b1;
    reg [2:0] settle = 3'd0;
    reg [HOLD_BITS-1:0] hold_count = 0;
    reg held_through_window = 1'b1;

    assign btn2_pressed = !btn2_sync;

    always @(posedge clk) begin
        if (rst) begin
            btn2_meta <= 1'b1;
            btn2_sync <= 1'b1;
            settle <= 3'd0;
            hold_count <= 0;
            held_through_window <= 1'b1;
            mode_valid <= 1'b0;
            dfu_selected <= 1'b0;
        end else begin
            btn2_meta <= btn2_n;
            btn2_sync <= btn2_meta;
            if (!mode_valid) begin
                // Allow the two-flop synchronizer to settle before sampling.
                if (!(&settle)) begin
                    settle <= settle + 1'b1;
                end else begin
                    if (btn2_sync)
                        held_through_window <= 1'b0;
                    hold_count <= hold_count + 1'b1;
                    if (&hold_count) begin
                        mode_valid <= 1'b1;
                        dfu_selected <= held_through_window && !btn2_sync;
                    end
                end
            end
        end
    end
endmodule
`default_nettype wire
