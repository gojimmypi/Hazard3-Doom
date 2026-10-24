/* GateMate configuration byte stream, isolated normal-mode experiment.
 * Default build cannot assert CC_CFG_CTRL. Firmware writes are rejected
 * unless an explicitly compiled, recovery-qualified build enables it.
 */
`default_nettype none
module ulx5m_cfg_stream_wb (
    input wire clk, rst,
    input wire normal_mode, spi_idle,
    input wire [2:0] bus_addr,
    input wire [31:0] bus_wdata,
    output reg [31:0] bus_rdata = 32'd0,
    input wire bus_cyc, bus_we,
    output reg bus_ack = 1'b0
);
`ifdef ULX5M_ENABLE_CFG_STREAM
    localparam [2:0] IDLE=0, LEAD=1, READY=2, PULSE=3,
                     GAP=4, TAIL=5, DONE=6, ERROR=7;
    localparam [31:0] ARM_KEY = 32'h43464731; // "CFG1"
    localparam [31:0] FINISH_KEY = 32'h454e4431; // "END1"
    localparam [31:0] ABORT_KEY = 32'h41425431; // "ABT1"
    localparam [31:0] MAX_STREAM = 32'd2096896;
    reg [2:0] state = IDLE;
    reg [3:0] delay_cycles = 4'd0;
    reg [31:0] expected = 32'd0, sent = 32'd0;
    reg [2:0] idle_cycles = 3'd0;
    reg en = 1'b0, valid = 1'b0;
    reg [7:0] data = 8'd0;
`ifdef ULX5M_ENABLE_CFG_STREAM
    localparam CAPABLE = 1'b1;
    // This primitive MUST remain absent from the default/proven bitstream.
    CC_CFG_CTRL cfg_i (
        .CLK(clk), .EN(en), .VALID(valid), .RECFG(1'b1), .DATA(data)
    );
`else
    localparam CAPABLE = 1'b0;
`endif
    wire write_req = bus_cyc && !bus_ack && bus_we;
    wire read_req = bus_cyc && !bus_ack && !bus_we;
    wire [31:0] status = {sent[23:0], 3'b000, CAPABLE,
                          state == ERROR, state == DONE,
                          state != IDLE && state != DONE && state != ERROR,
                          state == READY && idle_cycles >= 3'd3 && spi_idle};

    always @(posedge clk) begin
        if (rst || !normal_mode) begin
            state <= IDLE;
            expected <= 32'd0;
            sent <= 32'd0;
            delay_cycles <= 4'd0;
            idle_cycles <= 3'd0;
            en <= 1'b0;
            valid <= 1'b0;
            data <= 8'd0;
            bus_ack <= 1'b0;
            bus_rdata <= 32'd0;
        end else begin
            bus_ack <= bus_cyc && !bus_ack;
            valid <= 1'b0;
            if (spi_idle) begin
                if (idle_cycles != 3'd7)
                    idle_cycles <= idle_cycles + 1'b1;
            end else begin
                idle_cycles <= 3'd0;
            end
            // Flash reads between configuration bytes are expected.
            // Prevent a VALID pulse while SPI chip-select is asserted;
            // there is no rollback once the controller accepts bytes.
            case (state)
                LEAD: if (delay_cycles == 0)
                    state <= READY;
                else delay_cycles <= delay_cycles - 1'b1;
                PULSE: if (spi_idle) begin
                    valid <= 1'b1;
                    state <= GAP;
                end else begin
                    valid <= 1'b0;
                    en <= 1'b0;
                    state <= ERROR;
                end
                GAP: state <= READY;
                TAIL: if (delay_cycles == 0) begin
                    en <= 1'b0;
                    state <= DONE;
                end else delay_cycles <= delay_cycles - 1'b1;
                default: ;
            endcase
            if (read_req) begin
                case (bus_addr)
                    0: bus_rdata <= status;
                    1: bus_rdata <= expected;
                    2: bus_rdata <= sent;
                    default: bus_rdata <= 32'd0;
                endcase
            end
            if (write_req && !(state == PULSE && !spi_idle)) begin
                case (bus_addr)
                    1: if (state == IDLE && bus_wdata != 0 &&
                           bus_wdata <= MAX_STREAM)
                           expected <= bus_wdata;
                       else begin
                           state <= ERROR;
                           en <= 1'b0;
                           valid <= 1'b0;
                       end
                    2: if (bus_wdata == ABORT_KEY) begin
                           // Abort is not rollback of already accepted bytes.
                           state <= ERROR;
                           en <= 1'b0;
                           valid <= 1'b0;
                       end else if (bus_wdata == ARM_KEY && state == IDLE &&
                                    CAPABLE && expected != 0 && spi_idle &&
                                    idle_cycles >= 3'd3) begin
                           sent <= 0;
                           en <= 1'b1;
                           delay_cycles <= 4'd4;
                           state <= LEAD;
                       end else if (bus_wdata == FINISH_KEY && state == READY &&
                                    sent == expected && idle_cycles >= 3'd3 &&
                                    spi_idle) begin
                           delay_cycles <= 4'd9;
                           state <= TAIL;
                       end else begin
                           state <= ERROR;
                           en <= 1'b0;
                       end
                    3: if (state == READY && sent < expected &&
                           idle_cycles >= 3'd3 && spi_idle) begin
                           data <= bus_wdata[7:0];
                           sent <= sent + 1'b1;
                           state <= PULSE;
                       end else begin
                           state <= ERROR;
                           en <= 1'b0;
                       end
                    default: begin
                        state <= ERROR;
                        en <= 1'b0;
                    end
                endcase
            end
        end
    end
`else
    // Default build: no configuration commands or byte streaming hardware.
    // Reject all writes. Preserve the Wishbone ACK and error status contract.
    localparam [2:0] IDLE = 3'd0, ERROR = 3'd7;
    reg [2:0] state = IDLE;
    wire [2:0] idle_cycles = 3'd0; // Testbench compatibility; no pacing here.
    wire en = 1'b0, valid = 1'b0;
    wire [7:0] data = 8'd0;
    wire write_req = bus_cyc && !bus_ack && bus_we;
    wire read_req = bus_cyc && !bus_ack && !bus_we;
    always @(posedge clk) begin
        if (rst || !normal_mode) begin
            state <= IDLE;
            bus_ack <= 1'b0;
            bus_rdata <= 32'd0;
        end else begin
            bus_ack <= bus_cyc && !bus_ack;
            if (write_req)
                state <= ERROR;
            if (read_req)
                bus_rdata <= (bus_addr == 3'd0 && state == ERROR) ?
                             32'h00000008 : 32'd0;
        end
    end
`endif
endmodule
`default_nettype wire
