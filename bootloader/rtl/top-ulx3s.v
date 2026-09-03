/*
 * top.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019  Sylvain Munaut <tnt@246tNt.com>
 * All rights reserved.
 *
 * BSD 3-clause, see LICENSE.bsd
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the <organization> nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

// define none or one of:
`ifdef BOARD_ULX3S_V20
`define i2c_bridge_v20
`endif
`ifdef BOARD_ULX3S_V314
`define i2c_bridge_v316
`endif
`ifdef BOARD_ULX3S_V317
`define i2c_bridge_v316
`endif

`default_nettype none

module top 
#(
	parameter serial_debug = 0 // 0:ESP32 passthru, 1:RISC-V CPU debug console
)
(
	// Clock
	input  wire clk_25mhz,

	// LEDs
	output wire [7:0] led,

	// Buttons
	input  wire [6:0] btn,
	
	// DIP switches
	input  wire [3:0] sw,
	
	// Debug or esp32 passthru UART
	input  wire ftdi_txd,
	output wire ftdi_rxd,
        input  wire ftdi_ndtr,
        input  wire ftdi_nrts,

	// ESP32 passthru
	input  wire wifi_txd,
	output wire wifi_rxd,
        input  wire wifi_gpio15, wifi_gpio14,
        inout  wire wifi_gpio13, wifi_gpio12,
        inout  wire wifi_gpio4 , wifi_gpio2 , wifi_gpio0 ,
        inout  wire wifi_en,
        output wire sd_wp, // BGA pin exists but not connected on PCB

        // ESP32 I2C bridge
        `ifdef i2c_bridge_v20    // ULX3S v2.x.x or v3.0.x
        inout  wire wifi_gpio16, // i2c sda ESP32 v3.0.x
        inout  wire wifi_gpio17, // i2c scl ESP32 v3.0.x
        inout  wire gpdi_sda,    // i2c sda RTC and GPDI
        inout  wire gpdi_scl,    // i2c scl RTC and GPDI
        `endif
        `ifdef i2c_bridge_v316   // ULX3S v3.1.x
        inout  wire wifi_gpio22, // i2c sda ESP32 v3.1.6
        inout  wire wifi_gpio21, // i2c scl ESP32 v3.1.6
        inout  wire gpdi_sda,    // i2c sda RTC and GPDI
        inout  wire gpdi_scl,    // i2c scl RTC and GPDI
        `endif

	// SPI Flash
	inout  wire flash_mosi,
	inout  wire flash_miso,
	inout  wire flash_wpn,
	inout  wire flash_holdn,
	inout  wire flash_csn,

	// USB
	inout  wire usb_fpga_bd_dp,
	inout  wire usb_fpga_bd_dn,
	output wire usb_fpga_pu_dp,

	// Boot
	output wire user_programn
);

	// Config
	// ------

	localparam RAM_AW = 13;	/* 8k x 32 = 32 kbytes */

	localparam WB_N  =  5;
	localparam WB_DW = 32;
	localparam WB_AW = 16;
	localparam WB_AI =  2;


	// Signals
	// -------

	// Memory bus
	wire        mem_valid;
	wire        mem_instr;
	wire        mem_ready;
	wire [31:0] mem_addr;
	wire [31:0] mem_rdata;
	wire [31:0] mem_wdata;
	wire [ 3:0] mem_wstrb;

	// BRAM
	wire [RAM_AW-1:0] bram_addr;
	wire [31:0] bram_rdata;
	wire [31:0] bram_wdata;
	wire [ 3:0] bram_wmsk;
	wire        bram_we;

	// Wishbone
	wire [WB_AW-1:0] wb_addr;
	wire [WB_DW-1:0] wb_wdata;
	wire [(WB_DW/8)-1:0] wb_wmsk;
	wire [WB_DW-1:0] wb_rdata [0:WB_N-1];
	wire [(WB_DW*WB_N)-1:0] wb_rdata_flat;
	wire [WB_N-1:0] wb_cyc;
	wire wb_we;
	wire [WB_N-1:0] wb_ack;

	// USB EP Buffer
	wire [ 8:0] ep_tx_addr_0;
	wire [31:0] ep_tx_data_0;
	wire ep_tx_we_0;

	wire [ 8:0] ep_rx_addr_0;
	wire [31:0] ep_rx_data_1;
	wire ep_rx_re_0;

	// Deal with non standard IOs
	wire flash_sck;
	wire flash_cs;

	// BTN remapper
	wire [7:0] btn_remap_o, btn_remap_i;

	// Clocks / Reset
	wire clk_48m;
	wire rst;

	// Genvar
	genvar i;

	// Diagnostics
	wire locked;
	//assign diag = {rst, clk_48m};

	wire pass_uart_rxd = serial_debug ? 1 : ftdi_txd;
	wire boot_uart_rxd = serial_debug ? ftdi_txd : 1;
	wire pass_uart_txd, boot_uart_txd;
	assign ftdi_rxd = serial_debug ? boot_uart_txd : pass_uart_txd;
	
	// this is not needed for bootloader but it's
	// good for user convenience to access and
	// flash ESP32 over US1.
	esp32_passthru
	#(
		.C_powerup_en_time(0) // 0: normal, 10: v3.1.6 workaround but then uftpd will have problems
	)
	esp32_passthru_I
	(
		.clk_25mhz(clk_25mhz),
		.btn(btn_remap_o),
		//.led(led),
		.ftdi_txd(pass_uart_rxd),
		.ftdi_rxd(pass_uart_txd),
		.ftdi_ndtr(ftdi_ndtr),
		.ftdi_nrts(ftdi_nrts),
		.wifi_txd(wifi_txd),
		.wifi_rxd(wifi_rxd),
		.wifi_gpio15(wifi_gpio15),
		.wifi_gpio14(wifi_gpio14),
		.wifi_gpio13(wifi_gpio13),
		.wifi_gpio12(wifi_gpio12),
		.wifi_gpio4(wifi_gpio4),
		.wifi_gpio2(wifi_gpio2),
		.wifi_gpio0(wifi_gpio0),
		.wifi_en(wifi_en),
		//  wifi_gpio5 // v3.0.x, not available on v3.1.x
		`ifdef i2c_bridge_v20   // ULX3S v2.x.x or v3.0.x
		.wifi_sda(wifi_gpio16), // I2C ESP32 for v3.0.x
		.wifi_scl(wifi_gpio17), // I2C ESP32 for v3.0.x
		.gpdi_sda(gpdi_sda),    // I2C board GPDI and RTC
		.gpdi_scl(gpdi_scl),    // I2C board GPDI and RTC
		`endif
		`ifdef i2c_bridge_v316  // ULX3S v3.1.x
		.wifi_sda(wifi_gpio22), // I2C ESP32 for v3.1.6
		.wifi_scl(wifi_gpio21), // I2C ESP32 for v3.1.6
		.gpdi_sda(gpdi_sda),    // I2C board GPDI and RTC
		.gpdi_scl(gpdi_scl),    // I2C board GPDI and RTC
		`endif
		.nc(sd_wp) // BGA pin exists but not connected on PCB
	);

	// -------- BOOTLOADER CODE ----------

	// SoC
	// ---

	// PicoRV32
	picorv32 #(
		.PROGADDR_RESET(32'h 0000_0000),
		.STACKADDR(4 << RAM_AW),
		.BARREL_SHIFTER(0),
		.COMPRESSED_ISA(1),
		.ENABLE_COUNTERS(0),
		.ENABLE_COUNTERS64(0),
		.ENABLE_MUL(0),
		.ENABLE_DIV(0),
		.ENABLE_IRQ(0),
		.ENABLE_IRQ_QREGS(0),
		.CATCH_MISALIGN(0),
		.CATCH_ILLINSN(0)
	) cpu_I (
		.clk       (clk_48m),
		.resetn    (~rst),
		.mem_valid (mem_valid),
		.mem_instr (mem_instr),
		.mem_ready (mem_ready),
		.mem_addr  (mem_addr),
		.mem_wdata (mem_wdata),
		.mem_wstrb (mem_wstrb),
		.mem_rdata (mem_rdata)
	);

	// Bridge
	soc_bridge #(
		.RAM_AW(RAM_AW),
		.WB_N(WB_N),
		.WB_DW(WB_DW),
		.WB_AW(WB_AW),
		.WB_AI(WB_AI)
	) pb_I (
		.pb_addr(mem_addr),
		.pb_rdata(mem_rdata),
		.pb_wdata(mem_wdata),
		.pb_wstrb(mem_wstrb),
		.pb_valid(mem_valid),
		.pb_ready(mem_ready),
		.bram_addr(bram_addr),
		.bram_rdata(bram_rdata),
		.bram_wdata(bram_wdata),
		.bram_wmsk(bram_wmsk),
		.bram_we(bram_we),
		.wb_addr(wb_addr),
		.wb_wdata(wb_wdata),
		.wb_wmsk(wb_wmsk),
		.wb_rdata(wb_rdata_flat),
		.wb_cyc(wb_cyc),
		.wb_we(wb_we),
		.wb_ack(wb_ack),
		.clk(clk_48m),
		.rst(rst)
	);

	for (i=0; i<WB_N; i=i+1)
		assign wb_rdata_flat[i*WB_DW+:WB_DW] = wb_rdata[i];

	// RAM
	soc_bram #(
		.AW(RAM_AW),
		.INIT_FILE("boot.hex")
	) bram_I (
		.addr(bram_addr),
		.rdata(bram_rdata),
		.wdata(bram_wdata),
		.wmsk(bram_wmsk),
		.we(bram_we),
		.clk(clk_48m)
	);

	// BTN remapper (after debouncer in soc_had_misc)
	assign btn_remap_i = ~ // invert all, RISC-V FW inverts it back
	{
	  btn_remap_o[2]   , // BTN2 hold and plug USB to write protect flash and upgrade bootloader
	  btn_remap_o[1]     // BTN1 hold and plug USB to stay in bootloader
	| btn_remap_o[7]   , // DIP SW1=ON is the same as BTN1 hold
	  btn_remap_o[6:3] , // reserved
	  1'b0             , // disabled
	 ~btn_remap_o[0]     // BTN0 reserved, (BTN0 has inverted logic on ULX3S)
	};
	// For buttonless boards use this remapper
	// and execute user bistream with
	// dfu-util -a 0 -e
	//assign btn_remap_i = ~8'b01000000;

	// Peripheral [0] : Misc
	soc_had_misc had_misc_I (
		.led(led),
		.btn({sw[0],btn}),
		.btn_remap_o(btn_remap_o),
		.btn_remap_i(btn_remap_i),
		.programn(user_programn),
		.bus_addr(wb_addr[3:0]),
		.bus_wdata(wb_wdata),
		.bus_rdata(wb_rdata[0]),
		.bus_cyc(wb_cyc[0]),
		.bus_ack(wb_ack[0]),
		.bus_we(wb_we),
		//.fsel_c(fsel_c),
		//.fsel_d(fsel_d),
		.clk(clk_48m),
		.rst(rst)
	);

	// Peripheral [1] : UART
	uart_wb #(
		.DIV_WIDTH(16),
		.DW(WB_DW)
	) uart_I (
		.uart_tx(boot_uart_txd),
		.uart_rx(boot_uart_rxd),
		.bus_addr(wb_addr[1:0]),
		.bus_wdata(wb_wdata),
		.bus_rdata(wb_rdata[1]),
		.bus_cyc(wb_cyc[1]),
		.bus_ack(wb_ack[1]),
		.bus_we(wb_we),
		.clk(clk_48m),
		.rst(rst)
	);

	// Peripheral [2] : USB Core control
	usb #(
		.TARGET("ECP5"),
		.EPDW(32)
	) usb_I (
		.pad_dp(usb_fpga_bd_dp),
		.pad_dn(usb_fpga_bd_dn),
		.pad_pu(usb_fpga_pu_dp),
		.ep_tx_addr_0(ep_tx_addr_0),
		.ep_tx_data_0(ep_tx_data_0),
		.ep_tx_we_0(ep_tx_we_0),
		.ep_rx_addr_0(ep_rx_addr_0),
		.ep_rx_data_1(ep_rx_data_1),
		.ep_rx_re_0(ep_rx_re_0),
		.ep_clk(clk_48m),
		.bus_addr(wb_addr[11:0]),
		.bus_din(wb_wdata[15:0]),
		.bus_dout(wb_rdata[2][15:0]),
		.bus_cyc(wb_cyc[2]),
		.bus_we(wb_we),
		.bus_ack(wb_ack[2]),
		.clk(clk_48m),
		.rst(rst)
	);

	assign wb_rdata[2][31:16] = 16'h0000;

	// Peripheral [3] : USB Core buffers
	reg wb_ack_ep;

	always @(posedge clk_48m)
		wb_ack_ep <= wb_cyc[3] & ~wb_ack_ep;

	assign wb_ack[3] = wb_ack_ep;

	assign ep_tx_addr_0 = wb_addr[8:0];
	assign ep_tx_data_0 = wb_wdata;
	assign ep_tx_we_0   = wb_cyc[3] & ~wb_ack[3] & wb_we;

	assign ep_rx_addr_0 = wb_addr[8:0];
	assign ep_rx_re_0   = 1'b1;

	assign wb_rdata[3] = wb_cyc[3] ? ep_rx_data_1 : 32'h00000000;

	// Peripheral [4] : SPI core
	wire [3:0] spi_io_i_flash;
	reg  [3:0] spi_io_i;
	wire [3:0] spi_io_o;
	wire [3:0] spi_io_t;
	wire       spi_sck_o;
	wire [2:0] spi_cs_o;

	qspi_master_wb #(
		.N_CS(3)
	) spi_master_I (
		.spi_io_i(spi_io_i),
		.spi_io_o(spi_io_o),
		.spi_io_t(spi_io_t),
		.spi_sck_o(spi_sck_o),
		.spi_cs_o(spi_cs_o),
		.bus_addr(wb_addr[1:0]),
		.bus_wdata(wb_wdata),
		.bus_rdata(wb_rdata[4]),
		.bus_cyc(wb_cyc[4]),
		.bus_we(wb_we),
		.bus_ack(wb_ack[4]),
		.clk(clk_48m),
		.rst(rst)
	);

	// PHY to Flash
	qspi_phy_ecp5 #(
		.N_CS(1),
		.IS_SYS_CFG(1)
	) spi_phy_flash_I (
		.spi_io({flash_holdn, flash_wpn, flash_miso, flash_mosi}),
		.spi_cs(flash_csn),
		.spi_sck(),		// Special via USRMCLK
		.spi_io_i(spi_io_i_flash),
		.spi_io_o(spi_io_o),
		.spi_io_t(spi_cs_o[0] ? 4'hf : spi_io_t),
		.spi_sck_o(spi_cs_o[0] ? 1'b0 : spi_sck_o),
		.spi_cs_o(spi_cs_o[0]),
		.clk(clk_48m),
		.rst(rst)
	);

	// MUX for read data
	always @(*)
	begin
		spi_io_i <= 4'h0;

		if (~spi_cs_o[0])
			spi_io_i <= spi_io_i_flash;
	end


	// Clock / Reset
	// -------------

	sysmgr sysmgr_I (
		.clk_in(clk_25mhz),
		.rst_in(1'b0),
		.clk_48m(clk_48m),
		.rst_out(rst),
		.locked(locked)
	);

endmodule // top
