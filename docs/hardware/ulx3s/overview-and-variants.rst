Overview and Board Variants
===========================

What ULX3S is
-------------

ULX3S is a standalone ECP5 FPGA development board created as an open-hardware
platform for digital-logic education, research, and embedded FPGA projects. The
upstream design combines a Lattice ECP5 with SDR SDRAM and enough board-level
I/O that useful systems can run without a large carrier board.

Representative ULX3S resources include:

* Lattice ECP5 FPGA in the 381-ball package;
* external 16-bit SDR SDRAM;
* SPI configuration flash;
* two micro-USB connectors with different roles;
* FT231X USB serial/JTAG support on ``US1``;
* GPDI digital video;
* micro-SD storage;
* two 40-pin GPIO headers;
* optional/on-board ESP32 Wi-Fi/Bluetooth support;
* buttons and LEDs;
* audio and optional OLED/LCD connections;
* ADC and RTC circuitry; and
* a 25 MHz board oscillator plus external clock-capable pins.

Hazard3-Doom does not use every ULX3S peripheral. The project concentrates on
the Hazard3 CPU, external SDRAM, GPDI video, monitor/UART/JTAG diagnostics,
FPGA programming, micro-SD boot, and selected FPGA/ESP32 shared interfaces.

FPGA density is not the board revision
--------------------------------------

ULX3S has been assembled with multiple ECP5 densities. The upstream design
supports 12F, 25F, 45F, and 85F device populations in the same broad board
family. PCB revisions evolved independently.

For Hazard3-Doom the currently documented complete targets are:

.. list-table::
   :header-rows: 1
   :widths: 20 22 24 16 18

   * - Target
     - Software memory profile
     - External memory path
     - Hazard3 clock
     - Project note
   * - ULX3S 85F
     - ``64m``
     - 16-bit SDR SDRAM through the native project controller
     - 50 MHz
     - Primary full-size ULX3S build path.
   * - ULX3S 12F
     - ``32m`` default; ``64m`` optional when appropriate for the board
     - 16-bit SDR SDRAM through the native project controller
     - 40 MHz
     - Compact target with the 320x200 video path.

The existence of a 25F or 45F board does not automatically make it a supported
Hazard3-Doom target. A complete target also needs a qualified synthesis route,
matching memory/video configuration, constraints, and hardware testing.

PCB revisions matter
--------------------

The upstream ULX3S repository contains schematic and constraint material for
multiple PCB generations. Some details changed over time, including ESP32-shared
GPIOs, USB/power behavior, and other board-level routing.

When debugging hardware, record at least:

``PCB revision``
   The revision printed on the physical board or established from manufacturing
   information.

``FPGA density``
   12F, 25F, 45F, or 85F, including the full device/package marking when useful.

``SDRAM population``
   Device marking/capacity where it affects the selected Hazard3-Doom memory
   profile.

``Constraint source``
   The LPF revision used by the actual build.

A schematic for one PCB revision can still be educational for another revision,
but it should not silently be treated as the exact pinout of every ULX3S board.
