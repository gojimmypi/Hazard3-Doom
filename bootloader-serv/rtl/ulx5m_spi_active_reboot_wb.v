/* GateMate SPI-active secondary boot request (Project Peppercorn test 128).
 * This is NOT a configuration byte streamer. CC_CFG_CTRL.RECFG requests
 * an automatic reread from the --bootaddr recorded in the PRIMARY image.
 * The primary image MUST have been loaded from SPI-active mode. A JTAG
 * SRAM load cannot qualify this path. This module never writes flash.
 */
`default_nettype none
module ulx5m_spi_active_reboot_wb (
    input wire clk, rst,
    input wire normal_mode, spi_idle,
    input wire [2:0] bus_addr,
    input wire [31:0] bus_wdata,
    output reg [31:0] bus_rdata = 32'd0,
    input wire bus_cyc, bus_we,
    output reg bus_ack = 1'b0,
    output reg release_spi = 1'b0
);
    localparam [31:0] ARM_KEY = 32'h41524d31; /* ARM1 */
    localparam [31:0] BOOT_KEY = 32'h424f4f54; /* BOOT */
    reg [4:0] spi_idle_cycles = 0;
    reg armed = 1'b0;
    reg fired = 1'b0;
    reg error = 1'b0;
    reg recfg = 1'b0;
    reg handoff_pending = 1'b0;
    wire qualified = normal_mode && spi_idle && (&spi_idle_cycles);
    wire write_req = bus_cyc && !bus_ack && bus_we;
    wire read_req = bus_cyc && !bus_ack && !bus_we;

    // Vendor reference 128-secondary-bootaddr: only RECFG is used.
    // DATA, CLK, EN and VALID must not stream a replacement bitstream.
    CC_CFG_CTRL cfg_i (
        .CLK(1'b0), .EN(1'b0), .DATA(8'b0),
        .VALID(1'b0), .RECFG(recfg)
    );

    always @(posedge clk) begin
        if (rst || !normal_mode) begin
            spi_idle_cycles <= 0;
            armed <= 0;
            fired <= 0;
            error <= 0;
            recfg <= 0;
            release_spi <= 0;
            handoff_pending <= 0;
            bus_ack <= 0;
            bus_rdata <= 0;
        end else begin
            bus_ack <= bus_cyc && !bus_ack;
            // Release fabric drivers before asking the configuration engine
            // to take over the shared flash pins on the following cycle.
            if (handoff_pending) begin
                recfg <= 1'b1;
                handoff_pending <= 1'b0;
            end
            if (!spi_idle) begin
                spi_idle_cycles <= 0;
                if (armed)
                    error <= 1'b1;
                armed <= 0;
            end else if (!(&spi_idle_cycles)) begin
                spi_idle_cycles <= spi_idle_cycles + 1'b1;
            end
            if (read_req) begin
                case (bus_addr)
                    3'd0: bus_rdata <= {27'd0, 1'b1, error, fired,
                                        armed, qualified};
                    default: bus_rdata <= 32'd0;
                endcase
            end
            if (write_req && !fired) begin
                if (bus_addr == 3'd1 && bus_wdata == ARM_KEY &&
                    qualified && !error) begin
                    armed <= 1'b1;
                end else if (bus_addr == 3'd2 && bus_wdata == BOOT_KEY &&
                             armed && qualified && !error) begin
                    release_spi <= 1'b1;
                    handoff_pending <= 1'b1;
                    fired <= 1'b1;
                    armed <= 1'b0;
                end else begin
                    armed <= 1'b0;
                    error <= 1'b1;
                end
            end
        end
    end
endmodule
`default_nettype wire
