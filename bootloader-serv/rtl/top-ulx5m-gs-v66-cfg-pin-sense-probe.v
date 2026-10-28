/* ULX5M-GS v66: bounded flash-configuration-bank ownership isolation.
 *
 * v65's minimal --bootaddr primary succeeded in physically booting the
 * secondary. This comparator intentionally CLAIMS all six dedicated SPI
 * configuration pads as INPUT-ONLY USER GPIO, but never drives, reads or
 * commands the flash through fabric. Thus RECFG should work exactly as v65
 * if merely configuring user inputs does not obstruct SPI-active takeover.
 *
 * D6 on, D7 blinking: this primary. D5: parity of sampled flash pins,
 * used ONLY to ensure the pin input paths survive synthesis.
 * Secondary witness: original D0 blink plus walking LED pattern.
 * This experiment does not provide USB DFU recovery or write flash.
 */
`default_nettype none
module top_ulx5m_gs_v66_cfg_pin_sense_probe #(
    parameter integer RECFG_BITS = 26,
    parameter integer HEARTBEAT_BIT = 22
)(
    input wire clk25,
    input wire [3:0] flash_io,
    input wire flash_cs_n,
    input wire flash_sck,
    output wire [7:0] led_n
);
    reg [RECFG_BITS-1:0] start_count = {RECFG_BITS{1'b0}};
    reg [HEARTBEAT_BIT:0] heartbeat = {(HEARTBEAT_BIT+1){1'b0}};
    reg sensor_parity = 1'b0;
    wire recfg = &start_count;

    always @(posedge clk25) begin
        heartbeat <= heartbeat + 1'b1;
        if (!recfg)
            start_count <= start_count + 1'b1;
        sensor_parity <= ^{flash_io, flash_cs_n, flash_sck};
    end

    // Same primary witness as the successful v65 test; D5 is input sense.
    // LEDs on this board are active-high despite the historical '_n' suffix.
    assign led_n = {heartbeat[HEARTBEAT_BIT], 1'b1, sensor_parity, 5'b0};

    CC_CFG_CTRL cfg_i (
        .CLK(1'b0), .EN(1'b0), .DATA(8'b0),
        .VALID(1'b0), .RECFG(recfg)
    );
endmodule
`default_nettype wire
