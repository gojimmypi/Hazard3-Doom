`timescale 1ns/1ps
`default_nettype none
module CC_TOBUF #(parameter V_IO = "UNDEFINED") (
    input wire A, T, output wire O
);
    assign O = T ? 1'bz : A;
endmodule
module CC_IOBUF #(parameter V_IO = "UNDEFINED", PULLUP = 0, PULLDOWN = 0) (
    input wire A, T, output wire Y, inout wire IO
);
    assign IO = T ? 1'bz : A;
    assign Y = IO;
endmodule
module tb_ulx5m_v60_spi_release;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1;
    reg release_to_config = 0;
    reg [3:0] spi_io_o = 4'b1010;
    reg [3:0] spi_io_t = 4'b0000;
    reg spi_sck_o = 1;
    reg [0:0] spi_cs_o = 0;
    tri [3:0] spi_io;
    tri [0:0] spi_cs;
    tri spi_sck;
    wire [3:0] spi_io_i;
    qspi_phy_gatemate #(.N_CS(1)) dut (
        .spi_io(spi_io), .spi_cs(spi_cs), .spi_sck(spi_sck),
        .spi_io_i(spi_io_i), .spi_io_o(spi_io_o), .spi_io_t(spi_io_t),
        .spi_sck_o(spi_sck_o), .spi_cs_o(spi_cs_o),
        .release_to_config(release_to_config), .clk(clk), .rst(rst)
    );
    initial begin
        repeat (3) @(negedge clk);
        rst = 0;
        repeat (3) @(negedge clk);
        #1;
        if (spi_cs !== 1'b0 || spi_sck !== 1'b1 || spi_io !== 4'b1010)
            $fatal(1, "Normal SPI pad drive altered");
        release_to_config = 1;
        #1;
        if (spi_cs !== 1'bz || spi_sck !== 1'bz || spi_io !== 4'bzzzz)
            $fatal(1, "Shared SPI pads remain driven during RECFG");
        release_to_config = 0;
        #1;
        if (spi_cs !== 1'b0 || spi_sck !== 1'b1 || spi_io !== 4'b1010)
            $fatal(1, "SPI pad drive failed to return");
        $display("[PASS] v60 CS/SCK/D0..D3 high-Z and normal drive");
        $finish;
    end
endmodule
`default_nettype wire
