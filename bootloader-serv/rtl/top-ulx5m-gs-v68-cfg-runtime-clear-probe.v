/* ULX5M-GS v68: isolated runtime config-bank release probe. EXPERIMENTAL.
 *
 * v65: SPI-active RECFG works with no West-A user GPIO.
 * v66: same RECFG fails with six input-only West-A flash GPIO.
 * v67: the SAME v66 routed fabric succeeds if the configuration status
 *      third payload byte is cleared 0x08 -> 0x00 at PACK TIME.
 *
 * This v68 deliberately keeps the v66 input-only flash GPIO and their
 * original packed user-I/O bank mode. It streams a CRC-valid gmpack CMD_CHG_STATUS
 * record for the successful v67 status over CC_CFG_CTRL, using the v63b
 * timing helper, then asserts RECFG. Exactly 27 command/execute bytes.
 *
 * The frame is a source-derived EXPERIMENTAL attempt, NOT a vendor-verified
 * runtime command. Neither this RTL nor the associated Makefile writes flash.
 * It has NO USB DFU recovery if installed as a primary.
 */
`default_nettype none
module top_ulx5m_gs_v68_cfg_runtime_clear_probe #(
    parameter integer RECFG_BITS = 26,
    parameter integer HEARTBEAT_BIT = 22
)(
    input  wire clk25,
    input  wire [3:0] flash_io,
    input  wire flash_cs_n,
    input  wire flash_sck,
    output wire [7:0] led_n
);
    localparam integer CFG_COMMAND_LEN = 27;
    // Source: validated gmpack CMD_CHG_STATUS + execute suffix. Byte 0 is
    // at bits [7:0], because v63b streams COMMAND_BYTES[index*8 +: 8].
    // Payload=1F 10 00 20 04 01 00 00 00 00 00 00, header/data CRCs
    // CRC16/X25 (little-endian) = B8 7E / B1 3B.
    localparam [8*CFG_COMMAND_LEN-1:0] CFG_COMMAND_LE =
        216'h0000000033000000003bb100000000000001042000101f7eb80cdb;

    reg [RECFG_BITS-1:0] start_count = {RECFG_BITS{1'b0}};
    reg [HEARTBEAT_BIT:0] heartbeat = {(HEARTBEAT_BIT+1){1'b0}};
    reg sensor_parity = 1'b0;
    reg recfg = 1'b0;
    reg [2:0] after_stream = 3'b0;
    wire request = &start_count;
    wire cfg_clk, cfg_en, cfg_valid, stream_busy, stream_done, blocked;
    wire [7:0] cfg_data;

    // FLASH INPUTS ONLY. No fabric output enable or SPI writes in this probe.
    always @(posedge clk25) begin
        heartbeat <= heartbeat + 1'b1;
        if (!request)
            start_count <= start_count + 1'b1;
        sensor_parity <= ^{flash_io, flash_cs_n, flash_sck};
        if (stream_done && !recfg) begin
            if (after_stream == 3'd3)
                recfg <= 1'b1;
            else
                after_stream <= after_stream + 1'b1;
        end
    end

    // Reuse the separately tested generic v63b byte-stream timing FSM.
    // The pin inputs never drive the flash; thus spi_released is constant 1.
    ulx5m_cfg_bank_command_stream #(
        .COMMAND_LEN(CFG_COMMAND_LEN),
        .COMMAND_BYTES({{(512-8*CFG_COMMAND_LEN){1'b0}}, CFG_COMMAND_LE})
    ) stream_i (
        .clk(clk25), .rst(1'b0), .request(request),
        .normal_mode(1'b1), .spi_released(1'b1),
        .cfg_clk(cfg_clk), .cfg_en(cfg_en), .cfg_valid(cfg_valid),
        .cfg_data(cfg_data), .busy(stream_busy), .done(stream_done),
        .blocked(blocked)
    );

    CC_CFG_CTRL cfg_i (
        .CLK(cfg_clk), .EN(cfg_en), .DATA(cfg_data),
        .VALID(cfg_valid), .RECFG(recfg)
    );

    // Distinct primary witness from the existing walking-LED secondary:
    // D6 on, D7 heartbeat, D5 input parity, D4 streaming activity.
    assign led_n = {heartbeat[HEARTBEAT_BIT], 1'b1,
                    sensor_parity, stream_busy, 4'b0};
endmodule
`default_nettype wire
