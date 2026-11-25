/*
 * Initial GateMate QSPI data-pad PHY for the ULX5M-GS.
 * This module is not a validated configuration-flash interface.
 * In particular, access to dedicated configuration pads must be verified.
 */
`default_nettype none

module qspi_phy_gatemate #(
    parameter integer N_CS = 1
)(
    inout  wire [3:0] spi_io,
    inout  wire [N_CS-1:0] spi_cs,
    output wire spi_sck,
    output reg  [3:0] spi_io_i,
    input  wire [3:0] spi_io_o,
    input  wire [3:0] spi_io_t,
    input  wire spi_sck_o,
    input  wire [N_CS-1:0] spi_cs_o,
    input  wire release_to_config,
    input  wire clk,
    input  wire rst
);
    reg [3:0] io_out;
    reg [3:0] io_tristate;
    reg [N_CS-1:0] cs_out;
    reg sck_out;

    wire [3:0] io_in;
    genvar i;
    generate for (i = 0; i < 4; i = i + 1) begin : g_io
        CC_IOBUF #(.V_IO("1.8"), .PULLUP(1'b0), .PULLDOWN(1'b0)) pad_i (
            .IO(spi_io[i]), .A(io_out[i]), .T(io_tristate[i] | release_to_config), .Y(io_in[i])
        );
    end endgenerate
    // Dedicated configuration flash pins must stop being fabric outputs
    // BEFORE CC_CFG_CTRL.RECFG requests an SPI-active reread.
    genvar j;
    generate for (j = 0; j < N_CS; j = j + 1) begin : g_cs
        CC_TOBUF #(.V_IO("1.8")) cs_pad_i (
            .A(cs_out[j]), .T(release_to_config), .O(spi_cs[j])
        );
    end endgenerate
    CC_TOBUF #(.V_IO("1.8")) sck_pad_i (
        .A(sck_out), .T(release_to_config), .O(spi_sck)
    );

    always @(posedge clk) begin
        if (rst) begin
            io_out <= 4'b0000;
            io_tristate <= 4'b1111;
            cs_out <= {N_CS{1'b1}};
            sck_out <= 1'b0;
            spi_io_i <= 4'b0000;
        end else begin
            io_out <= spi_io_o;
            io_tristate <= spi_io_t;
            cs_out <= spi_cs_o;
            sck_out <= spi_sck_o;
            spi_io_i <= io_in;
        end
    end
endmodule

`default_nettype wire
