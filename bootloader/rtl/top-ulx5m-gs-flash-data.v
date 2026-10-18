/*
 * ULX5M-GS V005: standalone 25 MHz SPI flash content-read diagnostic.
 * JTAG SRAM configuration only. No PicoRV32, USB PHY or flash writes.
 * Reads 32 bytes at address 0x000000 using one SPI 0x03 transaction.
 */
`default_nettype none

module ulx5m_flash_data_reader #(
    parameter integer STARTUP_BITS = 16,
    parameter integer BTN_SAMPLE_BITS = 18
)(
    input  wire clk,
    input  wire rst,
    input  wire btn_next_n,
    input  wire btn_index_n,
    input  wire miso,
    output reg  sck = 1'b0,
    output reg  cs_n = 1'b1,
    output reg  mosi = 1'b1,
    output wire [7:0] display,
    output reg  done = 1'b0,
    output reg  [4:0] byte_index = 5'd0
);
    localparam [1:0] ST_WAIT = 2'd0, ST_SHIFT = 2'd1, ST_DONE = 2'd2;
    localparam integer HEADER_BITS = 32; // opcode + 24-bit address
    localparam integer DATA_BYTES = 32;
    localparam integer TOTAL_BITS = HEADER_BITS + DATA_BYTES * 8;

    reg [1:0] state = ST_WAIT;
    reg [STARTUP_BITS-1:0] startup_count = 0;
    reg [8:0] bit_count = 0;
    reg [1:0] phase = 0;
    reg sampled_miso = 0;
    reg [7:0] byte_shift = 0;
    reg [7:0] flash_bytes [0:DATA_BYTES-1];
    integer i;

    // SPI mode 0. The opcode is 0x03, the 24-bit address is 0x000000,
    // and the following 256 clocks read 32 bytes. SCK is 6.25 MHz.
    always @(posedge clk) begin
        if (rst) begin
            state <= ST_WAIT;
            startup_count <= 0;
            bit_count <= 0;
            phase <= 0;
            sampled_miso <= 0;
            byte_shift <= 0;
            cs_n <= 1'b1;
            sck <= 1'b0;
            mosi <= 1'b1;
            done <= 1'b0;
            for (i = 0; i < DATA_BYTES; i = i + 1)
                flash_bytes[i] <= 8'h00;
        end else case (state)
            ST_WAIT: begin
                if (&startup_count) begin
                    cs_n <= 1'b0;
                    state <= ST_SHIFT;
                end else begin
                    startup_count <= startup_count + 1'b1;
                end
            end
            ST_SHIFT: begin
                case (phase)
                    2'd0: begin
                        // Only the 0x03 READ opcode and zero address are sent.
                        mosi <= (bit_count < 8) ?
                            ((8'h03 >> (7 - bit_count[2:0])) & 1'b1) : 1'b0;
                        phase <= 2'd1;
                    end
                    2'd1: begin
                        sck <= 1'b1;
                        phase <= 2'd2;
                    end
                    2'd2: begin
                        sampled_miso <= miso;
                        phase <= 2'd3;
                    end
                    2'd3: begin
                        sck <= 1'b0;
                        if (bit_count >= HEADER_BITS) begin
                            byte_shift <= {byte_shift[6:0], sampled_miso};
                            if (bit_count[2:0] == 3'd7)
                                flash_bytes[(bit_count - HEADER_BITS) >> 3] <=
                                    {byte_shift[6:0], sampled_miso};
                        end
                        if (bit_count == TOTAL_BITS - 1) begin
                            cs_n <= 1'b1;
                            done <= 1'b1;
                            state <= ST_DONE;
                        end else begin
                            bit_count <= bit_count + 1'b1;
                            phase <= 2'd0;
                        end
                    end
                endcase
            end
            default: begin
                // Leave CS high and SCK low; never issue another command.
            end
        endcase
    end

    // BTN1 advances the byte offset (0..31); BTN2 displays that offset.
    // BTN1 is sampled at about 95 Hz for mechanical debounce.
    reg btn_meta = 1'b1;
    reg btn_sync = 1'b1;
    reg btn_prev = 1'b1;
    reg [BTN_SAMPLE_BITS-1:0] btn_count = 0;
    always @(posedge clk) begin
        if (rst) begin
            btn_meta <= 1'b1;
            btn_sync <= 1'b1;
            btn_prev <= 1'b1;
            btn_count <= 0;
            byte_index <= 0;
        end else begin
            btn_meta <= btn_next_n;
            btn_sync <= btn_meta;
            btn_count <= btn_count + 1'b1;
            if (&btn_count) begin
                if (btn_prev && !btn_sync)
                    byte_index <= byte_index + 1'b1;
                btn_prev <= btn_sync;
            end
        end
    end

    assign display = !done ? (state == ST_WAIT ? 8'h55 : 8'haa) :
                     !btn_index_n ? (8'h80 | {3'b000, byte_index}) :
                                    flash_bytes[byte_index];
endmodule

module top_ulx5m_gs_flash_data (
    input  wire clk25,
    input  wire btn0_n,
    input  wire btn1_n,
    output wire [7:0] led_n,
    inout  wire [3:0] flash_io,
    output wire flash_cs_n,
    output wire flash_sck
);
    wire clk_ref, clk_global, usr_rstn;
    CC_IBUF #(.PIN_NAME("IO_SB_A8"), .V_IO("1.8")) clk_buf_i (
        .I(clk25), .Y(clk_ref)
    );
    CC_BUFG bufg_i (.I(clk_ref), .O(clk_global));
    CC_USR_RSTN config_reset_i (.USR_RSTN(usr_rstn));
    reg [2:0] reset_release = 3'b000;
    always @(posedge clk_global or negedge usr_rstn) begin
        if (!usr_rstn)
            reset_release <= 3'b000;
        else
            reset_release <= {reset_release[1:0], 1'b1};
    end
    wire reset = !reset_release[2];

    wire spi_mosi, spi_miso;
    wire [7:0] led_phys;
    wire unused_done;
    wire [4:0] unused_index;

    ulx5m_flash_data_reader reader_i (
        .clk(clk_global), .rst(reset),
        .btn_next_n(btn0_n), .btn_index_n(btn1_n),
        .miso(spi_miso), .sck(flash_sck), .cs_n(flash_cs_n),
        .mosi(spi_mosi), .display(led_phys), .done(unused_done),
        .byte_index(unused_index)
    );

    CC_IOBUF #(.V_IO("1.8"), .PULLUP(1'b0), .PULLDOWN(1'b0)) io0 (
        .IO(flash_io[0]), .A(spi_mosi), .T(1'b0), .Y()
    );
    CC_IOBUF #(.V_IO("1.8"), .PULLUP(1'b0), .PULLDOWN(1'b0)) io1 (
        .IO(flash_io[1]), .A(1'b0), .T(1'b1), .Y(spi_miso)
    );
    // Hold WP_N (IO2) and HOLD_N (IO3) high throughout single-bit READ.
    CC_IOBUF #(.V_IO("1.8"), .PULLUP(1'b0), .PULLDOWN(1'b0)) io2 (
        .IO(flash_io[2]), .A(1'b1), .T(1'b0), .Y()
    );
    CC_IOBUF #(.V_IO("1.8"), .PULLUP(1'b0), .PULLDOWN(1'b0)) io3 (
        .IO(flash_io[3]), .A(1'b1), .T(1'b0), .Y()
    );

    // Physical V005 LEDs are active-high; retain known pin permutations.
    assign led_n[3:0] = led_phys[3:0];
    assign led_n[4] = led_phys[5];
    assign led_n[5] = led_phys[4];
    assign led_n[6] = led_phys[7];
    assign led_n[7] = led_phys[6];
endmodule
`default_nettype wire
