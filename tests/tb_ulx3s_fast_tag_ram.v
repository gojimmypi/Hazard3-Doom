// SPDX-License-Identifier: Apache-2.0
// End-to-end AHB cache test for the optional registered tag-hit/way stage.
// Exercises read misses/hits, write hits/misses, dirty evictions, byte lanes,
// and repeated accesses that alias to the same cache set.
`default_nettype none
`timescale 1ns/1ps

module ulx3s_cache_pipeline_driver #(
    parameter PIPE = 0,
    parameter TAG_MODE = 0
)(input wire clk, output reg done = 0);
    localparam MEM_BYTES = 1024;
    localparam MEM_WORDS = MEM_BYTES / 4;

    reg rst_n = 0;
    reg [31:0] haddr = 0;
    reg [31:0] hwdata = 0;
    reg hwrite = 0;
    reg [1:0] htrans = 0;
    reg [2:0] hsize = 2;
    wire hready, hresp;
    wire [31:0] hrdata;
    wire downstream_ready, downstream_hresp, downstream_resp;
    wire [31:0] downstream_haddr, downstream_hwdata, downstream_hrdata;
    wire downstream_hwrite;
    wire [1:0] downstream_htrans;
    wire [2:0] downstream_hsize, downstream_hburst;
    wire [3:0] downstream_hprot;
    wire downstream_hmastlock;
    reg [31:0] reference [0:MEM_WORDS-1];
    reg [31:0] rng = 32'h23574113;
    reg [31:0] expected_read;
    reg [31:0] value, address;
    reg [2:0] size;
    integer i, j, lane, count;

    ahb_cache_writeback #(
        .N_WAYS(2), .W_ADDR(32), .W_DATA(32),
        .W_LINE(256), .DEPTH(4),
        .REGISTERED_READ_HITS(1), .PIPELINE_TAG_CHECK(PIPE),
        .TAG_RAM_MODE(TAG_MODE)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .src_hready_resp(hready), .src_hready(hready),
        .src_hresp(hresp), .src_haddr(haddr),
        .src_hwrite(hwrite), .src_htrans(htrans),
        .src_hsize(hsize), .src_hburst(3'b000),
        .src_hprot(4'b1111), .src_hmastlock(1'b0),
        .src_hwdata(hwdata), .src_hrdata(hrdata),
        .dst_hready_resp(downstream_resp), .dst_hready(downstream_ready),
        .dst_hresp(downstream_hresp), .dst_haddr(downstream_haddr),
        .dst_hwrite(downstream_hwrite), .dst_htrans(downstream_htrans),
        .dst_hsize(downstream_hsize), .dst_hburst(downstream_hburst),
        .dst_hprot(downstream_hprot), .dst_hmastlock(downstream_hmastlock),
        .dst_hwdata(downstream_hwdata), .dst_hrdata(downstream_hrdata)
    );

    ahb_sync_sram #(.DEPTH(MEM_WORDS), .HAS_WRITE_BUFFER(1)) backing_ram (
        .clk(clk), .rst_n(rst_n),
        .ahbls_hready_resp(downstream_resp),
        .ahbls_hready(downstream_ready),
        .ahbls_hresp(downstream_hresp),
        .ahbls_haddr(downstream_haddr),
        .ahbls_hwrite(downstream_hwrite),
        .ahbls_htrans(downstream_htrans),
        .ahbls_hsize(downstream_hsize),
        .ahbls_hburst(downstream_hburst),
        .ahbls_hprot(downstream_hprot),
        .ahbls_hmastlock(downstream_hmastlock),
        .ahbls_hwdata(downstream_hwdata),
        .ahbls_hrdata(downstream_hrdata)
    );

    task transfer;
        input do_write;
        input [31:0] addr;
        input [2:0] access_size;
        input [31:0] write_data;
        reg [31:0] observed;
        begin
            if (addr + (1 << access_size) > MEM_BYTES ||
                (addr & ((1 << access_size) - 1)) != 0) begin
                $display("FAIL: testbench unaligned/out of range %h size=%0d", addr, access_size);
                $fatal(1);
            end
            // AHB NSEQ address phase (cache must be idle after last request).
            @(negedge clk);
            haddr = addr;
            hsize = access_size;
            hwrite = do_write;
            htrans = 2'b10;
            hwdata = 32'hdeadcafe;
            @(posedge clk);
            #1;
            // AHB data phase. The address phase is now IDLE while waiting.
            @(negedge clk);
            htrans = 2'b00;
            hwdata = write_data;
            begin: wait_for_retire
                for (count = 0; count < 400; count = count + 1) begin
                    @(posedge clk);
                    #1;
                    if (hresp) begin
                        $display("FAIL PIPE=%0d TAG_MODE=%0d AHB error addr=%h", PIPE, TAG_MODE, addr);
                        $fatal(1);
                    end
                    if (hready) begin
                        observed = hrdata;
                        if (!do_write && observed !== reference[addr >> 2]) begin
                            $display("FAIL PIPE=%0d TAG_MODE=%0d read addr=%h got=%h want=%h",
                                PIPE, TAG_MODE, addr, observed, reference[addr >> 2]);
                            $fatal(1);
                        end
                        disable wait_for_retire;
                    end
                end
                $display("FAIL PIPE=%0d TAG_MODE=%0d timeout addr=%h write=%0d", PIPE, TAG_MODE, addr, do_write);
                $fatal(1);
            end
            if (do_write) begin
                for (lane = 0; lane < 4; lane = lane + 1)
                    if (lane >= addr[1:0] && lane < addr[1:0] + (1 << access_size))
                        reference[addr >> 2][lane * 8 +: 8] = write_data[lane * 8 +: 8];
            end
        end
    endtask

    initial begin
        for (i = 0; i < MEM_WORDS; i = i + 1)
            reference[i] = 0;
        repeat (5) @(negedge clk);
        rst_n = 1;
        // Three different tags mapping to the same cache index; this forces
        // a dirty victim writeback and later reload from backing SDRAM.
        transfer(1, 32'h000, 2, 32'h11112222);
        transfer(1, 32'h080, 2, 32'h33334444);
        transfer(1, 32'h100, 2, 32'h55556666);
        transfer(0, 32'h000, 2, 0);
        transfer(0, 32'h080, 2, 0);
        transfer(0, 32'h100, 2, 0);
        transfer(1, 32'h001, 0, 32'h0000aa00);
        transfer(1, 32'h002, 1, 32'hbeef0000);
        transfer(0, 32'h000, 2, 0);
        for (j = 0; j < 300; j = j + 1) begin
            rng = rng * 32'd1664525 + 32'd1013904223;
            // Addresses over the whole backing store exercise many aliases.
            address = {22'b0, rng[17:10], 2'b00};
            size = rng[8:7] == 0 ? 3'd0 : rng[8:7] == 1 ? 3'd1 : 3'd2;
            address = address | (size == 0 ? {30'b0,rng[6:5]} :
                                 size == 1 ? {30'b0,rng[6],1'b0} : 32'b0);
            value = rng ^ (32'h5a0b0c0d + j);
            transfer(rng[9], address, size, value);
            // Always verify each randomly written word through the cache.
            if (rng[9]) transfer(0, {address[31:2],2'b00}, 2, 0);
        end
        // Drain dirty entries via repeated conflicts and check retained data.
        for (j = 0; j < MEM_WORDS; j = j + 1)
            transfer(0, j * 4, 2, 0);
        $display("PASS PIPE=%0d TAG_MODE=%0d: cache read/write/eviction regression", PIPE, TAG_MODE);
        done = 1;
    end
endmodule

module tb_ulx3s_fast_tag_ram;
    reg clk = 0;
    always #5 clk = ~clk;
    wire done_old, done_fast1, done_fast2;
    ulx3s_cache_pipeline_driver #(.PIPE(0), .TAG_MODE(0)) old_cache (
        .clk(clk), .done(done_old));
    ulx3s_cache_pipeline_driver #(.PIPE(0), .TAG_MODE(1)) fast1_cache (
        .clk(clk), .done(done_fast1));
    ulx3s_cache_pipeline_driver #(.PIPE(0), .TAG_MODE(2)) fast2_cache (
        .clk(clk), .done(done_fast2));
    initial begin
        wait(done_old && done_fast1 && done_fast2);
        $display("PASS: original, registered tag, and split-way tag RAM regressions completed");
        $finish;
    end
    initial begin
        #2000000;
        $display("FAIL: global cache regression timeout");
        $fatal(1);
    end
endmodule

`default_nettype wire
