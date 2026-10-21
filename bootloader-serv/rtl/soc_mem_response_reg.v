/*
 * GateMate USB bootloader: one-cycle registered PicoRV32 memory response.
 *
 * The existing ULX4M SoC and memory bridge are unchanged. This module
 * breaks the BRAM data -> PicoRV32 instruction-decode timing path without
 * introducing another clock domain. It acknowledges each CPU transaction
 * exactly once, even if the CPU holds cpu_valid until seeing cpu_ready.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */
`default_nettype none
module soc_mem_response_reg (
    input wire clk,
    input wire rst,
    input wire cpu_valid,
    output wire cpu_ready,
    output wire [31:0] cpu_rdata,
    output wire bridge_valid,
    input wire bridge_ready,
    input wire [31:0] bridge_rdata
);
    reg accepted;
    reg ready_q;
    reg [31:0] rdata_q;

    // Disable the underlying memory request immediately after its ACK.
    // Re-arm only after the PicoRV32 bus drops cpu_valid between transfers.
    assign bridge_valid = cpu_valid && !accepted;
    assign cpu_ready = ready_q;
    assign cpu_rdata = rdata_q;

    always @(posedge clk) begin
        if (rst) begin
            accepted <= 1'b0;
            ready_q <= 1'b0;
        end else begin
            ready_q <= 1'b0;
            if (!cpu_valid) begin
                accepted <= 1'b0;
            end else if (bridge_valid && bridge_ready) begin
                rdata_q <= bridge_rdata;
                ready_q <= 1'b1;
                accepted <= 1'b1;
            end
        end
    end
endmodule
`default_nettype wire
