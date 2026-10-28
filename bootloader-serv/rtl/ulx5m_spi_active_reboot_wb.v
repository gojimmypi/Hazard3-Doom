/* GateMate SPI-active secondary boot controller.
 * v73 opt-in: v72 hardware-proven registered 27-byte status command, followed
 * by RECFG. The ROM MUST be derived from THIS packed primary bitstream.
 * Default (without ULX5M_V73_REGISTERED_REBOOT) retains v47 RECFG-only
 * behavior for historical builds. This module never writes flash.
 */
`default_nettype none
module ulx5m_spi_active_reboot_wb #(
    // Equivalent startup hold to proven v72 (2^26 cycles at 25 MHz).
    // 128849019 cycles / 48 MHz = 2.684 seconds.
    parameter integer V78_BOOT_DELAY_CYCLES = 128849019
) (
    input wire clk, rst,
    input wire normal_mode, spi_idle,
    input wire [2:0] bus_addr,
    input wire [31:0] bus_wdata,
    output reg [31:0] bus_rdata = 32'd0,
    input wire bus_cyc, bus_we,
    output reg bus_ack = 1'b0,
    output reg release_spi = 1'b0
);
    localparam [31:0] ARM_KEY = 32'h41524d31; /* ARM1 */
    localparam [31:0] BOOT_KEY = 32'h424f4f54; /* BOOT */
    reg [4:0] spi_idle_cycles = 0;
    reg armed = 1'b0;
    reg fired = 1'b0;
    reg error = 1'b0;
    reg recfg = 1'b0;
`ifdef ULX5M_V78_V72_STARTUP_DELAY
    // The successful v72 probe waits approximately 2.68 seconds before
    // starting CC_CFG_CTRL. v76 started immediately after BTN2 latched.
    reg [27:0] v78_boot_count = 28'd0;
    reg v78_boot_ready = 1'b0;
`endif
`ifdef ULX5M_V73_REGISTERED_REBOOT
    localparam integer CMD_LEN = 27;
    localparam [2:0] S_IDLE = 3'd0, S_RELEASE = 3'd1,
                     S_EN = 3'd2, S_SEND = 3'd3, S_NEXT = 3'd4,
                     S_TAIL = 3'd5, S_WAIT = 3'd6, S_RECFG = 3'd7;
    reg [7:0] cmd_rom [0:CMD_LEN-1];
    initial $readmemh("build-ulx5m-gs/v73-normal-boot-dfu-hw-native/cmd.hex", cmd_rom);
    reg [2:0] cfg_state = S_IDLE;
    reg [4:0] cfg_addr = 5'd0;
    reg [5:0] cfg_count = 6'd0;
    reg cfg_en = 1'b0;
    reg cfg_valid = 1'b0;
    reg [7:0] cfg_data = 8'h00;
`else
    reg handoff_pending = 1'b0;
`endif
    wire qualified = normal_mode && spi_idle && (&spi_idle_cycles);
    wire write_req = bus_cyc && !bus_ack && bus_we;
    wire read_req = bus_cyc && !bus_ack && !bus_we;

`ifdef ULX5M_V73_REGISTERED_REBOOT
    // Registered interface from v72. At 48 MHz, double its 25 MHz
    // cycle intervals to preserve the physically proven real-time pacing.
    // One clock domain: no generated clock or CDC logic.
    CC_CFG_CTRL cfg_i (
        .CLK(clk), .EN(cfg_en), .DATA(cfg_data),
        .VALID(cfg_valid), .RECFG(recfg)
    );
`else
    // Historical v47 RECFG-only controller, intentionally unchanged.
    CC_CFG_CTRL cfg_i (
        .CLK(1'b0), .EN(1'b0), .DATA(8'b0),
        .VALID(1'b0), .RECFG(recfg)
    );
`endif

    always @(posedge clk) begin
        if (rst || !normal_mode) begin
            spi_idle_cycles <= 0;
`ifdef ULX5M_V78_V72_STARTUP_DELAY
            v78_boot_count <= 28'd0;
            v78_boot_ready <= 1'b0;
`endif
            armed <= 0;
            fired <= 0;
            error <= 0;
            recfg <= 0;
            release_spi <= 0;
`ifdef ULX5M_V73_REGISTERED_REBOOT
            cfg_state <= S_IDLE;
            cfg_addr <= 0;
            cfg_count <= 0;
            cfg_en <= 0;
            cfg_valid <= 0;
            cfg_data <= 0;
`else
            handoff_pending <= 0;
`endif
            bus_ack <= 0;
            bus_rdata <= 0;
        end else begin
            bus_ack <= bus_cyc && !bus_ack;
`ifdef ULX5M_V78_V72_STARTUP_DELAY
            // The flash pins are already released in normal mode at the PHY.
            // Count only after the startup button selection is final.
            if (!v78_boot_ready) begin
                if (v78_boot_count == V78_BOOT_DELAY_CYCLES - 1)
                    v78_boot_ready <= 1'b1;
                else
                    v78_boot_count <= v78_boot_count + 1'b1;
            end
`endif
`ifdef ULX5M_V73_REGISTERED_REBOOT
            // With BOOT accepted, hold flash pads high-Z before issuing
            // any configuration command. Do not request reconfiguration if
            // the fabric SPI controller becomes busy again before handoff.
            if (cfg_state != S_IDLE && cfg_state != S_RECFG && !spi_idle) begin
                cfg_state <= S_IDLE;
                cfg_en <= 0;
                cfg_valid <= 0;
                error <= 1'b1;
            end else begin
                case (cfg_state)
                    S_RELEASE: begin
                        cfg_count <= cfg_count + 1'b1;
                        if (cfg_count == 6'd63) begin
                            cfg_count <= 0;
                            cfg_state <= S_EN;
                        end
                    end
                    S_EN: begin
                        cfg_en <= 1'b1;
                        cfg_count <= cfg_count + 1'b1;
                        if (cfg_count == 6'd7)
                            cfg_state <= S_SEND;
                    end
                    S_SEND: begin
                        cfg_data <= cmd_rom[cfg_addr];
                        cfg_valid <= 1'b1;
                        cfg_count <= 0;
                        cfg_state <= S_NEXT;
                    end
                    S_NEXT: begin
                        cfg_valid <= 1'b0;
                        cfg_count <= cfg_count + 1'b1;
                        if (cfg_count == 6'd2) begin
                            cfg_addr <= cfg_addr + 1'b1;
                            cfg_count <= 0;
                            cfg_state <= (cfg_addr == CMD_LEN - 1) ? S_TAIL : S_SEND;
                        end
                    end
                    S_TAIL: begin
                        cfg_count <= cfg_count + 1'b1;
                        if (cfg_count == 6'd15) begin
                            cfg_count <= 0;
                            cfg_state <= S_WAIT;
                        end
                    end
                    S_WAIT: begin
                        cfg_en <= 1'b0;
                        cfg_count <= cfg_count + 1'b1;
                        if (cfg_count == 6'd31)
                            cfg_state <= S_RECFG;
                    end
                    S_RECFG: recfg <= 1'b1;
                    default: ;
                endcase
            end
`else
            // Legacy v47: release pads one cycle before RECFG only.
            if (handoff_pending) begin
                recfg <= 1'b1;
                handoff_pending <= 1'b0;
            end
`endif
`ifdef ULX5M_V76_HW_NORMAL_BOOT
            // Normal mode uses the v72-style autonomous hardware handoff.
            // No firmware SPI reads or Wishbone ARM/BOOT transaction is needed.
            if (!fired && cfg_state == S_IDLE && (&spi_idle_cycles)
`ifdef ULX5M_V78_V72_STARTUP_DELAY
                && v78_boot_ready
`endif
                ) begin
                release_spi <= 1'b1;
                cfg_state <= S_RELEASE;
                cfg_count <= 0;
                cfg_addr <= 0;
                fired <= 1'b1;
                armed <= 1'b0;
            end
`endif
            if (!spi_idle) begin
                spi_idle_cycles <= 0;
                if (armed)
                    error <= 1'b1;
                armed <= 0;
            end else if (!(&spi_idle_cycles)) begin
                spi_idle_cycles <= spi_idle_cycles + 1'b1;
            end
            if (read_req) begin
                case (bus_addr)
                    3'd0: bus_rdata <= {27'd0, 1'b1, error, fired,
                                        armed, qualified};
                    default: bus_rdata <= 32'd0;
                endcase
            end
            // In delayed autonomous mode, firmware writes must not bypass
            // the v72 startup hold. Normal-mode SERV may still execute.
            if (write_req && !fired
`ifdef ULX5M_V78_V72_STARTUP_DELAY
`ifdef ULX5M_V76_HW_NORMAL_BOOT
                && 1'b0
`endif
`endif
                ) begin
                if (bus_addr == 3'd1 && bus_wdata == ARM_KEY &&
                    qualified && !error) begin
                    armed <= 1'b1;
                end else if (bus_addr == 3'd2 && bus_wdata == BOOT_KEY &&
                             armed && qualified && !error) begin
                    release_spi <= 1'b1;
`ifdef ULX5M_V73_REGISTERED_REBOOT
                    cfg_state <= S_RELEASE;
                    cfg_count <= 0;
                    cfg_addr <= 0;
`else
                    handoff_pending <= 1'b1;
`endif
                    fired <= 1'b1;
                    armed <= 1'b0;
                end else begin
                    armed <= 1'b0;
                    error <= 1'b1;
                end
            end
        end
    end
endmodule
`default_nettype wire
