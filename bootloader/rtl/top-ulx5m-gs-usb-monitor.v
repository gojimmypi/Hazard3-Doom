/*
 * ULX5M-GS v005 USB pad monitor for volatile JTAG bring-up.
 *
 * This is NOT a USB device or bootloader. It deliberately does not
 * assert USB attach, transmit on D+/D-, or access configuration flash.
 * GateMate EA bank is physically supplied at 3.3 V on this PCB.
 *
 * USB25_P shares pads IO_EA_A0 and IO_EA_A1; USB25_N shares IO_EA_B0
 * and IO_EA_B1. Only A1 and B1 are constrained. Other pads remain unused.
 */
`default_nettype none
module top_ulx5m_gs_usb_monitor (
    input  wire clk25,
    input  wire btn0_n,
    inout  wire usb_dp,
    inout  wire usb_dn,
    output wire [7:0] led_n
);
    wire clk48;
    wire reset;
    wire locked;
    wire rx_dp;
    wire rx_dn;
    wire rx_chg;
    reg [25:0] counter = 26'd0;

    sysmgr_gatemate clocks (
        .clk_in(clk25), .rst_in(1'b0), .clk_48m(clk48),
        .rst_out(reset), .locked(locked)
    );

    usb_phy #(.TARGET("GATEMATE")) phy (
        .pad_dp(usb_dp), .pad_dn(usb_dn),
        .rx_dp(rx_dp), .rx_dn(rx_dn), .rx_chg(rx_chg),
        .tx_dp(1'b0), .tx_dn(1'b0), .tx_en(1'b0),
        .clk(clk48), .rst(reset)
    );

    always @(posedge clk48) begin
        if (reset)
            counter <= 26'd0;
        else
            counter <= counter + 26'd1;
    end

    // LEDs are active-low on ULX5M-GS.
    // Do not expect enumeration: no D+ pullup is enabled in this design.
    assign led_n[0] = ~rx_dp;
    assign led_n[1] = ~rx_dn;
    assign led_n[2] = ~rx_chg;
    assign led_n[3] = btn0_n;
    assign led_n[5:4] = 2'b11;
    assign led_n[6] = ~locked;
    assign led_n[7] = ~counter[24];
endmodule
`default_nettype wire
