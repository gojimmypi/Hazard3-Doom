/* Minimal register-compatible status/LED peripheral for USB probe only.
 * Does not instantiate ECP5 TRELLIS_IO/IFS primitives or reboot logic.
 */
`default_nettype none
module soc_ulx5m_misc (
    output wire [7:0] led_n,
    input  wire [2:0] btn_n,
    input  wire locked,
`ifdef ULX5M_SERV_NORMAL_BOOT_EXPERIMENT
    input wire mode_valid,
    input wire dfu_selected,
`endif
    input  wire [3:0] bus_addr,
    input  wire [31:0] bus_wdata,
    output reg  [31:0] bus_rdata,
    input  wire bus_cyc,
    output wire bus_ack,
    input  wire bus_we,
    input  wire clk,
    input  wire rst
);
    reg ack = 1'b0;
    reg [7:0] leds = 8'h00;
    reg [23:0] counter = 24'd0;
    reg [2:0] btn_sample = 3'b111;
    always @(posedge clk) begin
        if (rst) begin
            ack <= 1'b0;
            leds <= 8'h00;
            btn_sample <= 3'b111;
            bus_rdata <= 32'h00000000;
            counter <= 24'd0;
        end else begin
            ack <= bus_cyc & ~ack;
            counter <= counter + 24'd1;
            btn_sample <= btn_n;
            if (bus_cyc && !ack && bus_we && bus_addr[1:0] == 2'b00)
                leds <= bus_wdata[7:0];
            if (bus_cyc && !ack && !bus_we)
                bus_rdata <= (bus_addr[1:0] == 2'b00) ?
                    {8'h00, 5'h1f, btn_sample, 8'h00, leds} :
`ifdef ULX5M_SERV_NORMAL_BOOT_EXPERIMENT
                    (bus_addr[1:0] == 2'b01) ?
                    {30'd0, dfu_selected, mode_valid} :
`endif
                    32'h00000000;
        end
    end
    assign bus_ack = ack;
    // V005 LEDs are active-high despite the legacy led_n port name.
    // Physical LED numbering and pin swaps are handled in the CCF.
    assign led_n = {counter[23], locked, leds[5:0]};
endmodule
`default_nettype wire
