Memory and Bus Interface
========================

Hazard3 separates the processor pipeline from the system memory map. That
separation is especially important in Hazard3-Doom because most of the large
memory and graphics machinery is a project-specific SoC addition, not part of
the CPU core.

Core-side transaction interfaces
--------------------------------

`hazard3_core.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_core.v>`_ has logically separate channels
for:

* instruction fetch; and
* load/store data accesses.

This allows the same core to be wrapped in different system architectures.
The standard Hazard3 wrappers demonstrate two common choices:

``hazard3_cpu_2port``
   Keeps instruction and data AHB5 traffic on separate master ports.

``hazard3_cpu_1port``
   Arbitrates instruction and data requests onto one AHB5 master port.

Hazard3-Doom instantiates
`hazard3_cpu_1port.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_cpu_1port.v>`_. This is the first place
where a student should distinguish **pipeline parallelism** from **memory-bus
parallelism**: F and M may both have reasons to access memory, but the one-port
wrapper must serialize access to the shared external master interface.

AHB5 concepts visible in the wrapper
------------------------------------

The wrapper exposes the familiar AHB-style address/control and data-phase
signals, including address, transfer type, size, write direction, response,
ready, and read/write data. It also contains the exclusive-access signals used
when Hazard3's optional ``A`` extension is synthesized.

The project disables ``EXTENSION_A``, so software cannot execute RISC-V atomic
memory instructions in this bitstream even though the standard wrapper has the
bus plumbing needed for configurations that do enable them.

SoC bus hierarchy
-----------------

At a high level, the project memory path is:

.. code-block:: text

                     +-------------------+
   instruction ----->|                   |
                     | hazard3_cpu_1port |---- AHB5 ----+
   load/store ------>|                   |              |
                     +-------------------+              v
                                                +---------------+
                                                | example SoC   |
                                                | decode/fabric |
                                                +---------------+
                                                  |     |     |
                                                SRAM  APB   SDRAM

The CPU does not need to know whether an address ultimately reaches ECP5 block
RAM, an APB UART, external SDRAM, or a project video aperture. It issues a
normal architectural load/store; address decoding in the SoC determines the
destination.

Reset vector and resident SRAM
------------------------------

The pinned example SoC instantiates the processor with:

.. code-block:: text

   RESET_VECTOR = 0x00000040

The ULX3S wrapper configures 128 KiB of internal SRAM and supplies
``hazard3_boot.hex`` as the preload image. This is a project customization: it
allows the resident monitor to be present immediately after FPGA
configuration, so cold boot does not depend on first downloading code through
the debugger.

The relevant source locations are:

* `example_soc.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/example_soc/soc/example_soc.v>`_ - CPU reset vector and
  SoC memory/peripheral integration.
* `fpga_ulx3s.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/example_soc/fpga/fpga_ulx3s.v>`_ - 128 KiB SRAM depth,
  preload filename, board options, and selected CPU parameters.
* `hazard3_boot.hex <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/example_soc/soc/hazard3_boot.hex>`_ - generated
  resident-monitor initialization image in this fork snapshot.

See :doc:`../memory-map` for the Hazard3-Doom software-visible memory layout.

External SDRAM is not a Hazard3 CPU feature
-------------------------------------------

The large Doom image, heap, IWAD data, and video buffers live in external
memory in the project design. Support for that memory lives in the fork's
example-SoC integration, including modules such as ``ahb_sdram.v`` and the
ULX3S SDRAM controller.

This is a critical architectural boundary:

* **Upstream CPU responsibility:** execute loads/stores and obey bus
  ready/error responses.
* **Project SoC responsibility:** decode SDRAM address windows, implement
  caching/aliases where configured, arbitrate SDRAM users, and drive board
  memory pins.

A CPU load from ``0x20xxxxxx`` is not a special "SDRAM instruction." It is a
normal RISC-V load whose physical address happens to be routed to the external
memory subsystem.

Memory ordering and ``fence.i``
-------------------------------

The project enables ``Zifencei``. ``fence.i`` exists to synchronize instruction
fetch with prior writes that may have changed instruction memory. Hazard3
exports memory-ordering/fetch-flush intent so the surrounding system can
participate when required. This matters more as a SoC gains caches or other
state between the core and memory.

For self-modifying code or a loader that writes executable memory and then
jumps into it, this is the conceptual sequence to understand:

.. code-block:: text

   write new instruction bytes
          |
          v
   complete required data ordering
          |
          v
       fence.i
          |
          v
   fetch newly written instructions

The exact software loading path in Hazard3-Doom is handled by the resident
monitor and project memory system, but the instruction-fetch synchronization
mechanism is standard RISC-V/Hazard3 behavior.

No MMU in this project
----------------------

This configuration is a bare-metal embedded system. It does not enable a
virtual-memory MMU, and it does not enable user-mode/PMP isolation. Addresses
in :doc:`../memory-map` are therefore best understood as SoC physical address
windows used directly by machine-mode firmware and the Doom application.
