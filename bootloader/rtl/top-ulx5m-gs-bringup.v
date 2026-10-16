/* ULX5M-GS V005: safe, RAM-only clock/LED/button bring-up.
 * No flash, USB, DFU or external RAM pins are touched by this design.
 */
`default_nettype none
module top_ulx5m_gs_bringup (
    input wire clk25,
    input wire btn0_n,
    output wire [7:0] led_n
);
    wire clk48;
    wire reset;
    wire locked;
    sysmgr_gatemate clocks (
        .clk_in(clk25),
        .rst_in(1'b0),
        .clk_48m(clk48),
        .rst_out(reset),
        .locked(locked)
    );

    reg [25:0] counter = 26'd0;
    always @(posedge clk48) begin
        if (reset)
            counter <= 26'd0;
        else
            counter <= counter + 26'd1;
    end

    // Active-low LEDs. D7 blinks, D6 shows PLL lock, D0 follows BTN1.
    assign led_n[7] = !counter[24];
    assign led_n[6] = !locked;
    assign led_n[5:1] = 5'b11111;
    assign led_n[0] = btn0_n;
endmodule
`default_nettype wire
