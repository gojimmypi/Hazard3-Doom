/* ULX5M-GS button input/pin polarity check.
 * Standalone SRAM-only LED probe. No CC_CFG_CTRL, USB, or SPI signals.
 * D0-D2 display sampled GPIO levels. D3-D5 display their inverses.
 * D6 is a probe identification LED; D7 is a heartbeat.
 * V005 LED pads are active-high despite the historical led_n name.
 */
`default_nettype none
module top_ulx5m_gs_button_polarity #(
    parameter integer HEARTBEAT_BIT = 25
) (
    input wire clk25,
    input wire [2:0] btn_n,
    output wire [7:0] led_n
);
    (* async_reg = "true" *) reg [2:0] btn_meta = 3'b111;
    (* async_reg = "true" *) reg [2:0] btn_sync = 3'b111;
    reg [25:0] heartbeat = 0;

    always @(posedge clk25) begin
        btn_meta <= btn_n;
        btn_sync <= btn_meta;
        heartbeat <= heartbeat + 1'b1;
    end

    assign led_n = {
        heartbeat[HEARTBEAT_BIT],
        1'b1,
        ~btn_sync[2], ~btn_sync[1], ~btn_sync[0],
         btn_sync[2],  btn_sync[1],  btn_sync[0]
    };
endmodule
`default_nettype wire
