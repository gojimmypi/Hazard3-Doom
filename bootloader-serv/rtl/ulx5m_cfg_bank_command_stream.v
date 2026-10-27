/* GateMate CC_CFG_CTRL byte-stream timing helper, NOT integrated in the ULX5M top.
 *
 * This source contains NO real config-bank command. COMMAND_LEN=0 fails closed.
 * Only a vendor-confirmed, CRC-validated byte sequence can eventually be used.
 * It does not implement CMD_CFGMODE encoding, RECFG, SPI-resume or flash writes.
 *
 * UG1001 section 7.6: EN >=3 clocks before VALID; >=1 idle clock between
 * bytes; EN >=8 clocks following the last VALID. One clock domain is used.
 * The existing v60 SPI-primary configuration/DFU path is NOT modified.
 */
`default_nettype none
module ulx5m_cfg_bank_command_stream #(
    parameter integer COMMAND_LEN = 0,
    parameter [511:0] COMMAND_BYTES = 512'b0
) (
    input  wire clk,
    input  wire rst,
    input  wire request,
    input  wire normal_mode,
    input  wire spi_released,
    output wire cfg_clk,
    output wire cfg_en,
    output wire cfg_valid,
    output wire [7:0] cfg_data,
    output wire busy,
    output wire done,
    output wire blocked
);
    localparam [2:0] S_IDLE    = 3'd0,
                     S_LEAD    = 3'd1,
                     S_BYTE    = 3'd2,
                     S_GAP     = 3'd3,
                     S_TAIL    = 3'd4,
                     S_DONE    = 3'd5,
                     S_BLOCKED = 3'd6;

    reg [2:0] state = S_IDLE;
    reg [6:0] index = 0;
    reg [3:0] count = 0;

    assign cfg_clk = clk;
    assign cfg_en = (state == S_LEAD || state == S_BYTE ||
                     state == S_GAP || state == S_TAIL);
    assign cfg_valid = (state == S_BYTE);
    assign cfg_data = cfg_valid ? COMMAND_BYTES[index * 8 +: 8] : 8'b0;
    assign busy = cfg_en;
    assign done = (state == S_DONE);
    assign blocked = (state == S_BLOCKED);

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            index <= 0;
            count <= 0;
        end else if (cfg_en && (!normal_mode || !spi_released)) begin
            // Safety withdrawal aborts this helper. It cannot undo bytes
            // already accepted by an actual configuration controller.
            state <= S_BLOCKED;
        end else begin
            case (state)
                S_IDLE: if (request) begin
                    if (COMMAND_LEN < 1 || COMMAND_LEN > 64 ||
                        !normal_mode || !spi_released) begin
                        state <= S_BLOCKED;
                    end else begin
                        index <= 0;
                        count <= 0;
                        state <= S_LEAD;
                    end
                end
                S_LEAD: begin
                    if (count == 4'd2) begin
                        count <= 0;
                        state <= S_BYTE;
                    end else begin
                        count <= count + 1'b1;
                    end
                end
                S_BYTE: begin
                    if (index == COMMAND_LEN - 1) begin
                        count <= 0;
                        state <= S_TAIL;
                    end else begin
                        index <= index + 1'b1;
                        state <= S_GAP;
                    end
                end
                S_GAP: state <= S_BYTE;
                S_TAIL: begin
                    if (count == 4'd7) begin
                        state <= S_DONE;
                    end else begin
                        count <= count + 1'b1;
                    end
                end
                S_DONE: state <= S_DONE;
                S_BLOCKED: state <= S_BLOCKED;
                default: state <= S_BLOCKED;
            endcase
        end
    end
endmodule
`default_nettype wire
