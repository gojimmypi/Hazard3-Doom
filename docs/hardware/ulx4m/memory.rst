External Memory: SDRAM and DDR3
================================

External memory is the largest architectural difference between ULX4M-LS and
ULX4M-LD in Hazard3-Doom. The processor still executes ordinary RISC-V loads
and stores, but the logic between the AHB bus and the physical memory is very
different.

For the processor-side view of these controllers, also see
:doc:`../../architecture/hazard3/memory-and-bus`.

ULX4M-LS: native SDR SDRAM
--------------------------

The current Hazard3-Doom LS wrapper describes a 32 MiB, 16-bit SDR SDRAM
interface and uses the same native controller family as the ULX3S target:

.. code-block:: text

   Hazard3/AHB
       |
       v
   ahb_sdram.v
       |
       v
   ulx3s_sdram_controller.v
       |
       v
   16-bit SDR SDRAM

The wrapper configures a 50 MHz system clock and a 9-bit SDRAM column geometry
for this board profile. The controller handles activate/precharge, CAS timing,
refresh, byte masks, and arbitration with video requests.

ULX4M-LD: LiteDRAM DDR3
-----------------------

The LD path uses LiteDRAM because DDR3 requires substantially more PHY and
initialization machinery. The project-facing path is:

.. code-block:: text

   Hazard3 @ 40 MHz
         |
       AHB5
         |
   ahb_litedram.v
         |
   request/response CDC
         |
   128-bit Wishbone @ 60 MHz
         |
   generated LiteDRAM core
         |
      ECP5DDRPHY
         |
      x16 DDR3

The generated LiteDRAM core owns memory geometry, initialization, command
scheduling, refresh, and the ECP5 DDR PHY. ``ahb_litedram.v`` intentionally
keeps the same processor-side interface when the physical DDR3 part changes.

Supported DDR3 profile families
-------------------------------

Current checked-in generation sources support two part-number selections:

.. list-table::
   :header-rows: 1
   :widths: 27 19 19 35

   * - Project selection
     - Density/class
     - Capacity class
     - LiteDRAM module class
   * - ``MT41K512M16HA``
     - 8 Gbit x16
     - 1 GiB
     - ``MT41K512M16``
   * - ``AS4C256M16D3``
     - 4 Gbit x16
     - 512 MiB
     - ``AS4C256M16D3A``

.. _fig-alliance-ddr3-variants:

.. figure:: ../../images/as4c256m16d3-flavors.png
   :alt: Alliance Memory AS4C256M16D3 ordering-code variants

   **Alliance AS4C256M16D3 family variants** - ordering-code details matter
   when identifying the fitted DDR3 device; record the complete package marking
   rather than only the base family name.

The physical memory can be much larger than the memory map exposed to
Hazard3-Doom. The current Doom software profile intentionally uses a 64 MiB
external-memory window; unused physical capacity does not need to be mapped for
the game to run.

Current generated profile
-------------------------

The checked-in SERV and VexRisc generated metadata in this release are for the
Micron ``MT41K512M16HA`` family. Both record:

.. code-block:: text

   FPGA: LFE5UM-85F-8BG381C
   LiteDRAM: 2024.12
   LiteX: 2024.12
   input/init clock: 25 MHz
   Hazard3 system clock: 40 MHz
   LiteDRAM user clock: 60 MHz
   DDR clock: 120 MHz
   user port: 128-bit Wishbone
   command buffer depth: 2
   command buffer buffered: true
   auto precharge: true

The generated core can use SERV or minimal VexRiscv as its LiteX initialization
CPU. That CPU is part of the DDR initialization environment; it is not the
Hazard3 processor that later runs Doom.

Regenerating for the fitted RAM
-------------------------------

Do not hand-edit the generated LiteDRAM Verilog to change DDR3 chips. The
checked-in YAML files are the editable sources. Select the part number and let
the project regenerate both supported initialization-CPU variants:

.. code-block:: bash

   cd third_party/Hazard3/example_soc/third_party/LiteDRAM
   ./regenerate-ulx4m.sh MT41K512M16HA

or:

.. code-block:: bash

   ./regenerate-ulx4m.sh AS4C256M16D3

The generator validates pinned LiteDRAM/LiteX/Migen and CPU-package versions,
builds the cores, embeds the required CPU RTL, records provenance, and writes
``generated-serv/`` and ``generated-vexrisc/``.

.. important::

   A generated core must match the DDR3 part fitted to the board. Do not assume
   the device named by a campaign page, an old schematic, or another user's
   board is the device on your board.

Geometry and identification
---------------------------

For x16 DDR3, address geometry provides a useful software-visible clue. The two
currently supported families differ in row count/capacity class. Hazard3-Doom
can use destructive memory probing during diagnostics to distinguish a
512-MiB-class alias pattern from a 1-GiB-class pattern, but this should be
understood as a geometry/probability check rather than an electronic JEDEC part
number reader.

When documenting a board, record all of the following when possible:

* package marking on the fitted memory;
* full manufacturer part number if known;
* PCB revision;
* schematic/assembly source used for comparison;
* generated LiteDRAM profile name; and
* hardware qualification result.

DDR3 qualification
------------------

Timing closure alone is not sufficient. The release-qualified Micron path has
been exercised with destructive sequential patterns, sparse alias/address
checks, pseudorandom tests in separated memory regions, the monitor's full
qualification suite, heap stress, Doom platform smoke testing, and execution of
copied RV32 code from DDR.

That sequence is intentionally stronger than "LiteDRAM calibrated." Calibration
proves the PHY completed initialization; it does not prove every relevant
address line, data lane, cache interaction, or long-running software access is
correct.

Electrical interface
--------------------

The LD top level exposes a conventional x16 DDR3 interface: address, three bank
bits, RAS/CAS/WE, CKE, CS, ODT, reset, two data-mask lanes, sixteen bidirectional
DQ bits, two DQS byte lanes, and a differential clock. The LPF assigns those
signals to ECP5 package pins and applies DDR3-appropriate SSTL/differential I/O
constraints.

Those constraints are part of the memory controller. A correct LiteDRAM YAML
with an incorrect LPF is not a valid DDR3 design.


External References
-------------------

* `LiteDRAM <https://github.com/enjoy-digital/litedram>`_ - configurable DRAM
  controller/PHY generator used by the ULX4M-LD path.
* `Alliance Memory AS4C256M16D3 product page <https://www.alliancememory.com/as4c256m16d3/>`_ -
  current manufacturer part-family and datasheet links.
* `Lattice ECP5 / ECP5-5G resources <https://www.latticesemi.com/ecp5>`_ - FPGA
  family data sheets and DDR-related device documentation.
* :doc:`sources` - ULX4M schematics, board repositories, and project source hierarchy.
