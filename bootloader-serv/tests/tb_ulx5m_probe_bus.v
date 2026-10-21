/*
 * ULX5M USB bootloader: integrated PicoRV32/BRAM/Wishbone smoke test.
 *
 * Runs a small, fixed RV32I program without a RISC-V toolchain or USB PHY.
 * Uses the same CPU configuration, registered memory response, and bridge
 * settings as top-ulx5m-gs-usb-probe.v. No flash-related RTL is involved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */
`timescale 1ns/1ps
`default_nettype none
module tb_ulx5m_probe_bus;
    localparam integer RAM_AW = 13;

    reg clk = 1'b0;
    reg rst = 1'b1;
    always #5 clk = ~clk;

    wire cpu_valid, cpu_instr, cpu_ready, cpu_trap;
    wire [31:0] cpu_addr, cpu_wdata, cpu_rdata;
    wire [3:0] cpu_wstrb;
    wire bridge_valid, bridge_ready;
    wire [31:0] bridge_rdata;
    wire [RAM_AW-1:0] bram_addr;
    wire [31:0] bram_rdata, bram_wdata;
    wire [3:0] bram_wmsk;
    wire bram_we;
    wire [15:0] wb_addr;
    wire [31:0] wb_wdata, wb_rdata;
    wire [3:0] wb_wmsk;
    wire wb_cyc, wb_we;
    reg wb_ack = 1'b0;

    integer wb_writes = 0;
    integer wb_reads = 0;
    integer cpu_responses = 0;
    reg done = 1'b0;
    integer i;

    picorv32 #(
        .PROGADDR_RESET(32'h00000000),
        .STACKADDR(4 << RAM_AW),
        .BARREL_SHIFTER(0),
        .COMPRESSED_ISA(0),
        .ENABLE_REGS_DUALPORT(1),
        .ENABLE_COUNTERS(0),
        .ENABLE_COUNTERS64(0),
        .ENABLE_MUL(0),
        .ENABLE_DIV(0),
        .ENABLE_IRQ(0),
        .ENABLE_IRQ_QREGS(0),
        .CATCH_MISALIGN(0),
        .CATCH_ILLINSN(0)
    ) cpu_i (
        .clk(clk), .resetn(~rst), .trap(cpu_trap),
        .mem_valid(cpu_valid), .mem_instr(cpu_instr),
        .mem_ready(cpu_ready), .mem_addr(cpu_addr),
        .mem_wdata(cpu_wdata), .mem_wstrb(cpu_wstrb),
        .mem_rdata(cpu_rdata),
        .pcpi_wr(1'b0), .pcpi_rd(32'h00000000),
        .pcpi_wait(1'b0), .pcpi_ready(1'b0), .irq(32'h00000000)
    );

    soc_mem_response_reg response_i (
        .clk(clk), .rst(rst),
        .cpu_valid(cpu_valid), .cpu_ready(cpu_ready), .cpu_rdata(cpu_rdata),
        .bridge_valid(bridge_valid), .bridge_ready(bridge_ready),
        .bridge_rdata(bridge_rdata)
    );

    soc_bridge #(
        .RAM_AW(RAM_AW), .WB_N(1), .WB_DW(32), .WB_AW(16),
        .WB_AI(2), .WB_REG(4)
    ) bridge_i (
        .pb_addr(cpu_addr), .pb_rdata(bridge_rdata),
        .pb_wdata(cpu_wdata), .pb_wstrb(cpu_wstrb),
        .pb_valid(bridge_valid), .pb_ready(bridge_ready),
        .bram_addr(bram_addr), .bram_rdata(bram_rdata),
        .bram_wdata(bram_wdata), .bram_wmsk(bram_wmsk),
        .bram_we(bram_we),
        .wb_addr(wb_addr), .wb_wdata(wb_wdata), .wb_wmsk(wb_wmsk),
        .wb_rdata(wb_rdata), .wb_cyc(wb_cyc), .wb_we(wb_we),
        .wb_ack(wb_ack), .clk(clk), .rst(rst)
    );

    soc_bram #(.AW(RAM_AW), .INIT_FILE("")) bram_i (
        .addr(bram_addr), .rdata(bram_rdata),
        .wdata(bram_wdata), .wmsk(bram_wmsk),
        .we(bram_we), .clk(clk)
    );

    // Mock Wishbone peripheral at 0x80000000, selected by bridge slot 0.
    // Return a constant on reads and acknowledge each bus cycle once.
    assign wb_rdata = wb_cyc && !wb_we ? 32'h000000a5 : 32'h00000000;
    always @(posedge clk) begin
        if (rst) begin
            wb_ack <= 1'b0;
            wb_writes <= 0;
            wb_reads <= 0;
            cpu_responses <= 0;
            done <= 1'b0;
        end else begin
            wb_ack <= wb_cyc && !wb_ack;
            if (cpu_valid && cpu_ready)
                cpu_responses <= cpu_responses + 1;
            if (wb_cyc && !wb_ack) begin
                if (wb_we) begin
                    case (wb_writes)
                        0: if (wb_addr !== 16'h0000 || wb_wdata !== 32'd42)
                               $fatal(1, "[FAIL] first Wishbone store");
                        1: if (wb_addr !== 16'h0001 || wb_wdata !== 32'h000000a6)
                               $fatal(1, "[FAIL] second Wishbone store");
                        2: begin
                            if (wb_addr !== 16'h0002 || wb_wdata !== 32'd1)
                                $fatal(1, "[FAIL] completion store");
                            done <= 1'b1;
                        end
                        default: $fatal(1, "[FAIL] duplicate Wishbone store");
                    endcase
                    if (wb_wmsk !== 4'b1111)
                        $fatal(1, "[FAIL] incorrect Wishbone byte enables");
                    wb_writes <= wb_writes + 1;
                end else begin
                    if (wb_addr !== 16'h0000)
                        $fatal(1, "[FAIL] unexpected Wishbone read address");
                    wb_reads <= wb_reads + 1;
                end
            end
        end
    end

    initial begin
        // Hand-encoded RV32I: write MMIO, read MMIO, store/load BRAM,
        // increment returned byte value, write MMIO, signal completion.
        // All unassigned BRAM words contain ADDI x0,x0,0 (NOP).
        for (i = 0; i < (1 << RAM_AW); i = i + 1)
            bram_i.mem[i] = 32'h00000013;
        bram_i.mem[ 0] = 32'h800000b7; // lui  x1,0x80000
        bram_i.mem[ 1] = 32'h02a00113; // addi x2,x0,42
        bram_i.mem[ 2] = 32'h0020a023; // sw   x2,0(x1)
        bram_i.mem[ 3] = 32'h0000a183; // lw   x3,0(x1)
        bram_i.mem[ 4] = 32'h10000213; // addi x4,x0,256
        bram_i.mem[ 5] = 32'h00322023; // sw   x3,0(x4)
        bram_i.mem[ 6] = 32'h00022283; // lw   x5,0(x4)
        bram_i.mem[ 7] = 32'h00128293; // addi x5,x5,1
        bram_i.mem[ 8] = 32'h0050a223; // sw   x5,4(x1)
        bram_i.mem[ 9] = 32'h00100313; // addi x6,x0,1
        bram_i.mem[10] = 32'h0060a423; // sw   x6,8(x1)
        bram_i.mem[11] = 32'h0000006f; // jal  x0,0

        repeat (5) @(negedge clk);
        rst = 1'b0;
        for (i = 0; i < 2000; i = i + 1) begin
            @(negedge clk);
            if (cpu_trap)
                $fatal(1, "[FAIL] PicoRV32 trap at PC 0x%08x", cpu_addr);
            if (done) begin
                repeat (12) @(negedge clk);
                if (wb_writes !== 3 || wb_reads !== 1)
                    $fatal(1, "[FAIL] Wishbone transfer counts writes=%0d reads=%0d",
                           wb_writes, wb_reads);
                if (bram_i.mem[64] !== 32'h000000a5)
                    $fatal(1, "[FAIL] BRAM store/load data: 0x%08x", bram_i.mem[64]);
                if (cpu_responses < 15)
                    $fatal(1, "[FAIL] too few CPU memory responses: %0d", cpu_responses);
                $display("[PASS] PicoRV32 + registered response + BRAM + Wishbone");
                $display("[PASS] MMIO writes=3, MMIO reads=1, BRAM[0x100]=0x%08x",
                         bram_i.mem[64]);
                $finish;
            end
        end
        $fatal(1, "[FAIL] CPU/bridge integration timeout");
    end
endmodule
`default_nettype wire
