System Architecture
===================

Hazard3-Doom is a hardware/software stack rather than a single firmware binary.
The processor at its center is standard parameterized Hazard3 RTL; the Doom
project adds the board-level memory, video, storage, SAO, and boot integration
around that processor.

For a detailed CPU walkthrough, including the F/X/M pipeline, selected ISA
extensions, CSRs, interrupts, bus interface, and RISC-V debug path, see
:doc:`hazard3/index`.

Major components
----------------

.. list-table::
   :header-rows: 1
   :widths: 25 75

   * - Component
     - Role
   * - Hazard3 CPU
     - Three-stage RV32 RISC-V processor. This project selects M, C, Zba, Zbb, Zbs, Zifencei, counters, debug support, fast multiply options, fast branch compare, and the small branch predictor; A is disabled.
   * - Hazard3 Debug Module/DTM
     - Upstream RISC-V debug infrastructure connected to the ECP5 chip JTAG TAP and used by OpenOCD/GDB.
   * - Resident monitor
     - Startup, diagnostics, UART loading, SD boot, and recovery firmware in internal EBR SRAM.
   * - External SDRAM
     - Project SoC memory subsystem storing the linked Doom image, heap/zone memory, IWAD, and video staging areas.
   * - HDMI engine
     - Project display logic presenting the indexed Doom framebuffer.
   * - micro-SD interface
     - Project APB/SPI hardware used for standalone executable/IWAD loading after power-up.
   * - SAO APB bridge
     - Project memory-mapped access to SAO I2C/GPIO and shared-resource control.
   * - ESP32
     - Optional companion processor sharing selected board resources through explicit ownership rules.
   * - OpenOCD/GDB
     - Host-side source-level debug path through Hazard3's standard external-debug architecture.

CPU versus SoC boundary
-----------------------

A useful way to reason about the design is to keep the processor and platform
layers separate:

.. code-block:: text

   +-------------------------------------------+
   | Hazard3 CPU/debug                         |
   | RISC-V ISA, F/X/M pipeline, CSRs, traps   |
   +-------------------------------------------+
                       |
                       | AHB5
                       v
   +-------------------------------------------+
   | Example SoC and project integration       |
   | SRAM, APB, timer, UART, SDRAM, SD, SAO    |
   +-------------------------------------------+
                       |
                       v
   +-------------------------------------------+
   | ULX3S/ULX4M board hardware                |
   | ECP5, SDRAM, HDMI, micro-SD, ESP32, pins  |
   +-------------------------------------------+

The processor executes ordinary RISC-V loads and stores. The SoC address
decoder determines whether those accesses reach internal SRAM, an APB
peripheral, external SDRAM, or another mapped target. Likewise, Doom video and
SD-card behavior are platform features, not special CPU instructions.

Boot paths
----------

Development boot
~~~~~~~~~~~~~~~~

FPGA load -> resident monitor -> UART ``.h3d`` upload -> UART ``DOOM.WAD`` upload -> launch.

Standalone boot
~~~~~~~~~~~~~~~

SPI flash FPGA configuration -> preloaded EBR resident monitor -> SDRAM init -> micro-SD ``DOOM.H3D`` + ``DOOM.WAD`` -> launch.

The resident-monitor SRAM preload is a customization in the ULX3S Hazard3 fork.
It lets the system start useful firmware immediately after FPGA configuration
without requiring a debugger download first.

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

These peripherals are additions around the Hazard3 processor. Keep software
register definitions synchronized with the matching Hazard3 hardware submodule
commit.
