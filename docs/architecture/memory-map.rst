Memory Map
==========

The addresses on this page belong to the Hazard3-Doom **SoC integration**, not
to the RISC-V ISA or a fixed Hazard3 processor memory map. Hazard3 issues normal
instruction/data transactions; the surrounding SoC decodes these physical
address windows. See :doc:`hazard3/memory-and-bus` for the CPU/bus boundary.

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

For ULX4M-LD, this is a **software-visible 64 MiB profile**, not the physical
DDR3 chip capacity. The currently qualified Micron ``MT41K512M16HA`` population
is an 8 Gbit/x16 device (1 GiB), and the project also supports the smaller
Alliance ``AS4C256M16D3`` population through a separate generated LiteDRAM
profile. Hazard3-Doom deliberately uses only the 64 MiB range above, so the
software memory map remains stable across those board populations.

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
