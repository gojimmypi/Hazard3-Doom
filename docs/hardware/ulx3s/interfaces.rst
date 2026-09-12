USB, JTAG, UART, GPIO, and ESP32 Interfaces
===========================================

``US1`` FT231X path
-------------------

The main ULX3S ``US1`` connector reaches the FT231X USB interface used for the
board's normal host communication and JTAG-oriented programming workflows.
Hazard3-Doom uses this path for:

* FPGA programming with ``fujprog``/compatible host tools;
* the browser WebUSB FPGA flasher;
* OpenOCD JTAG access with the appropriate FT231X/``ft232r`` support; and
* board/ESP32 serial workflows when the FT231X serial interface is bound normally.

The current project-tested Hazard3 monitor UART is the separate J1 ``GP0``/``GP1``
wiring described below; do not assume that opening the ``US1`` FT231X serial port
is the same signal path.

Windows driver choice matters because WebUSB and the normal serial/JTAG host
stacks do not all use the same driver binding. See :doc:`../../troubleshooting`
and :doc:`../../user-guide/web-flasher` before changing an FTDI driver.

External JTAG header
--------------------

ULX3S also provides a six-pin JTAG header with TCK, TDI, TDO, TMS, 3.3 V, and
GND. An external programmer can therefore be used independently of the onboard
FT231X path.

When attaching an external JTAG adapter, verify signal order and voltage before
connecting it. Do not assume that a generic cable's physical pin numbering
matches the ULX3S header merely because the signal names are standard.

UART used by Hazard3-Doom
-------------------------

UART is the simplest software-facing monitor path. The tested Hazard3-Doom
external UART wiring uses the ULX3S J1 header as follows:

.. list-table::
   :header-rows: 1
   :widths: 24 30 46

   * - Function at FPGA
     - ULX3S header location
     - External adapter connection
   * - ``RxD``
     - J1 pin 8 / ``GP1``
     - Connect to adapter TX.
   * - ``TxD``
     - J1 pin 6 / ``GP0``
     - Connect to adapter RX.
   * - Ground
     - Adjacent J1 ground
     - Connect to adapter ground.

This is project-tested lab wiring, not a replacement for checking the active
LPF/top-level design. Always verify the build if UART pins are changed.

J1/J2 GPIO
----------

The two 40-pin headers expose 56 FPGA GPIO signals named as ``GP``/``GN`` pairs
in upstream material. Some are ordinary single-ended signals, some correspond
to true differential-capable FPGA pairs, and some are shared with ESP32 or ADC
functions depending on PCB revision.

The upstream manual also notes an important mechanical detail: physical odd/even
pin interpretation differs between angled female and vertical male header
arrangements. Use the schematic and constraint comments rather than inferring
pin numbers from a photograph.

ESP32 sharing
-------------

ULX3S can include an ESP32 that provides Wi-Fi/Bluetooth and can participate in
FPGA programming or board-side services. Several FPGA-facing resources are
shared, including micro-SD and selected GPIO/JTAG-related signals on documented
PCB revisions.

Hazard3-Doom therefore treats shared interfaces as ownership problems. The side
that does not own a bus must release it electrically. This is particularly
important for SD and for any experiment involving the ESP32 and FPGA JTAG paths
at the same time.

Other board interfaces
----------------------

Buttons, LEDs, ADC, RTC, audio, OLED/LCD, and clock-capable GPIO are available
for experimentation. They are valuable teaching resources even when the current
Hazard3-Doom SoC does not expose a dedicated software driver for every device.
