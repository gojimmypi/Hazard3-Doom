Board Profiles
==============

.. list-table::
   :header-rows: 1
   :widths: 30 25 20 25

   * - Board
     - Memory profile
     - System clock
     - Video/build note
   * - ULX3S 85F
     - ``64m``
     - 50 MHz
     - 320x200 default; extended modes available
   * - ULX3S 12F
     - ``32m`` default; ``64m`` optional
     - 40 MHz
     - Compact 320x200 SDRAM scanout
   * - ULX4M-LD 85F
     - ``64m``
     - 50 MHz
     - LiteDRAM target
   * - ULX4M-LS 85F
     - ``32m``
     - 50 MHz documented profile
     - Memory-profile reference

The monitor, linked Doom image, and SDRAM memory map must agree on the memory
profile. Complete board build wrappers set their target-specific profile and
clock automatically.

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
