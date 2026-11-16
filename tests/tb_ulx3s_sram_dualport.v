// SPDX-License-Identifier: Apache-2.0
// Compare original zero-wait SRAM adapter against experimental split R/W port.
`default_nettype none
`timescale 1ns/1ps

module tb_ulx3s_sram_dualport;
    localparam DEPTH = 256;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;
    reg hready = 1;
    reg [31:0] haddr = 0;
    reg [31:0] hwdata = 0;
    reg hwrite = 0;
    reg [1:0] htrans = 0;
    reg [2:0] hsize = 2;
    wire [31:0] rdata_old, rdata_new;
    wire ready_old, ready_new, resp_old, resp_new;
    reg [31:0] reference_mem [0:DEPTH-1];
    reg pending_valid;
    integer pending_row;
    reg [3:0] pending_mask;
    reg [31:0] pending_data;
    integer i, n, b, row;
    reg [31:0] random_state, expected_data, tmp;

    ahb_sync_sram #(.DEPTH(DEPTH), .HAS_WRITE_BUFFER(1),
        .DUAL_PORT_RW(0)) dut_old (
        .clk(clk), .rst_n(rst_n), .ahbls_hready_resp(ready_old),
        .ahbls_hready(hready), .ahbls_hresp(resp_old),
        .ahbls_haddr(haddr), .ahbls_hwrite(hwrite),
        .ahbls_htrans(htrans), .ahbls_hsize(hsize),
        .ahbls_hburst(3'b000), .ahbls_hprot(4'b0011),
        .ahbls_hmastlock(1'b0), .ahbls_hwdata(hwdata),
        .ahbls_hrdata(rdata_old));

    ahb_sync_sram #(.DEPTH(DEPTH), .HAS_WRITE_BUFFER(1),
        .DUAL_PORT_RW(1)) dut_new (
        .clk(clk), .rst_n(rst_n), .ahbls_hready_resp(ready_new),
        .ahbls_hready(hready), .ahbls_hresp(resp_new),
        .ahbls_haddr(haddr), .ahbls_hwrite(hwrite),
        .ahbls_htrans(htrans), .ahbls_hsize(hsize),
        .ahbls_hburst(3'b000), .ahbls_hprot(4'b0011),
        .ahbls_hmastlock(1'b0), .ahbls_hwdata(hwdata),
        .ahbls_hrdata(rdata_new));

    // An AHB write's data is presented one cycle after its address.
    // All transfers in this test are zero wait, including a read following
    // a partial write to the same word.
    task issue;
        input valid, write_enable;
        input [31:0] address, following_write_data;
        input [2:0] size;
        reg [3:0] current_mask;
        begin
            @(negedge clk);
            haddr = address;
            htrans = valid ? 2'b10 : 2'b00;
            hwrite = write_enable;
            hsize = size;
            hwdata = pending_data;
            row = (address >> 2) % DEPTH;
            // Retire the previous write in the reference model before
            // checking the data from an accepted read at this same edge.
            if (pending_valid) begin
                tmp = reference_mem[pending_row];
                for (b = 0; b < 4; b = b + 1)
                    if (pending_mask[b])
                        tmp[b*8 +: 8] = pending_data[b*8 +: 8];
                reference_mem[pending_row] = tmp;
            end
            expected_data = reference_mem[row];
            @(posedge clk);
            #1;
            if (ready_old !== 1'b1 || ready_new !== 1'b1 ||
                resp_old !== 1'b0 || resp_new !== 1'b0) begin
                $display("FAIL ready/resp cycle=%0d", n);
                $fatal(1);
            end
            if (valid && !write_enable &&
                (rdata_old !== expected_data || rdata_new !== expected_data)) begin
                $display("FAIL cycle=%0d addr=%h expected=%h old=%h new=%h",
                    n, address, expected_data, rdata_old, rdata_new);
                $fatal(1);
            end
            pending_valid = valid && write_enable;
            pending_row = row;
            current_mask = ~(4'hf << (1 << size));
            pending_mask = current_mask << address[1:0];
            pending_data = following_write_data;
            n = n + 1;
        end
    endtask

    initial begin
        n = 0;
        pending_valid = 0;
        pending_row = 0;
        pending_mask = 0;
        pending_data = 0;
        random_state = 32'h31415926;
        for (i = 0; i < DEPTH; i = i + 1)
            reference_mem[i] = 0;
        repeat (3) @(negedge clk);
        rst_n = 1;
        issue(1, 1, 32'h0000, 32'h11223344, 2);
        issue(1, 0, 32'h0000, 32'h0, 2);
        issue(1, 1, 32'h0001, 32'h0000aa00, 0);
        issue(1, 0, 32'h0000, 32'h0, 2);
        issue(1, 1, 32'h0002, 32'hbeef0000, 1);
        issue(1, 1, 32'h0004, 32'h55667788, 2);
        issue(1, 0, 32'h0000, 32'h0, 2);
        issue(1, 0, 32'h0004, 32'h0, 2);
        issue(0, 0, 32'h0000, 32'h0, 2);
        for (i = 0; i < 4000; i = i + 1) begin
            random_state = random_state * 32'd1664525 + 32'd1013904223;
            case (random_state[5:4])
                0: issue(0, 0, 0, 0, 2);
                1: issue(1, 0, {22'b0, random_state[15:8], 2'b00}, 0, 2);
                2: issue(1, 1, {22'b0, random_state[15:8], 2'b00}, ~random_state, 2);
                3: issue(1, 1, {22'b0, random_state[15:8], 2'b00} |
                                {30'b0, random_state[7:6]},
                         random_state ^ 32'h12345678, 0);
            endcase
        end
        issue(0, 0, 0, 0, 2);
        $display("PASS: %0d AHB cycles; original and dual-port SRAM match reference", n);
        $finish;
    end
endmodule

`default_nettype wire
