/*
 * Run the actual read-only flash diagnostic firmware on SERV.
 * The USB, UART, SPI and endpoint registers are Wishbone mocks; this is
 * not a PHY, enumeration, or actual flash transaction simulation.
 *
 * Expected sequence: RV32I startup -> debug UART/LED -> stack/BSS ->
 * SPI deselect -> USB descriptor reset -> USB attach -> USB CSR polling.
 * SPDX-License-Identifier: BSD-3-Clause
 */
`timescale 1ns/1ps
`default_nettype none
module tb_ulx5m_serv_firmware_boot;
    localparam integer RAM_AW = 13;
    localparam integer WB_N = 5;
    localparam integer MAX_CYCLES = 2000000;

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
    wire [WB_N-1:0] wb_cyc;
    wire wb_we;
    reg [WB_N-1:0] wb_ack = 5'b00000;
    wire [WB_N*32-1:0] wb_rdata;
    reg [31:0] usb_csr = 32'h00000000;

    integer cycle_count = 0;
    integer instr_fetches = 0;
    integer uart_writes = 0;
    integer led_writes = 0;
    integer ep_writes = 0;
    integer usb_poll_reads = 0;
    integer spi_data_writes = 0;
    reg uart_div_seen = 1'b0;
    reg led_1_seen = 1'b0;
    reg led_3_seen = 1'b0;
    reg led_7_seen = 1'b0;
    reg spi_deselect_seen = 1'b0;
    reg usb_reset_seen = 1'b0;
    reg usb_attach_seen = 1'b0;
    reg stack_write_seen = 1'b0;
    reg [1023:0] fw_path;
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
        .cpu_valid(cpu_valid), .cpu_ready(cpu_ready),
        .cpu_rdata(cpu_rdata), .bridge_valid(bridge_valid),
        .bridge_ready(bridge_ready), .bridge_rdata(bridge_rdata)
    );

    soc_bridge #(
        .RAM_AW(RAM_AW), .WB_N(WB_N), .WB_DW(32),
        .WB_AW(16), .WB_AI(2), .WB_REG(4), .BRAM_REG(1)
    ) bridge_i (
        .pb_addr(cpu_addr), .pb_rdata(bridge_rdata),
        .pb_wdata(cpu_wdata), .pb_wstrb(cpu_wstrb),
        .pb_valid(bridge_valid), .pb_ready(bridge_ready),
        .bram_addr(bram_addr), .bram_rdata(bram_rdata),
        .bram_wdata(bram_wdata), .bram_wmsk(bram_wmsk),
        .bram_we(bram_we),
        .wb_addr(wb_addr), .wb_wdata(wb_wdata),
        .wb_wmsk(wb_wmsk), .wb_rdata(wb_rdata),
        .wb_cyc(wb_cyc), .wb_we(wb_we), .wb_ack(wb_ack),
        .clk(clk), .rst(rst)
    );

    soc_bram #(.AW(RAM_AW), .INIT_FILE("")) bram_i (
        .addr(bram_addr), .rdata(bram_rdata),
        .wdata(bram_wdata), .wmsk(bram_wmsk),
        .we(bram_we), .clk(clk)
    );

    // Peripherals return one ACK per bus cycle, as in the existing SoC.
    // USB CSR at 0x82000000 is the only nonzero MMIO read value needed
    // for firmware initialization and idle polling without host packets.
    assign wb_rdata[ 31:  0] = 32'h00000000; // Misc
    assign wb_rdata[ 63: 32] = 32'h00000000; // UART
    assign wb_rdata[ 95: 64] = (wb_addr == 16'h0000) ? usb_csr : 32'h00000000;
    assign wb_rdata[127: 96] = 32'h00000000; // Endpoint RAM
    assign wb_rdata[159:128] = 32'h00000000; // QSPI

    always @(posedge clk) begin
        if (rst) begin
            wb_ack <= 5'b00000;
        end else begin
            wb_ack <= wb_cyc & ~wb_ack;
            cycle_count <= cycle_count + 1;

            if (cpu_valid && cpu_ready && cpu_instr) begin
                instr_fetches <= instr_fetches + 1;
                if (cpu_addr[31] || cpu_addr >= 32'h00008000 || cpu_addr[1:0] != 2'b00)
                    $fatal(1, "[FAIL] instruction fetch outside aligned 32 KiB BRAM: %08x", cpu_addr);
            end
            if (bram_we && (bram_addr >= 13'h1c00))
                stack_write_seen <= 1'b1;

            if (wb_cyc[0] && !wb_ack[0] && wb_we && wb_addr == 16'h0000) begin
                led_writes <= led_writes + 1;
                if (wb_wdata == 32'h00000001) led_1_seen <= 1'b1;
                if (wb_wdata == 32'h00000003) led_3_seen <= 1'b1;
                if (wb_wdata == 32'h00000007) led_7_seen <= 1'b1;
            end
            if (wb_cyc[1] && !wb_ack[1] && wb_we) begin
                uart_writes <= uart_writes + 1;
                if (wb_addr == 16'h0001 && wb_wdata == 32'd414)
                    uart_div_seen <= 1'b1;
            end
            if (wb_cyc[2] && !wb_ack[2]) begin
                // USB endpoint descriptors live at 0x82002000 (bank 2).
                if (wb_we && wb_addr >= 16'h0800)
                    ep_writes <= ep_writes + 1;
                if (wb_we && wb_addr == 16'h0000) begin
                    usb_csr <= wb_wdata;
                    if (wb_wdata == 32'h00001080)
                        usb_reset_seen <= 1'b1;
                    if (wb_wdata == 32'h00009080 && usb_reset_seen)
                        usb_attach_seen <= 1'b1;
                end
                if (!wb_we && wb_addr == 16'h0000 && usb_attach_seen)
                    usb_poll_reads <= usb_poll_reads + 1;
            end
            if (wb_cyc[4] && !wb_ack[4] && wb_we) begin
                if (wb_addr == 16'h0000 && wb_wdata == 32'h00010f00)
                    spi_deselect_seen <= 1'b1;
                if (wb_addr == 16'h0001) begin
                    spi_data_writes <= spi_data_writes + 1;
                    $fatal(1, "[FAIL] unexpected SPI data write during idle startup: %08x", wb_wdata);
                end
            end
        end
    end

    initial begin
        if (!$value$plusargs("firmware=%s", fw_path))
            $fatal(1, "[FAIL] provide +firmware=path/to/SERV/fw_ulx5m_flash_read.hex");
        for (i = 0; i < (1 << RAM_AW); i = i + 1)
            bram_i.mem[i] = 32'h00000000;
        $readmemh(fw_path, bram_i.mem);
        // The SERV-specific start.S must initialize sp with lui sp,0x8.
        if (bram_i.mem[0] !== 32'h00000093 || bram_i.mem[1] !== 32'h00008137)
            $fatal(1, "[FAIL] image is not RV32I SERV startup (missing sp=0x8000): %08x %08x",
                   bram_i.mem[0], bram_i.mem[1]);

        repeat (5) @(negedge clk);
        rst = 1'b0;
        for (i = 0; i < MAX_CYCLES; i = i + 1) begin
            @(negedge clk);
            if (usb_attach_seen && usb_poll_reads >= 3) begin
                if (!uart_div_seen || !led_1_seen || !led_3_seen || !led_7_seen)
                    $fatal(1, "[FAIL] missing UART or LED startup stage");
                if (!spi_deselect_seen || !stack_write_seen)
                    $fatal(1, "[FAIL] SPI deselect or stack write missing");
                if (ep_writes < 160 || spi_data_writes != 0)
                    $fatal(1, "[FAIL] unexpected endpoint init or SPI writes: ep=%0d spi=%0d",
                           ep_writes, spi_data_writes);
                $display("[PASS] SERV executed actual RV32I firmware from reset");
                $display("[PASS] UART/LED startup, stack, SPI deselect, endpoint initialization");
                $display("[PASS] USB CSR setup, pull-up enable, and idle polling");
                $display("[INFO] cycles=%0d fetches=%0d uart=%0d leds=%0d endpoint_writes=%0d polls=%0d",
                         cycle_count, instr_fetches, uart_writes, led_writes, ep_writes, usb_poll_reads);
                $finish;
            end
        end
        $fatal(1, "[FAIL] SERV firmware startup timeout: cycles=%0d fetches=%0d UART=%0d LED=%0d EP=%0d SPI_deselect=%0d USB_reset=%0d USB_attach=%0d polls=%0d",
               cycle_count, instr_fetches, uart_writes, led_writes, ep_writes,
               spi_deselect_seen, usb_reset_seen, usb_attach_seen, usb_poll_reads);
    end
endmodule
`default_nettype wire
