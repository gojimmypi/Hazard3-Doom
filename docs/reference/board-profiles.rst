Board Profiles
==============

.. list-table::
   :header-rows: 1
   :widths: 35 25 40

   * - Board
     - Memory profile
     - System clock
   * - ULX3S 85F
     - ``64m``
     - 50 MHz
   * - ULX4M-LD 85F
     - ``64m``
     - 50 MHz
   * - ULX4M-LS 85F
     - ``32m``
     - 50 MHz documented profile

The monitor, linked Doom image, and WAD uploader must all agree on the memory profile.

Primary ULX3S peripheral bases
------------------------------

.. list-table::
   :header-rows: 1

   * - Peripheral
     - Base
   * - SAO bridge
     - ``0x40009000``
   * - SD SPI
     - ``0x4000A000``
   * - HDMI/video
     - ``0x4000C000``
