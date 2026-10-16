`timescale 1ns/1ps
`default_nettype none
module tb_soc_mem_response_reg;
    reg clk = 0;
    always #5 clk = ~clk;

    reg rst = 1;
    reg cpu_valid = 0;
    wire cpu_ready;
    wire [31:0] cpu_rdata;
    wire bridge_valid;
    reg bridge_ready = 0;
    reg [31:0] bridge_rdata = 0;
    integer n_reqs = 0;

    soc_mem_response_reg dut (
        .clk(clk), .rst(rst),
        .cpu_valid(cpu_valid), .cpu_ready(cpu_ready), .cpu_rdata(cpu_rdata),
        .bridge_valid(bridge_valid), .bridge_ready(bridge_ready),
        .bridge_rdata(bridge_rdata)
    );

    always @(posedge clk) begin
        if (bridge_valid && bridge_ready)
            n_reqs <= n_reqs + 1;
    end

    task check;
        input condition;
        input [256*8-1:0] message;
        begin
            if (!condition) begin
                $display("[FAIL] %0s", message);
                $fatal(1);
            end
        end
    endtask

    initial begin
        // While reset: no response, no requests.
        repeat (2) @(negedge clk);
        check(!cpu_ready, "ready asserted in reset");
        rst = 0;
        cpu_valid = 1;
        #1; // Wait for the combinational bridge_valid assignment to settle.
        check(bridge_valid, "request not forwarded");
        repeat (3) begin
            @(negedge clk);
            check(!cpu_ready && bridge_valid, "unexpected early acknowledgment");
        end

        // Return a data word; only one response may be captured.
        bridge_rdata = 32'h12345678;
        bridge_ready = 1;
        @(negedge clk);
        check(cpu_ready && cpu_rdata == 32'h12345678,
              "read data and ready not registered together");
        check(!bridge_valid && n_reqs == 1, "duplicate bridge request after ACK");
        bridge_ready = 0;
        bridge_rdata = 32'hdeadbeef;
        @(negedge clk);
        check(!cpu_ready && !bridge_valid && cpu_rdata == 32'h12345678,
              "response repeated or data changed while CPU valid stays high");

        // CPU consumes ACK then drops valid; re-arm for next access.
        cpu_valid = 0;
        @(negedge clk);
        check(!bridge_valid && !cpu_ready, "idle response not clear");
        cpu_valid = 1;
        #1;
        check(bridge_valid, "next transaction not armed");
        bridge_ready = 1;
        bridge_rdata = 32'hcafef00d;
        @(negedge clk);
        check(cpu_ready && cpu_rdata == 32'hcafef00d && n_reqs == 2,
              "second response failed");
        check(!bridge_valid, "second response repeated");

        // Reset must clear the pending state, even during a held request.
        rst = 1;
        bridge_ready = 0;
        @(negedge clk);
        check(!cpu_ready, "reset did not clear ready");
        rst = 0;
        #1;
        check(bridge_valid, "reset did not clear accepted state");
        $display("[PASS] registered response: latency, data, single ACK, re-arm, reset");
        $finish;
    end
endmodule
`default_nettype wire
