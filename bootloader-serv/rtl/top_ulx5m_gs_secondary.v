// Source-backed ULX5M-GS V005 LED secondary; not the recovered v41 bitstream.
// Native GateMate image only: no SERV, USB, flash access or CFG controller.
module top_ulx5m_gs_secondary #(
    parameter integer STEP_TICKS = 6250000  // 25 MHz: one LED step per 250 ms
) (
    input  wire       clk25,
    output wire [7:0] led_n
);
    // led_n is the historical port name; V005 LEDs are active HIGH.
    localparam integer COUNT_BITS = (STEP_TICKS > 1) ? $clog2(STEP_TICKS) : 1;
    reg [COUNT_BITS-1:0] count = 0;
    reg [2:0] position = 0;
    reg heartbeat = 0;

    always @(posedge clk25) begin
        if (count == STEP_TICKS - 1) begin
            count <= 0;
            position <= (position == 6) ? 0 : position + 1'b1;
            heartbeat <= ~heartbeat;
        end else begin
            count <= count + 1'b1;
        end
    end

    assign led_n = {7'b0000001 << position, heartbeat};
endmodule
