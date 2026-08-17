System Architecture
===================

Hazard3-Doom is a hardware/software stack rather than a single firmware binary.

Major components
----------------

.. list-table::
   :header-rows: 1
   :widths: 25 75

   * - Component
     - Role
   * - Hazard3 CPU
     - RISC-V processor and debug module implemented in the ECP5 FPGA.
   * - Resident monitor
     - Startup, diagnostics, UART loading, SD boot, and recovery firmware in internal EBR SRAM.
   * - External SDRAM
     - Stores the linked Doom image, heap/zone memory, IWAD, and video staging areas.
   * - HDMI engine
     - Presents the indexed Doom framebuffer through FPGA video logic.
   * - micro-SD interface
     - Provides standalone executable/IWAD loading after power-up.
   * - SAO APB bridge
     - Gives Hazard3 software access to SAO I2C/GPIO functions.
   * - ESP32
     - Optional companion processor sharing selected board resources through explicit ownership rules.
   * - OpenOCD/GDB
     - Host-side source-level debug path through JTAG.

Boot paths
----------

Development boot
~~~~~~~~~~~~~~~~

FPGA load -> resident monitor -> UART ``.h3d`` upload -> UART ``DOOM.WAD`` upload -> launch.

Standalone boot
~~~~~~~~~~~~~~~

SPI flash FPGA configuration -> EBR resident monitor -> SDRAM init -> micro-SD ``DOOM.H3D`` + ``DOOM.WAD`` -> launch.

APB peripherals
---------------

Important project-local APB regions include:

.. list-table::
   :header-rows: 1

   * - Base
     - Function
   * - ``0x40009000``
     - SAO bridge.
   * - ``0x4000A000``
     - SD SPI interface.
   * - ``0x4000C000``
     - HDMI/video control registers.

Keep software register definitions synchronized with the matching Hazard3 hardware submodule commit.
