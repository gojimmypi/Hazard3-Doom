/* Simulation-only GateMate CC_CFG_CTRL protocol sequencer.
 * DO NOT instantiate in the ULX5M hardware top level.
 * Outputs are an observation model, NOT connected to CC_CFG_CTRL.
 * No SPI or flash write interface exists in this module.
 * External authorization and full stream validation are NOT implemented.
 */
`default_nettype none
module ulx5m_cfg_handoff_model #(
    parameter integer READ_TIMEOUT = 16,
    parameter [31:0] MAX_BYTES = 32'd4194304
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire        mode_valid,
    input  wire        dfu_selected,
    input  wire        integrity_ok,
    input  wire        format_verified,
    input  wire        policy_authorized,
    input  wire        spi_exclusive,
    input  wire [31:0] image_bytes,
    input  wire [7:0]  read_data,
    input  wire        read_valid,
    input  wire        read_error,
    output wire        read_request,
    output wire [7:0]  cfg_data_model,
    output wire        cfg_en_model,
    output wire        cfg_valid_model,
    output wire        cfg_recfg_model,
    output wire        busy,
    output wire        done,
    output wire        failed,
    output wire        usb_quiesce_model
);
    localparam [2:0] S_IDLE  = 3'd0,
                     S_LEAD  = 3'd1,
                     S_FETCH = 3'd2,
                     S_PULSE = 3'd3,
                     S_GAP   = 3'd4,
                     S_TAIL  = 3'd5,
                     S_DONE  = 3'd6,
                     S_FAIL  = 3'd7;
    reg [2:0] state = S_IDLE;
    reg [3:0] hold_count = 4'd0;
    reg [31:0] wait_count = 32'd0;
    reg [31:0] sent_bytes = 32'd0;
    reg [31:0] target_bytes = 32'd0;
    reg [7:0] data_q = 8'd0;

    wire active = (state == S_LEAD || state == S_FETCH ||
                   state == S_PULSE || state == S_GAP || state == S_TAIL);
    wire prerequisites = mode_valid && !dfu_selected && integrity_ok &&
                         format_verified && policy_authorized && spi_exclusive;

    assign cfg_data_model = data_q;
    assign cfg_en_model = active;
    assign cfg_valid_model = (state == S_PULSE);
    assign cfg_recfg_model = active;
    assign read_request = (state == S_FETCH);
    assign busy = active;
    assign done = (state == S_DONE);
    assign failed = (state == S_FAIL);
    /* A normal-mode path must not inadvertently attach DFU over USB. */
    assign usb_quiesce_model = !(mode_valid && dfu_selected);

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            hold_count <= 4'd0;
            wait_count <= 32'd0;
            sent_bytes <= 32'd0;
            target_bytes <= 32'd0;
            data_q <= 8'd0;
        end else if (active && !prerequisites) begin
            /* This is a simulation abort only. Once actual bytes have been
             * sent to hardware, returning to DFU is NOT guaranteed. */
            state <= S_FAIL;
        end else begin
            case (state)
                S_IDLE: if (start) begin
                    if (!prerequisites || image_bytes == 0 ||
                        image_bytes > MAX_BYTES || READ_TIMEOUT < 1) begin
                        state <= S_FAIL;
                    end else begin
                        target_bytes <= image_bytes;
                        sent_bytes <= 32'd0;
                        hold_count <= 4'd0;
                        wait_count <= 32'd0;
                        state <= S_LEAD;
                    end
                end
                S_LEAD: begin
                    /* EN stays high for 3 full clock edges before VALID. */
                    if (hold_count == 4'd2) begin
                        hold_count <= 4'd0;
                        state <= S_FETCH;
                    end else begin
                        hold_count <= hold_count + 1'b1;
                    end
                end
                S_FETCH: begin
                    if (read_error) begin
                        state <= S_FAIL;
                    end else if (read_valid) begin
                        data_q <= read_data;
                        wait_count <= 32'd0;
                        state <= S_PULSE;
                    end else if (wait_count >= READ_TIMEOUT - 1) begin
                        state <= S_FAIL;
                    end else begin
                        wait_count <= wait_count + 1'b1;
                    end
                end
                S_PULSE: begin
                    sent_bytes <= sent_bytes + 1'b1;
                    if (sent_bytes + 1'b1 == target_bytes) begin
                        hold_count <= 4'd0;
                        state <= S_TAIL;
                    end else begin
                        state <= S_GAP;
                    end
                end
                S_GAP: state <= S_FETCH;
                S_TAIL: begin
                    /* EN remains high for at least 8 clocks after VALID. */
                    if (hold_count == 4'd7) begin
                        state <= S_DONE;
                    end else begin
                        hold_count <= hold_count + 1'b1;
                    end
                end
                S_DONE: state <= S_DONE;
                S_FAIL: state <= S_FAIL;
                default: state <= S_FAIL;
            endcase
        end
    end
endmodule
`default_nettype wire
