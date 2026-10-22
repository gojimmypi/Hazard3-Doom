/* Volatile ULX5M-GS BTN2 startup mode probe (LEDs only).
 * No USB, SPI flash, DFU transfer or persistent boot activation.
 */
`default_nettype none
module top_ulx5m_gs_btn2_boot_probe (
    input  wire clk25,
    input  wire btn2_n,
    output wire [7:0] led_n
);
    wire clk48, reset, locked;
    wire mode_valid, dfu_selected, btn2_pressed;
    reg [23:0] heartbeat = 24'd0;
    sysmgr_gatemate clocks (
        .clk_in(clk25), .rst_in(1'b0),
        .clk_48m(clk48), .rst_out(reset), .locked(locked)
    );
    ulx5m_btn2_boot_select selector (
        .clk(clk48), .rst(reset), .btn2_n(btn2_n),
        .mode_valid(mode_valid), .dfu_selected(dfu_selected),
        .btn2_pressed(btn2_pressed)
    );
    always @(posedge clk48) begin
        if (reset)
            heartbeat <= 24'd0;
        else
            heartbeat <= heartbeat + 24'd1;
    end
    // V005 LEDs are active-HIGH despite legacy led_n port name.
    // D7 heartbeat; D6 PLL; D5 ready; D4 DFU; D3 normal; D2 BTN2 level.
    assign led_n = {heartbeat[23], locked, mode_valid,
                    mode_valid && dfu_selected,
                    mode_valid && !dfu_selected,
                    btn2_pressed, 2'b00};
endmodule
`default_nettype wire
