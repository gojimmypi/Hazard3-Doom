/* -----------------------------------------------------------------------------
 * File:        tb_apb_sao_bridge.v
 * Path:        tests/sao-bridge/tb_apb_sao_bridge.v
 *
 * Project:     Hazard3-Doom
 * Purpose:     Verify APB, I2C, GPIO, timeout, and ESP32 arbitration behavior of
 *              the SAO bridge.
 *
 * Copyright (c) 2026 gojimmypi
 *
 * This source describes Open Hardware and is licensed under the CERN
 * Open Hardware License Version 2 - Weakly Reciprocal.
 *
 * SPDX-License-Identifier: CERN-OHL-W-2.0
 *
 * This source is provided WITHOUT ANY EXPRESS OR IMPLIED WARRANTY.
 * See LICENSES/CERN-OHL-W-2.0.txt for the complete license terms.
 * See LICENSING.md for project licensing policy and scope.
 * -------------------------------------------------------------------------- */

`default_nettype none

`timescale 1ns/1ps

module tb_apb_sao_bridge;

reg clk = 1'b0;
reg rst_n = 1'b0;
always #10 clk = ~clk; // 50 MHz

reg psel = 1'b0;
reg penable = 1'b0;
reg pwrite = 1'b0;
reg [15:0] paddr = 16'd0;
reg [31:0] pwdata = 32'd0;
wire [31:0] prdata;
wire pready;
wire pslverr;

wire master_sda_low;
wire master_scl_low;
reg slave_sda_low = 1'b0;
reg slave_scl_low = 1'b0;
wire sda_line = master_sda_low || slave_sda_low ? 1'b0 : 1'b1;
wire scl_line = master_scl_low || slave_scl_low ? 1'b0 : 1'b1;

reg gpio1_i = 1'b0;
reg gpio2_i = 1'b1;
wire gpio1_o;
wire gpio1_oe;
wire gpio2_o;
wire gpio2_oe;
wire i2c_busy;
wire i2c_bus_active;
reg i2c_enable = 1'b1;
reg esp_owner = 1'b0;
reg esp_request = 1'b0;

apb_sao_bridge #(
    .CLK_DIV_RESET(16'd4),
    .TIMEOUT_RESET(32'd64)
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .apbs_psel(psel),
    .apbs_penable(penable),
    .apbs_pwrite(pwrite),
    .apbs_paddr(paddr),
    .apbs_pwdata(pwdata),
    .apbs_prdata(prdata),
    .apbs_pready(pready),
    .apbs_pslverr(pslverr),
    .sao_sda_i(sda_line),
    .sao_scl_i(scl_line),
    .sao_sda_drive_low(master_sda_low),
    .sao_scl_drive_low(master_scl_low),
    .sao_gpio1_i(gpio1_i),
    .sao_gpio1_o(gpio1_o),
    .sao_gpio1_oe(gpio1_oe),
    .sao_gpio2_i(gpio2_i),
    .sao_gpio2_o(gpio2_o),
    .sao_gpio2_oe(gpio2_oe),
    .i2c_enable(i2c_enable),
    .i2c_busy(i2c_busy),
    .i2c_bus_active(i2c_bus_active),
    .esp_owner(esp_owner),
    .esp_request(esp_request)
);

task apb_write;
    input [15:0] address;
    input [31:0] data;
    begin
        @(posedge clk);
        psel <= 1'b1;
        penable <= 1'b0;
        pwrite <= 1'b1;
        paddr <= address;
        pwdata <= data;
        @(posedge clk);
        penable <= 1'b1;
        @(posedge clk);
        psel <= 1'b0;
        penable <= 1'b0;
        pwrite <= 1'b0;
    end
endtask

task apb_read;
    input [15:0] address;
    output [31:0] data;
    begin
        @(posedge clk);
        psel <= 1'b1;
        penable <= 1'b0;
        pwrite <= 1'b0;
        paddr <= address;
        @(posedge clk);
        penable <= 1'b1;
        #1 data = prdata;
        @(posedge clk);
        psel <= 1'b0;
        penable <= 1'b0;
    end
endtask

task wait_done;
    reg [31:0] status;
    integer n;
    begin : wait_loop
        for (n = 0; n < 1000; n = n + 1) begin
            apb_read(16'h9004, status);
            if (!status[0] && status[1]) begin
                disable wait_loop;
            end
        end
        $display("ERROR: command did not complete");
        $finish;
    end
endtask

reg [31:0] value;

initial begin
    $dumpfile("tb_apb_sao_bridge.vcd");
    $dumpvars(0, tb_apb_sao_bridge);

    repeat (4) @(posedge clk);
    rst_n <= 1'b1;
    repeat (4) @(posedge clk);

    apb_read(16'h9020, value);
    if (value !== 32'h53414f31) begin
        $display("ERROR: ID register %08x", value);
        $finish;
    end

    apb_read(16'h9024, value);
    if (value !== 32'h00020100) begin
        $display("ERROR: VERSION register %08x", value);
        $finish;
    end

    apb_read(16'h9028, value);
    if (value !== 32'd0) begin
        $display("ERROR: OWNER register %08x", value);
        $finish;
    end

    esp_request <= 1'b1;
    esp_owner <= 1'b1;
    repeat (2) @(posedge clk);
    apb_read(16'h9028, value);
    if (value[1:0] !== 2'b11) begin
        $display("ERROR: OWNER/request visibility %08x", value);
        $finish;
    end
    apb_read(16'h9004, value);
    if (value[13:12] !== 2'b11) begin
        $display("ERROR: STATUS owner/request visibility %08x", value);
        $finish;
    end
    esp_request <= 1'b0;
    esp_owner <= 1'b0;
    repeat (2) @(posedge clk);

    // Arbitration disables new Hazard3 I2C commands without changing APB.
    i2c_enable <= 1'b0;
    apb_write(16'h9000, 32'd1); // START must be rejected
    apb_read(16'h9004, value);
    if (!value[5] || value[0]) begin
        $display("ERROR: disabled I2C command was not rejected %08x", value);
        $finish;
    end
    i2c_enable <= 1'b1;

    apb_write(16'h9018, 32'h0000000b); // GPIO1 out=1/oe=1, GPIO2 out=0/oe=1
    if (!gpio1_oe || !gpio1_o || !gpio2_oe || gpio2_o) begin
        $display("ERROR: GPIO control");
        $finish;
    end

    apb_write(16'h9000, 32'd1); // START
    wait_done();
    apb_read(16'h9004, value);
    if (!value[6]) begin
        $display("ERROR: bus_active not set after START");
        $finish;
    end

    // Force SDA low so the slave ACKs the byte.
    slave_sda_low <= 1'b1;
    apb_write(16'h9008, 32'h000000a8);
    apb_write(16'h9000, 32'd3); // WRITE
    wait_done();
    apb_read(16'h9004, value);
    if (!value[2]) begin
        $display("ERROR: ACK not observed");
        $finish;
    end
    slave_sda_low <= 1'b0;

    apb_write(16'h9000, 32'd2); // STOP
    wait_done();
    apb_read(16'h9004, value);
    if (value[6]) begin
        $display("ERROR: bus_active still set after STOP");
        $finish;
    end

    // Exercise recovery with an idle bus.
    apb_write(16'h9000, 32'd6);
    wait_done();
    apb_read(16'h9004, value);
    if (!value[11]) begin
        $display("ERROR: recovery did not report success");
        $finish;
    end

    $display("PASS: tb_apb_sao_bridge");
    $finish;
end

endmodule

`default_nettype wire
