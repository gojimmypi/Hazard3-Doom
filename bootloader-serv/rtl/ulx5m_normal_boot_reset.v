/* ULX5M-GS normal-boot-only reset release isolation.
 * The PLL/global reset must assert firmware reset without a clock.
 * Selection must be latched before normal or DFU firmware can execute.
 * Does not alter the separately hardware-verified BTN2 DFU-only build.
 */
`default_nettype none
module ulx5m_normal_boot_reset (
    input  wire clk,
    input  wire rst,
    input  wire mode_valid,
    output reg  fw_reset = 1'b1
);
    always @(posedge clk or posedge rst) begin
        if (rst)
            fw_reset <= 1'b1;
        else
            fw_reset <= ~mode_valid;
    end
endmodule
`default_nettype wire
