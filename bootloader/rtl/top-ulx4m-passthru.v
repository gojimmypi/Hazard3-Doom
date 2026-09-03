
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
(
	// Clock
	input  wire clk_25mhz,

	// LEDs
	output wire [3:0] led,

	// Buttons
	input  wire [6:0] btn,
	
	// Debug or esp32 passthru UART
	input  wire ftdi_txd,
	output wire ftdi_rxd,

	// ESP32 passthru
	input  wire wifi_txd,
	output wire wifi_rxd,
        input  wire wifi_gpio15, wifi_gpio14,
        inout  wire wifi_gpio13, wifi_gpio12,
        inout  wire wifi_gpio4 , wifi_gpio2 , wifi_gpio0 ,
        inout  wire wifi_en,
        //output wire sd_wp, // BGA pin exists but not connected on PCB

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

	// Boot
	inout  wire user_programn
);

	wire [7:0] led8; // only lower 4 LEDs
	//assign led = led8[3:0];
	assign led = {wifi_gpio15, wifi_gpio14, wifi_gpio13, wifi_gpio12}; // debug SD card
	wire ftdi_ndtr = 1'b1, ftdi_nrts = 1'b1, sd_wp; // not used
	// ESP32 passthru FPGA
	esp32_passthru
	#(
		.C_powerup_en_time(0) // 0: normal, 10: v3.1.6 workaround but then uftpd will have problems
	)
	esp32_passthru_I
	(
		.clk_25mhz(clk_25mhz),
		.btn(btn),
		.led(led8),
		.ftdi_txd(ftdi_txd),
		.ftdi_rxd(ftdi_rxd),
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
		//.wifi_en(wifi_en),
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
		//.user_programn(user_programn),
		.nc(sd_wp) // BGA pin exists but not connected on PCB
	);

	// ecp5wp.py needs this
	// for some boards with IS25LP128	
	assign flash_csn   = 1;
	assign flash_holdn = 1;

endmodule // top
