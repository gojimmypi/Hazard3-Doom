.. NOTE: English fallback - French translation pending.

ULX3S Schematic Reference
=========================

This page describes selected ULX3S circuits and their connections to
Hazard3-Doom. Use the schematic for the installed board revision when
checking component values and FPGA package pins. See :doc:`sources` for
schematic sources and :doc:`pinout-and-revisions` for pin assignments.

.. contents::
   :local:
   :depth: 1

Pushbuttons and reset
---------------------

The board provides user buttons and a power-control button. ``PWRBtn``
and ``BTN_PWRn`` identify the power-button circuit; ``BTN_PWRn`` is an
active-low signal.

The FPGA can use a button as a reset input only when the pin is assigned
in ``fpga_ulx3s.lpf`` and connected to reset logic in ``fpga_ulx3s.v``.
A SoC reset restarts the processor and the logic connected to that reset.
It does not reload the FPGA bitstream or switch off board power.

Relevant source files:

* ``third_party/Hazard3/example_soc/synth/fpga_ulx3s.lpf``
* ``third_party/Hazard3/example_soc/fpga/fpga_ulx3s.v``
* ``third_party/Hazard3/example_soc/soc/example_soc.v``

.. .. image:: ../../images/ulx3s-schematic-buttons-reset.png
..    :alt: ULX3S button and reset circuit
..    :width: 100%

GPIO expansion headers
----------------------

J1 and J2 expose FPGA I/O signals labeled ``GP`` and ``GN``. A header
pin number, schematic net name, FPGA package pin, and RTL signal name
are separate identifiers.

The Hazard3-Doom monitor UART uses these J1 connections:

.. list-table:: J1 monitor UART
   :header-rows: 1
   :widths: 20 30 35

   * - UART
     - J1
     - USB-UART adapter
   * - Transmit (``TxD``)
     - Pin 6, ``GP0``
     - RX
   * - Receive (``RxD``)
     - Pin 8, ``GP1``
     - TX
   * - Ground
     - GND
     - GND

For other GPIO signals, ``fpga_ulx3s.lpf`` assigns FPGA pins and
``fpga_ulx3s.v`` connects the pads to the SoC. ``GPIO_IN_WIDTH`` in
``example_soc.v`` specifies an internal input-bus width. It does not
specify the number of pins on J1 or J2.

See :doc:`interfaces` for connector details.

.. .. image:: ../../images/ulx3s-schematic-gpio-headers.png
..    :alt: ULX3S J1 and J2 GPIO header connections
..    :width: 100%

LEDs and switches
-----------------

The board has eight user LEDs and input switches. The LPF assigns the
FPGA pins; the top-level RTL defines their functions. The LED output
width and GPIO input width are independent.

.. .. image:: ../../images/ulx3s-schematic-leds-switches.png
..    :alt: ULX3S LEDs and switches
..    :width: 100%

Clock and FPGA configuration
----------------------------

The ULX3S oscillator provides a 25 MHz reference clock. The FPGA derives
other clocks for the SoC, memory, and video interfaces. Clock settings
are defined in the FPGA build, not by changing the oscillator.

The ECP5 can be configured through JTAG or from SPI flash. SoC reset
does not replace FPGA configuration. See :doc:`fpga-and-clocking` and
:doc:`boot-and-flash`.

.. .. image:: ../../images/ulx3s-schematic-clock-config.png
..    :alt: ULX3S oscillator and configuration connections
..    :width: 100%

SDR SDRAM
---------

External SDR SDRAM provides application and data memory. The memory
interface has a 16-bit data bus, address and bank signals, and SDRAM
control signals. The memory controller performs initialization and
refresh.

Hazard3-Doom connects the SoC to the SDRAM controller through
``ahb_sdram.v``. The monitor initializes SDRAM before loading an
application into it. See :doc:`memory`.

.. .. image:: ../../images/ulx3s-schematic-sdram.png
..    :alt: ULX3S SDR SDRAM connections
..    :width: 100%

USB, UART, and JTAG
-------------------

The on-board USB interface provides FPGA programming and debug access.
The board also has a six-pin JTAG header for an external adapter.

The Hazard3-Doom monitor UART uses J1 ``GP0`` and ``GP1``, as listed
above. The monitor UART is not the USB programming connection. See
:doc:`interfaces`.

.. .. image:: ../../images/ulx3s-schematic-usb-jtag.png
..    :alt: ULX3S USB interface and JTAG header
..    :width: 100%

micro-SD and ESP32
------------------

The micro-SD socket can hold ``DOOM.IMG`` and ``DOOM.WAD`` for loading
by the monitor. These files are separate from the FPGA configuration
stored in SPI flash.

The FPGA and ESP32 share SD interface signals. When the FPGA accesses
the card, ESP32 GPIO14, GPIO15, GPIO2, and GPIO13 must be configured as
high-impedance inputs to avoid bus contention. See
:doc:`video-and-storage` and :doc:`../../user-guide/sd-card`.

.. .. image:: ../../images/ulx3s-schematic-sd-esp32.png
..    :alt: ULX3S micro-SD and ESP32 connections
..    :width: 100%

GPDI video
----------

The GPDI connector carries HDMI-compatible video signals driven by the
FPGA. Hazard3-Doom converts framebuffer pixels into the output video
stream in FPGA logic.

The web interface's Screen Snip feature transfers framebuffer data over
UART; it does not capture the GPDI output. See :doc:`video-and-storage`
and :doc:`../../architecture/video`.

.. .. image:: ../../images/ulx3s-schematic-gpdi.png
..    :alt: ULX3S GPDI video connections
..    :width: 100%

Other peripherals
-----------------

The schematic also includes audio, display, and board-support circuits.
Availability to software depends on the FPGA build and its peripheral
logic. Consult the LPF and top-level RTL for implemented connections.

.. .. image:: ../../images/ulx3s-schematic-peripherals.png
..    :alt: ULX3S auxiliary peripheral connections
..    :width: 100%
