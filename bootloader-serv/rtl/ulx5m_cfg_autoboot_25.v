/* GateMate autonomous SPI-active secondary handoff, independent of PLL0.
 * Preserves the registered 25 MHz CC_CFG_CTRL waveform.
 * normal_mode is a latched, 48 MHz mode-selection signal: synchronize it
 * once into clk25 and hold the request until the fabric reconfigures.
 * No Wishbone traffic and no SPI flash transactions are required here.
 * cmd.hex must be derived from the final gmpack --reconfig --bootaddr image.
 */
`default_nettype none
module ulx5m_cfg_autoboot_25 #(
    parameter integer STARTUP_BITS = 26
)(
    input wire clk25,
    input wire normal_mode,
    output reg release_spi = 1'b0
);
    localparam integer CMD_LEN = 27;
    localparam [2:0] S_IDLE = 3'd0, S_EN = 3'd1,
                     S_SEND = 3'd2, S_NEXT = 3'd3,
                     S_TAIL = 3'd4, S_WAIT = 3'd5,
                     S_RECFG = 3'd6;

    reg [7:0] cmd_rom [0:CMD_LEN-1];
    initial $readmemh("build-ulx5m-gs/bootloader/cmd.hex", cmd_rom);


    (* async_reg = "true" *) reg normal_meta = 1'b0;
    (* async_reg = "true" *) reg normal_sync = 1'b0;
    reg requested = 1'b0;
    reg [STARTUP_BITS-1:0] startup_count = 0;
    reg [2:0] cfg_state = S_IDLE;
    reg [4:0] cfg_addr = 0;
    reg [3:0] cfg_wait = 0;
    reg cfg_en = 1'b0;
    reg cfg_valid = 1'b0;
    reg [7:0] cfg_data = 8'h00;
    reg cfg_recfg = 1'b0;

    // A one-hot ROM decode avoids a deep variable-indexed memory mux.
    // The 27 bytes still come from the packed-image-derived cmd.hex.
    wire [CMD_LEN-1:0] cmd_select;
    wire [7:0] cmd_lookup;
    genvar byte_index, bit_index;
    generate
        for (byte_index = 0; byte_index < CMD_LEN; byte_index = byte_index + 1) begin : g_cmd_decode
            assign cmd_select[byte_index] = (cfg_addr == byte_index);
        end
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin : g_cmd_bit
            wire [CMD_LEN-1:0] selected_bits;
            for (byte_index = 0; byte_index < CMD_LEN; byte_index = byte_index + 1) begin : g_cmd_word
                assign selected_bits[byte_index] = cmd_rom[byte_index][bit_index] & cmd_select[byte_index];
            end
            assign cmd_lookup[bit_index] = |selected_bits;
        end
    endgenerate

    always @(posedge clk25) begin
        normal_meta <= normal_mode;
        normal_sync <= normal_meta;
        // Once the settled startup selection is normal, remain autonomous.
        // Loss of PLL0 or its reset after CHG_STATUS must not stop this FSM.
        if (normal_sync)
            requested <= 1'b1;
        if (requested && !(&startup_count))
            startup_count <= startup_count + 1'b1;

        case (cfg_state)
            S_IDLE: if (requested && (&startup_count)) begin
                release_spi <= 1'b1;
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
                cfg_data <= cmd_lookup;
                cfg_valid <= 1'b1;
                cfg_state <= S_NEXT;
            end
            S_NEXT: begin
                cfg_valid <= 1'b0;
                cfg_addr <= cfg_addr + 1'b1;
                cfg_wait <= 0;
                cfg_state <= (cfg_addr == CMD_LEN - 1) ? S_TAIL : S_SEND;
            end
            S_TAIL: begin
                cfg_wait <= cfg_wait + 1'b1;
                if (cfg_wait == 4'd7) begin
                    cfg_wait <= 0;
                    cfg_state <= S_WAIT;
                end
            end
            S_WAIT: begin
                cfg_en <= 1'b0;
                cfg_wait <= cfg_wait + 1'b1;
                if (&cfg_wait)
                    cfg_state <= S_RECFG;
            end
            S_RECFG: cfg_recfg <= 1'b1;
            default: cfg_state <= S_IDLE;
        endcase
    end

    CC_CFG_CTRL cfg_i (
        .CLK(clk25), .EN(cfg_en), .DATA(cfg_data),
        .VALID(cfg_valid), .RECFG(cfg_recfg)
    );
endmodule
`default_nettype wire
