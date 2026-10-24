/* ULX5M-GS standalone volatile configuration handoff experiment.
 * Deliberately isolated from SERV, USB and external SPI flash.
 * Holding PCB BTN3 starts ONE internal configuration stream from BRAM.
 * This may stop executing mid-stream if GateMate replaces this fabric.
 * All failures must be recovered via cold-start JTAG/SPI boot selection.
 */
`default_nettype none
module top_ulx5m_gs_cfg_probe #(
    parameter integer HOLD_BITS = 22
) (
    input wire clk25,
    input wire btn3_n,
    output wire [7:0] led_n
);
    `ifdef ULX5M_CFG_PROBE_DEST_RESET_RECONFIG
    localparam integer IMAGE_BYTES = 3033;
`else
    localparam integer IMAGE_BYTES = 3026;
`endif
    localparam [2:0] WAIT_BUTTON = 0, LEAD = 1, FETCH = 2,
                     GAP = 3, PULSE = 4, ADVANCE = 5,
                     TAIL = 6, FINISHED = 7;
    reg [7:0] image_rom [0:IMAGE_BYTES-1];
`ifdef ULX5M_CFG_PROBE_DEST_RESET_RECONFIG
    initial $readmemh("build-ulx5m-gs/cfg-probe-dest-reset-reconfig/walking-led-reset-reconfig.hex", image_rom);
`elsif ULX5M_CFG_PROBE_DEST_RECONFIG
    initial $readmemh("build-ulx5m-gs/cfg-probe-dest-reconfig/walking-led-reconfig.hex", image_rom);
`else
    initial $readmemh("build-ulx5m-gs/cfg-probe/walking-led.hex", image_rom);
`endif

    (* async_reg = "true" *) reg btn3_meta = 1'b1;
    (* async_reg = "true" *) reg btn3_sync = 1'b1;
    reg [2:0] state = WAIT_BUTTON;
    reg [HOLD_BITS-1:0] hold_counter = 0;
    reg [HOLD_BITS-1:0] release_counter = 0;
    reg button_armed = 1'b0;
    reg [3:0] cycle_counter = 0;
    reg [11:0] byte_index = 0;
    reg [7:0] data = 0;
    reg en = 0;
    reg valid = 0;
    reg [25:0] heartbeat = 0;

    CC_CFG_CTRL cfg_i (
        .CLK(clk25), .EN(en), .VALID(valid), .RECFG(1'b1), .DATA(data)
    );

    always @(posedge clk25) begin
        heartbeat <= heartbeat + 1'b1;
        btn3_meta <= btn3_n;
        btn3_sync <= btn3_meta;
        if (!btn3_sync) begin
            release_counter <= 0;
            if (!(&hold_counter))
                hold_counter <= hold_counter + 1'b1;
        end else begin
            hold_counter <= 0;
            if (!(&release_counter))
                release_counter <= release_counter + 1'b1;
            if (&release_counter)
                button_armed <= 1'b1;
        end
        valid <= 1'b0;
        case (state)
            WAIT_BUTTON: if (button_armed && !btn3_sync && (&hold_counter)) begin
                // No automatic configuration at power-on.
                en <= 1'b1;
                cycle_counter <= 0;
                byte_index <= 0;
                state <= LEAD;
            end
            LEAD: if (cycle_counter == 4'd3)
                state <= FETCH;
            else cycle_counter <= cycle_counter + 1'b1;
            FETCH: begin
                data <= image_rom[byte_index];
                state <= GAP;
            end
            GAP: state <= PULSE;
            PULSE: begin
                valid <= 1'b1;
                state <= ADVANCE;
            end
            ADVANCE: if (byte_index == IMAGE_BYTES - 1) begin
                cycle_counter <= 0;
                state <= TAIL;
            end else begin
                byte_index <= byte_index + 1'b1;
                state <= FETCH;
            end
            TAIL: if (cycle_counter == 4'd8) begin
                en <= 1'b0;
                state <= FINISHED;
            end else cycle_counter <= cycle_counter + 1'b1;
            default: ;
        endcase
    end

    // V005 pads are active high. If full reconfiguration succeeds,
    // these LEDs should be replaced by the walking-LED application.
    assign led_n = {heartbeat[25], 1'b0, state == FINISHED,
                    en, valid, !btn3_sync, state == WAIT_BUTTON, 1'b0};
endmodule
`default_nettype wire
