External Memory: SDR SDRAM
==========================

ULX3S provides external 16-bit synchronous SDR SDRAM. This is the main working
memory used by Hazard3-Doom for the loaded application, heap, IWAD data, and
other large runtime objects that do not fit in ECP5 block RAM.

For the processor-side architecture, also see
:doc:`../../architecture/hazard3/memory-and-bus`.

Controller path
---------------

The project memory path is intentionally simple enough to study:

.. code-block:: text

   Hazard3 load/store
          |
          v
      AHB5 fabric
          |
          v
      ahb_sdram.v
          |
          v
   ulx3s_sdram_controller.v
          |
          v
   16-bit SDR SDRAM

The controller owns SDRAM activate/precharge sequencing, CAS timing, refresh,
byte masks, and the physical command/data interface. The AHB-side adapter also
coordinates processor and video access to the external memory path where the
selected video implementation requires it.

Memory profiles are software-visible maps
-----------------------------------------

Hazard3-Doom uses named memory profiles so the monitor, Doom image, linker
layout, and FPGA design agree about the external-memory window.

The current complete builds use:

``ULX3S 85F``
   ``64m`` at a 50 MHz Hazard3 system clock.

``ULX3S 12F``
   ``32m`` by default at 40 MHz. The wrapper can select ``64m`` when the board
   and complete software/hardware configuration are appropriate for that map.

A software profile is not a substitute for checking the fitted SDRAM. Upstream
ULX3S material documents multiple SDRAM capacity populations across the board
family. When the exact board population matters, use the device marking,
matching schematic/BOM revision, and a memory/alias test rather than the board
name alone.

SDRAM is not ECP5 EBR
---------------------

Two different memories are present in the system:

``ECP5 EBR``
   Internal FPGA block RAM. The resident boot monitor can be preloaded here as
   part of the FPGA bitstream and is available immediately after configuration.

``External SDR SDRAM``
   A separate board-level DRAM device. It must be initialized and refreshed by
   the SDRAM controller and provides the capacity required by Doom.

This distinction explains the cold-boot sequence: the resident monitor can run
from internal EBR first, initialize SDRAM, then load the larger Doom image and
IWAD into external memory.

Qualification
-------------

Do not treat successful FPGA configuration as proof that SDRAM is healthy. A
useful board qualification should exercise multiple address/data patterns,
byte/halfword/word accesses, address aliasing, heap use, and real application
traffic.

The monitor's SDRAM tests and Doom smoke tests are therefore part of hardware
bring-up, not merely software diagnostics.
