Memory Map
==========

Internal SRAM
-------------

The 128 KiB ECP5 EBR SRAM is divided as follows:

.. list-table::
   :header-rows: 1

   * - Range
     - Use
   * - ``0x00000000-0x0000FFFF``
     - Resident monitor, traps, and monitor/Doom stack.
   * - ``0x00010000-0x0001F9FF``
     - Doom 320x200 indexed working screen.
   * - ``0x0001FA00-0x0001FFFF``
     - Unused internal SRAM.

64 MiB SDRAM profile
--------------------

Used by ULX3S 85F and ULX4M-LD 85F:

.. list-table::
   :header-rows: 1

   * - Range
     - Use
   * - ``0x20000000-0x23FFFFFF``
     - Physical 64 MiB external memory.
   * - ``0x24000000-0x27FFFFFF``
     - Uncached diagnostic alias.
   * - ``0x20100000-0x203FFFFF``
     - Cached linked Doom image.
   * - ``0x20400000-0x22BFFFFF``
     - Cached Doom heap and zone memory.
   * - ``0x22C00000-0x23BFFFFF``
     - Cached IWAD reservation, 16 MiB.
   * - ``0x23C00000-0x23FFFFFF``
     - Uncached video reservation.

32 MiB SDRAM profile
--------------------

Used by ULX4M-LS 85F:

.. list-table::
   :header-rows: 1

   * - Range
     - Use
   * - ``0x20000000-0x21FFFFFF``
     - Physical 32 MiB SDRAM.
   * - ``0x24000000-0x25FFFFFF``
     - Uncached diagnostic alias.
   * - ``0x20100000-0x203FFFFF``
     - Cached linked Doom image.
   * - ``0x20400000-0x20FFFFFF``
     - Cached Doom heap, 12 MiB.
   * - ``0x21000000-0x21BFFFFF``
     - Cached IWAD reservation, 12 MiB.
   * - ``0x21C00000-0x21FFFFFF``
     - Uncached video reservation.
