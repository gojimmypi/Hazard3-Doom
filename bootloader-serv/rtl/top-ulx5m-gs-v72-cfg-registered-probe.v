/* ULX5M-GS v72: isolated CC_CFG_CTRL registered handoff timing probe.
 *
 * v65/v67 secondary takeover passed on hardware. v66/v68/v70 failed.
 * v70 had the correct TinyDFU-derived command bytes, but used a shorter
 * post-command settle than TinyDFU and combinational stream outputs.
 *
 * Adapted from pu-cc/tinydfu-bootloader/boards/ulx5m/tinydfu_ulx5m.v
 * S_EN/S_SEND/S_NEXT/S_WAIT/S_RECFG sequence. Added eight EN-high tail
 * clocks required by Cologne Chip UG1001 section 7.6 BEFORE S_WAIT.
 * cmd.hex is generated from a packed bitstream, never hand-coded here.
 * This is a NON-DFU test primary. No flash writing logic is present.
 */
`default_nettype none
module top_ulx5m_gs_v72_cfg_registered_probe #(
    parameter integer RECFG_BITS = 26,
    parameter integer HEARTBEAT_BIT = 22
)(
    input  wire clk25,
    input  wire [3:0] flash_io,
    input  wire flash_cs_n,
    input  wire flash_sck,
    output wire [7:0] led_n
);
    localparam integer CMD_LEN = 27;
    localparam S_IDLE = 3'd0,
               S_EN = 3'd1,
               S_SEND = 3'd2,
               S_NEXT = 3'd3,
               S_TAIL = 3'd4,
               S_WAIT = 3'd5,
               S_RECFG = 3'd6;

    reg [7:0] cmd_rom [0:CMD_LEN-1];
    initial $readmemh("build-ulx5m-gs/v72-registered-probe/cmd.hex", cmd_rom);

    reg [RECFG_BITS-1:0] start_count = {RECFG_BITS{1'b0}};
    reg [HEARTBEAT_BIT:0] heartbeat = {(HEARTBEAT_BIT+1){1'b0}};
    reg sensor_parity = 1'b0;
    wire request = &start_count;

    reg [2:0] cfg_state = S_IDLE;
    reg [4:0] cfg_addr = 0;
    reg [3:0] cfg_wait = 0;
    reg cfg_en = 1'b0;
    reg cfg_valid = 1'b0;
    reg [7:0] cfg_data = 8'h00;
    reg recfg = 1'b0;

    // All six shared flash pads are inputs only; never driven by this probe.
    always @(posedge clk25) begin
        heartbeat <= heartbeat + 1'b1;
        if (!request)
            start_count <= start_count + 1'b1;
        sensor_parity <= ^{flash_io, flash_cs_n, flash_sck};

        case (cfg_state)
            S_IDLE: if (request) begin
                cfg_addr <= 0;
                cfg_wait <= 0;
                cfg_state <= S_EN;
            end
            S_EN: begin
                cfg_en <= 1'b1;
                cfg_wait <= cfg_wait + 1'b1;
                if (cfg_wait == 4'd3)
                    cfg_state <= S_SEND;
            end
            S_SEND: begin
                cfg_data <= cmd_rom[cfg_addr];
                cfg_valid <= 1'b1;
                cfg_state <= S_NEXT;
            end
            S_NEXT: begin
                cfg_valid <= 1'b0;
                cfg_addr <= cfg_addr + 1'b1;
                cfg_wait <= 0;
                cfg_state <= (cfg_addr == CMD_LEN - 1) ? S_TAIL : S_SEND;
            end
            // Vendor guide: EN remains asserted for >=8 clocks after VALID.
            S_TAIL: begin
                cfg_wait <= cfg_wait + 1'b1;
                if (cfg_wait == 4'd7) begin
                    cfg_wait <= 0;
                    cfg_state <= S_WAIT;
                end
            end
            // TinyDFU: 16-count quiet period before requesting RECFG.
            S_WAIT: begin
                cfg_en <= 1'b0;
                cfg_wait <= cfg_wait + 1'b1;
                if (&cfg_wait)
                    cfg_state <= S_RECFG;
            end
            S_RECFG: recfg <= 1'b1;
            default: cfg_state <= S_IDLE;
        endcase
    end

    CC_CFG_CTRL cfg_i (
        .CLK(clk25), .EN(cfg_en), .DATA(cfg_data),
        .VALID(cfg_valid), .RECFG(recfg)
    );

    // Primary witness differs from secondary walking LED application.
    assign led_n = {heartbeat[HEARTBEAT_BIT], 1'b1,
                    sensor_parity, cfg_en, 4'b0};
endmodule
`default_nettype wire
