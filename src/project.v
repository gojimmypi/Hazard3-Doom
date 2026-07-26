/*
 * Copyright (c) 2026 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// TinyTapeout FPGA smoke-test design for the Hazard3-Doom repository.
//
// This module intentionally tests the TinyTapeout FPGA wrapper and tool flow;
// the full Hazard3-Doom SoC is built by the dedicated ULX3S/ULX4M workflows.
module tt_um_ulx3s_example (
`ifdef OTHER_SHUTTLKE
    input  wire       VGND,
    input  wire       VDPWR,    // 3.3v core power supply
//  input  wire       VAPWR,    // second analog power supply (VAA)
`endif
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    inout  wire [7:0] ua,       // Analog pins, only ua[5:0] can be used
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // Use visible counter bits so the low output nibble blinks at a human-
    // observable rate over the normal TinyTapeout FPGA clock range.
    reg [25:0] counter;

    always @(posedge clk) begin
        if (!rst_n) begin
            counter <= 26'd0;
        end else if (ena) begin
            counter <= counter + 26'd1;
        end
    end

    // 0xD identifies this as the Hazard3-Doom TinyTapeout smoke image.
    assign uo_out = {4'hD, counter[25:22]};

    // Do not drive the bidirectional TinyTapeout pins in this smoke test.
    assign uio_out = 8'h00;
    assign uio_oe  = 8'h00;

    // Keep otherwise-unused standard TinyTapeout inputs intentional.
    wire _unused = &{ui_in, uio_in, 1'b0};

endmodule

`default_nettype wire
