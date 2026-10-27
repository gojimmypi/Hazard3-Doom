/* ULX5M-GS V005 v65: SPI-active minimal multiboot isolation test.
 *
 * Based on the semantics of YosysHQ/prjpeppercorn-test-cases
 * 128-secondary-bootaddr/top.v (RECFG-only, all other CC_CFG_CTRL inputs 0).
 *
 * No SPI flash pads, USB, CPU, BTN2 or flash write controller are used.
 * This is NOT the DFU bootloader and must not be treated as a recovery image.
 * The flash update, if subsequently authorized, is a separately guarded step.
 *
 * Primary LED witness: D6 always on; D7 blinks. After 2**26 - 1
 * reference-clock counts (~2.68 s at 25 MHz), assert RECFG and continue
 * D7 heartbeat if the configuration engine does not replace the primary.
 * Secondary witness: the existing independently JTAG-tested v41 walking LEDs.
 */
`default_nettype none
module top_ulx5m_gs_v65_multiboot_probe #(
    parameter integer RECFG_BITS = 26,
    parameter integer HEARTBEAT_BIT = 22
)(
    input wire clk25,
    output wire [7:0] led_n
);
    reg [RECFG_BITS-1:0] start_count = {RECFG_BITS{1'b0}};
    reg [HEARTBEAT_BIT:0] heartbeat = {(HEARTBEAT_BIT+1){1'b0}};
    wire recfg = &start_count;

    always @(posedge clk25) begin
        heartbeat <= heartbeat + 1'b1;
        if (!recfg)
            start_count <= start_count + 1'b1;
    end

    // Physical board LEDs are active HIGH despite the historical _n suffix.
    assign led_n = {heartbeat[HEARTBEAT_BIT], 1'b1, 6'b000000};

    // Exactly match upstream test 128's RECFG-only primitive connections.
    CC_CFG_CTRL cfg_i (
        .CLK(1'b0), .EN(1'b0), .DATA(8'b0),
        .VALID(1'b0), .RECFG(recfg)
    );
endmodule
`default_nettype wire
