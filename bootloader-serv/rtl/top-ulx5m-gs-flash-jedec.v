/*
 * ULX5M-GS V005: standalone 25 MHz, read-only SPI JEDEC ID diagnostic.
 * JTAG SRAM configuration only. No PicoRV32, USB PHY or flash writes.
 * Configuration SPI IO pins are reused as 1.8 V GPIO after JTAG load.
 */
`default_nettype none

module ulx5m_flash_jedec_reader #(
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
    output reg  [23:0] jedec_id = 24'h000000,
    output reg  [1:0] byte_index = 2'd0
);
    localparam [1:0] ST_WAIT = 2'd0, ST_SHIFT = 2'd1, ST_DONE = 2'd2;
    reg [1:0] state = ST_WAIT;
    reg [STARTUP_BITS-1:0] startup_count = 0;
    reg [5:0] bit_count = 0;
    reg [1:0] phase = 0;
    reg sampled_miso = 0;

    // In SPI mode 0, drive MOSI while SCK is low; sample after rising SCK.
    // Four 25 MHz cycles per bit: 6.25 MHz SPI clock.
    always @(posedge clk) begin
        if (rst) begin
            state <= ST_WAIT;
            startup_count <= 0;
            bit_count <= 0;
            phase <= 0;
            sampled_miso <= 0;
            cs_n <= 1'b1;
            sck <= 1'b0;
            mosi <= 1'b1;
            jedec_id <= 0;
            done <= 1'b0;
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
                        // Send 0x9f, then 24 dummy bits to clock out the ID.
                        mosi <= (bit_count < 8) ? ((8'h9f >> (7 - bit_count[2:0])) & 1'b1) : 1'b0;
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
                        if (bit_count >= 8)
                            jedec_id <= {jedec_id[22:0], sampled_miso};
                        if (bit_count == 31) begin
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
                // Hold SCK low, CS high; no additional flash commands.
            end
        endcase
    end

    // BTN1 advances the displayed JEDEC byte; BTN2 shows the byte index.
    // Sample BTN1 at about 95 Hz to suppress mechanical bounce.
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
                if (btn_prev && !btn_sync) begin
                    if (byte_index == 2'd2)
                        byte_index <= 2'd0;
                    else
                        byte_index <= byte_index + 1'b1;
                end
                btn_prev <= btn_sync;
            end
        end
    end

    wire [7:0] selected_byte = byte_index == 2'd0 ? jedec_id[23:16] :
                                byte_index == 2'd1 ? jedec_id[15:8] :
                                                     jedec_id[7:0];
    assign display = !done ? (state == ST_WAIT ? 8'h55 : 8'haa) :
                     !btn_index_n ? (8'h80 | (8'h01 << byte_index)) :
                                    selected_byte;
endmodule

module top_ulx5m_gs_flash_jedec (
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
    wire [23:0] unused_id;
    wire [1:0] unused_index;

    ulx5m_flash_jedec_reader reader_i (
        .clk(clk_global), .rst(reset),
        .btn_next_n(btn0_n), .btn_index_n(btn1_n),
        .miso(spi_miso), .sck(flash_sck), .cs_n(flash_cs_n),
        .mosi(spi_mosi), .display(led_phys), .done(unused_done),
        .jedec_id(unused_id), .byte_index(unused_index)
    );

    CC_IOBUF #(.V_IO("1.8"), .PULLUP(1'b0), .PULLDOWN(1'b0)) io0 (
        .IO(flash_io[0]), .A(spi_mosi), .T(1'b0), .Y()
    );
    CC_IOBUF #(.V_IO("1.8"), .PULLUP(1'b0), .PULLDOWN(1'b0)) io1 (
        .IO(flash_io[1]), .A(1'b0), .T(1'b1), .Y(spi_miso)
    );
    // WP_N and HOLD_N must remain high for a single-bit SPI READ ID.
    CC_IOBUF #(.V_IO("1.8"), .PULLUP(1'b0), .PULLDOWN(1'b0)) io2 (
        .IO(flash_io[2]), .A(1'b1), .T(1'b0), .Y()
    );
    CC_IOBUF #(.V_IO("1.8"), .PULLUP(1'b0), .PULLDOWN(1'b0)) io3 (
        .IO(flash_io[3]), .A(1'b1), .T(1'b0), .Y()
    );

    // Physical V005 LEDs are active-high. Preserve observed D4/D5 and
    // D6/D7 pin permutations so displayed bytes use physical D0..D7 bits.
    assign led_n[3:0] = led_phys[3:0];
    assign led_n[4] = led_phys[5];
    assign led_n[5] = led_phys[4];
    assign led_n[6] = led_phys[7];
    assign led_n[7] = led_phys[6];
endmodule
`default_nettype wire
