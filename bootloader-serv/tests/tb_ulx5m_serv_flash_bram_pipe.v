/*
 * ULX5M flash-read probe: registered BRAM request and response integration.
 * SERV RV32I program tests word, byte and halfword stores, signed/unsigned loads,
 * a read after the final store, and one-shot BRAM/MMIO write handshakes.
 * No USB PHY, SPI pins or configuration flash are involved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */
`timescale 1ns/1ps
`default_nettype none
module tb_ulx5m_serv_flash_bram_pipe;
    localparam integer RAM_AW = 13;

    reg clk = 1'b0;
    reg rst = 1'b1;
    always #5 clk = ~clk;

    wire cpu_valid, cpu_instr, cpu_ready;
    wire [31:0] cpu_addr, cpu_wdata, cpu_rdata;
    wire [3:0] cpu_wstrb;
    wire bridge_valid, bridge_ready;
    wire [31:0] bridge_rdata;
    wire [RAM_AW-1:0] bram_addr;
    wire [31:0] bram_rdata, bram_wdata;
    wire [3:0] bram_wmsk;
    wire bram_we;
    wire [15:0] wb_addr;
    wire [31:0] wb_wdata;
    wire [3:0] wb_wmsk;
    wire wb_cyc, wb_we;
    reg wb_ack = 1'b0;

    integer bram_writes = 0;
    integer wb_writes = 0;
    integer cpu_responses = 0;
    reg done = 1'b0;
    integer i;

    soc_serv_cpu cpu_i (
        .clk(clk), .rst(rst),
        .mem_valid(cpu_valid), .mem_instr(cpu_instr),
        .mem_ready(cpu_ready), .mem_addr(cpu_addr),
        .mem_wdata(cpu_wdata), .mem_wstrb(cpu_wstrb),
        .mem_rdata(cpu_rdata)
    );

    soc_mem_response_reg response_i (
        .clk(clk), .rst(rst),
        .cpu_valid(cpu_valid), .cpu_ready(cpu_ready), .cpu_rdata(cpu_rdata),
        .bridge_valid(bridge_valid), .bridge_ready(bridge_ready),
        .bridge_rdata(bridge_rdata)
    );

    soc_bridge #(
        .RAM_AW(RAM_AW), .WB_N(1), .WB_DW(32), .WB_AW(16),
        .WB_AI(2), .WB_REG(4), .BRAM_REG(1)
    ) bridge_i (
        .pb_addr(cpu_addr), .pb_rdata(bridge_rdata),
        .pb_wdata(cpu_wdata), .pb_wstrb(cpu_wstrb),
        .pb_valid(bridge_valid), .pb_ready(bridge_ready),
        .bram_addr(bram_addr), .bram_rdata(bram_rdata),
        .bram_wdata(bram_wdata), .bram_wmsk(bram_wmsk),
        .bram_we(bram_we),
        .wb_addr(wb_addr), .wb_wdata(wb_wdata), .wb_wmsk(wb_wmsk),
        .wb_rdata(32'h00000000), .wb_cyc(wb_cyc), .wb_we(wb_we),
        .wb_ack(wb_ack), .clk(clk), .rst(rst)
    );

    soc_bram #(.AW(RAM_AW), .INIT_FILE("")) bram_i (
        .addr(bram_addr), .rdata(bram_rdata),
        .wdata(bram_wdata), .wmsk(bram_wmsk),
        .we(bram_we), .clk(clk)
    );

    // Mock MMIO at 0x80000000: acknowledge a single request per transfer.
    always @(posedge clk) begin
        if (rst) begin
            wb_ack <= 1'b0;
            bram_writes <= 0;
            wb_writes <= 0;
            cpu_responses <= 0;
            done <= 1'b0;
        end else begin
            wb_ack <= wb_cyc & ~wb_ack;
            if (cpu_valid && cpu_ready)
                cpu_responses <= cpu_responses + 1;
            if (bram_we) begin
                if (bram_addr !== 13'h048)
                    $fatal(1, "[FAIL] BRAM write address: 0x%04x", bram_addr);
                case (bram_writes)
                    0: if (bram_wmsk !== 4'b1111 || bram_wdata !== 32'h12345678)
                           $fatal(1, "[FAIL] BRAM word write");
                    1: if (bram_wmsk !== 4'b0010 || bram_wdata[15:8] !== 8'ha5)
                           $fatal(1, "[FAIL] BRAM byte write");
                    2: if (bram_wmsk !== 4'b1100 || bram_wdata[31:16] !== 16'h0345)
                           $fatal(1, "[FAIL] BRAM halfword write");
                    default: $fatal(1, "[FAIL] duplicate BRAM write");
                endcase
                bram_writes <= bram_writes + 1;
            end
            if (wb_cyc && !wb_ack) begin
                if (!wb_we || wb_wmsk !== 4'b1111)
                    $fatal(1, "[FAIL] unexpected MMIO operation");
                case (wb_writes)
                    0: if (wb_addr !== 16'h0000 || wb_wdata !== 32'h0345a578)
                           $fatal(1, "[FAIL] read-after-write result: %h", wb_wdata);
                    1: if (wb_addr !== 16'h0001 || wb_wdata !== 32'hffffffa5)
                           $fatal(1, "[FAIL] signed byte load: %h", wb_wdata);
                    2: if (wb_addr !== 16'h0002 || wb_wdata !== 32'h000000a5)
                           $fatal(1, "[FAIL] unsigned byte load: %h", wb_wdata);
                    3: if (wb_addr !== 16'h0003 || wb_wdata !== 32'h00000345)
                           $fatal(1, "[FAIL] halfword load: %h", wb_wdata);
                    4: begin
                        if (wb_addr !== 16'h0004 || wb_wdata !== 32'h00000001)
                            $fatal(1, "[FAIL] completion store");
                        done <= 1'b1;
                    end
                    default: $fatal(1, "[FAIL] duplicate MMIO write");
                endcase
                wb_writes <= wb_writes + 1;
            end
        end
    end

    initial begin
        for (i = 0; i < (1 << RAM_AW); i = i + 1)
            bram_i.mem[i] = 32'h00000013; // NOP
        bram_i.mem[ 0] = 32'h800000b7; // lui  x1,0x80000 (MMIO)
        bram_i.mem[ 1] = 32'h12000113; // addi x2,x0,0x120 (BRAM)
        bram_i.mem[ 2] = 32'h123451b7; // lui  x3,0x12345
        bram_i.mem[ 3] = 32'h67818193; // addi x3,x3,0x678
        bram_i.mem[ 4] = 32'h00312023; // sw   x3,0(x2)
        bram_i.mem[ 5] = 32'h0a500213; // addi x4,x0,0xa5
        bram_i.mem[ 6] = 32'h004100a3; // sb   x4,1(x2)
        bram_i.mem[ 7] = 32'h34500293; // addi x5,x0,0x345
        bram_i.mem[ 8] = 32'h00511123; // sh   x5,2(x2)
        bram_i.mem[ 9] = 32'h00012303; // lw   x6,0(x2)
        bram_i.mem[10] = 32'h0060a023; // sw   x6,0(x1)
        bram_i.mem[11] = 32'h00110383; // lb   x7,1(x2)
        bram_i.mem[12] = 32'h0070a223; // sw   x7,4(x1)
        bram_i.mem[13] = 32'h00114403; // lbu  x8,1(x2)
        bram_i.mem[14] = 32'h0080a423; // sw   x8,8(x1)
        bram_i.mem[15] = 32'h00211483; // lh   x9,2(x2)
        bram_i.mem[16] = 32'h0090a623; // sw   x9,12(x1)
        bram_i.mem[17] = 32'h00100513; // addi x10,x0,1
        bram_i.mem[18] = 32'h00a0a823; // sw   x10,16(x1)
        bram_i.mem[19] = 32'h0000006f; // jal  x0,0

        repeat (5) @(negedge clk);
        rst = 1'b0;
        for (i = 0; i < 30000; i = i + 1) begin
            @(negedge clk);
            if (done) begin
                repeat (12) @(negedge clk);
                if (bram_writes !== 3 || wb_writes !== 5)
                    $fatal(1, "[FAIL] write counts BRAM=%0d MMIO=%0d",
                           bram_writes, wb_writes);
                if (bram_i.mem[13'h048] !== 32'h0345a578)
                    $fatal(1, "[FAIL] BRAM readback: 0x%08x", bram_i.mem[13'h048]);
                if (cpu_responses < 20)
                    $fatal(1, "[FAIL] too few CPU responses: %0d", cpu_responses);
                $display("[PASS] registered BRAM request: word/byte/halfword stores");
                $display("[PASS] readback, signed loads, MMIO and one-shot ACK");
                $finish;
            end
        end
        $fatal(1, "[FAIL] registered BRAM test timeout");
    end
endmodule
`default_nettype wire
