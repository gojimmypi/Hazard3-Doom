SAO / I2C Support
=================

Hazard3-Doom exposes a Hackaday-style SAO connector through an APB-controlled I2C/GPIO bridge. The same physical SAO bus can also be shared with the onboard ESP32 through an ownership sideband protocol.

Connector signals
-----------------

The Supercon SAO cannot be plugged directly into the ULX3S because the 3.3V and ground pins are perpendicular
to the other pins on the ULX3S header.

The documented ULX3S SAO signals are:

.. list-table::
   :header-rows: 1

   * - Signal
     - FPGA pin
     - Header GP/GN
     - J1 Row
     - Header Pin
   * - Power
     - 3.3V
     - 3.3V
     - 1
     - 1
   * - Ground
     - GND
     - GND
     - 2
     - 3
   * - SDA
     - A9
     - GP2
     - 2
     - 10
   * - SCL
     - B10
     - GN2
     - 2
     - 11
   * - GPIO1
     - B9
     - GP3
     - 3
     - 12
   * - GPIO2
     - C10
     - GN3
     - 3
     - 11

.. image:: ../images/ulx3s-pinout.png
   :alt: ULX3S pinout

Hazard3 APB base
----------------

The SAO bridge is mapped at:

.. code-block:: text

   0x40009000

Monitor commands
----------------

The resident monitor provides commands including:

.. code-block:: text

   sao info
   sao gui
   sao recover
   sao scan
   sao probe
   sao read
   sao write
   i2c scan
   i2c gui

HDMI I2CDriver interface
------------------------

The resident monitor also provides an interactive I2CDriver-style HDMI tool:

.. code-block:: text

   i2c gui

The GUI provides scanning, probing, register reads/writes, bus recovery,
100/400-kHz selection, an address heatmap, transaction history, and a logical
SDA/SCL trace. See :doc:`i2cdriver` for controls, safety notes, and the
important distinction between an initiated logical trace and true passive bus
capture.

ESP32 sharing
-------------

The FPGA and ESP32 use the ULX3S Wi-Fi GPIO16/GPIO17 sideband connection to coordinate logical ownership of the SAO bus. The example ESP32 firmware lives under:

.. code-block:: text

   examples/esp32-sao-shared/

The owner that does not hold the bus must release its outputs rather than merely deciding not to transmit.

Electrical note
---------------

I2C pull-ups establish the idle high level but do not replace any series protection required by a particular SAO design. Review the electrical requirements of the add-on before attaching hardware that actively drives the optional GPIO lines.
