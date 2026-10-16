/* GateMate 25 MHz to 48 MHz clock/reset for ULX5M-GS.
 * CC_PLL ports and timing follow Cologne Chip UG1001, section 7.3.
 * No ECP5 primitives are used here.
 */
`default_nettype none

module sysmgr_gatemate (
    input  wire clk_in,
    input  wire rst_in,
    output wire clk_48m,
    output wire rst_out,
    output wire locked
);
    wire clk_ref;
    wire clk_pll;
    wire pll_locked;
    wire usr_rstn;

    CC_IBUF #(
        .PIN_NAME("IO_SB_A8"),
        .V_IO("1.8")
    ) clk_buf_i (
        .I(clk_in),
        .Y(clk_ref)
    );

    CC_PLL #(
        .REF_CLK(25.0),
        .OUT_CLK(48.0),
        .LOW_JITTER(1),
        .LOCK_REQ(1)
    ) pll_i (
        .CLK_REF(clk_ref),
        .USR_CLK_REF(1'b0),
        .CLK_FEEDBACK(1'b0),
        .USR_LOCKED_STDY_RST(1'b1),
        .USR_PLL_LOCKED_STDY(),
        .USR_PLL_LOCKED(pll_locked),
        .CLK0(clk_pll),
        .CLK90(),
        .CLK180(),
        .CLK270(),
        .CLK_REF_OUT()
    );

    CC_BUFG bufg_i (
        .I(clk_pll),
        .O(clk_48m)
    );

    CC_USR_RSTN config_reset_i (
        .USR_RSTN(usr_rstn)
    );

    // Hold reset for 256 clocks after the FPGA has configured and PLL locks.
    // Output resets asserted HIGH, as in the original ECP5 sysmgr module.
    reg [7:0] release_count = 8'd0;
    reg ready = 1'b0;
    always @(posedge clk_48m or negedge usr_rstn) begin
        if (!usr_rstn) begin
            release_count <= 8'd0;
            ready <= 1'b0;
        end else if (rst_in || !pll_locked) begin
            release_count <= 8'd0;
            ready <= 1'b0;
        end else if (!ready) begin
            release_count <= release_count + 8'd1;
            if (&release_count)
                ready <= 1'b1;
        end
    end

    assign locked = pll_locked;
    assign rst_out = !ready;
endmodule

`default_nettype wire
