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
    input  wire clk,
    input  wire rst
);
    reg [3:0] io_out;
    reg [3:0] io_tristate;
    reg [N_CS-1:0] cs_out;
    reg sck_out;

    genvar i;
    generate for (i = 0; i < 4; i = i + 1) begin : g_io
        assign spi_io[i] = io_tristate[i] ? 1'bz : io_out[i];
    end endgenerate
    assign spi_cs = cs_out;
    assign spi_sck = sck_out;

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
            spi_io_i <= spi_io;
        end
    end
endmodule

`default_nettype wire
