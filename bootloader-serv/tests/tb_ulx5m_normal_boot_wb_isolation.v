/* The normal-boot mode read leaves a latched 0x3 on the misc read bus.
 * A later USB register read must not OR in this inactive peripheral's data.
 * Simulation only; no GateMate or SPI flash operations.
 */
`timescale 1ns/1ps
`default_nettype none
module tb_ulx5m_normal_boot_wb_isolation;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg bus_cyc = 1'b0;
    reg [3:0] bus_addr = 4'd1;
    wire [31:0] misc_rdata;
    wire misc_ack;
    wire [7:0] unused_leds;
    wire [31:0] masked_misc = bus_cyc ? misc_rdata : 32'd0;
    localparam [31:0] USB_CSR = 32'h00008000;

    always #5 clk = ~clk;

    soc_ulx5m_misc misc_i (
        .led_n(unused_leds), .btn_n(3'b111), .locked(1'b1),
        .mode_valid(1'b1), .dfu_selected(1'b1),
        .bus_addr(bus_addr), .bus_wdata(32'd0),
        .bus_rdata(misc_rdata), .bus_cyc(bus_cyc),
        .bus_ack(misc_ack), .bus_we(1'b0),
        .clk(clk), .rst(rst)
    );

    initial begin
        #1000;
        $fatal(1, "Wishbone isolation simulation timeout");
    end

    initial begin
        repeat (3) @(negedge clk);
        rst = 1'b0;
        bus_cyc = 1'b1;
        repeat (2) @(negedge clk);
        if (misc_rdata !== 32'h00000003)
            $fatal(1, "BTN2 DFU mode register did not return 0x3");
        if (masked_misc !== 32'h00000003)
            $fatal(1, "Active misc read was incorrectly masked");
        $display("[PASS] Active DFU mode register read preserved");

        // Switch to USB (Wishbone peripheral 2). The misc peripheral
        // still holds its previous result, even after bus_cyc drops.
        bus_cyc = 1'b0;
        #1;
        if (misc_rdata !== 32'h00000003)
            $fatal(1, "Test precondition: misc readback should stay latched");
        if ((USB_CSR | misc_rdata) !== 32'h00008003)
            $fatal(1, "Test precondition: original cross-bus corruption absent");
        if ((USB_CSR | masked_misc) !== USB_CSR)
            $fatal(1, "Inactive misc data corrupted USB register read");
        $display("[PASS] Inactive misc readback cannot corrupt USB CSR");
        $finish;
    end
endmodule
`default_nettype wire
