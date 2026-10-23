/* ULX5M-GS V005 harmless LED application, SRAM-only.
 * No USB, SPI, flash, configuration primitive, or write operations.
 */
`default_nettype none
module top_ulx5m_gs_normal_led (
    input wire clk25,
    output wire [7:0] led_n
);
    reg [25:0] count = 26'd0;
    always @(posedge clk25)
        count <= count + 1'b1;
    // V005 pads are active-high. A moving point plus a heartbeat.
    wire [2:0] index = count[25:23];
    assign led_n = (8'b00000001 << index) ^ {7'b0, count[24]};
endmodule
`default_nettype wire
