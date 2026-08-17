SAO / I2C Support
=================

Hazard3-Doom exposes a Hackaday-style SAO connector through an APB-controlled I2C/GPIO bridge. The same physical SAO bus can also be shared with the onboard ESP32 through an ownership sideband protocol.

Connector signals
-----------------

The documented ULX3S SAO signals are:

.. list-table::
   :header-rows: 1

   * - Signal
     - ULX3S pin
   * - SDA
     - A9
   * - SCL
     - B10
   * - GPIO1
     - B9
   * - GPIO2
     - C10

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
   sao recover
   sao scan
   sao probe
   sao read
   sao write
   i2c scan

ESP32 sharing
-------------

The FPGA and ESP32 use the ULX3S Wi-Fi GPIO16/GPIO17 sideband connection to coordinate logical ownership of the SAO bus. The example ESP32 firmware lives under:

.. code-block:: text

   examples/esp32-sao-shared/

The owner that does not hold the bus must release its outputs rather than merely deciding not to transmit.

Electrical note
---------------

I2C pull-ups establish the idle high level but do not replace any series protection required by a particular SAO design. Review the electrical requirements of the add-on before attaching hardware that actively drives the optional GPIO lines.
