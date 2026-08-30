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

External DRAM is not a Hazard3 CPU feature
------------------------------------------

The large Doom image, heap, IWAD data, and video buffers live in external
memory in the project design. Support for that memory lives in the fork's
example-SoC integration. The ULX3S and ULX4M-LS targets use the native SDR
SDRAM path, while ULX4M-LD uses the LiteDRAM DDR3 path.

This is a critical architectural boundary:

* **Upstream CPU responsibility:** execute loads/stores and obey bus
  ready/error responses.
* **Project SoC responsibility:** decode external-memory address windows,
  implement caching/aliases where configured, arbitrate memory users, and
  drive the board memory interface.

A CPU load from ``0x20xxxxxx`` is not a special "SDRAM instruction." It is a
normal RISC-V load whose physical address happens to be routed to the external
memory subsystem.

Memory controller implementations
---------------------------------

Hazard3-Doom uses three distinct memory mechanisms. Internal ECP5 EBR is
synchronous block SRAM inside the FPGA and does not need a DRAM controller.
The board-level SDR SDRAM and DDR3 devices are separate external memories and
require controllers with refresh and DRAM timing state.

.. list-table::
   :header-rows: 1
   :widths: 19 20 27 34

   * - Target/memory
     - Physical interface
     - Controller path
     - Important behavior
   * - ECP5 internal EBR
     - On-chip synchronous SRAM
     - ``ahb_sync_sram`` / inferred EBR
     - No activate/precharge, refresh, or DRAM training. This is the lowest
       latency and most deterministic memory, but EBR capacity is limited.
   * - ULX3S 12F/85F
     - External 16-bit SDR SDRAM
     - ``ahb_sdram.v`` -> ``ulx3s_sdram_controller.v``
     - Native project SDR controller. It accepts one controller request at a
       time, keeps rows open across accesses when possible, uses CAS latency 2,
       and periodically precharges for refresh. CPU and video requests are
       arbitrated at the AHB/SDRAM adapter.
   * - ULX4M-LS 85F
     - External 16-bit SDR SDRAM, 32 MiB board device
     - ``ahb_sdram.v`` -> ``ulx3s_sdram_controller.v``
     - Uses the same native SDR memory subsystem as the ULX3S path at a 50 MHz
       system clock. The board wrapper forwards a half-cycle-shifted SDRAM
       clock and keeps video on a separate PLL.
   * - ULX4M-LD 85F
     - External DDR3
     - ``ahb_litedram.v`` -> generated LiteDRAM -> ``ECP5DDRPHY``
     - LiteDRAM runs a 75 MHz user port with a 128-bit Wishbone interface while
       Hazard3/AHB runs at 50 MHz. The adapter crosses the clock domains one
       request at a time. Startup firmware performs DDR3 initialization, read
       leveling, and a memory test before normal accesses are enabled.

The two external-memory paths therefore have different performance tradeoffs.
The native SDR controller is simpler and has less interface machinery, but
external SDR SDRAM still has activate/CAS/refresh latency. DDR3 offers much
higher burst bandwidth, while the current ULX4M-LD adapter adds clock-domain
crossing and request-conversion overhead. In particular, the current adapter
maps each DDR3 BL8 transfer to one 128-bit Wishbone word; writes use an atomic
128-bit read/modify/write path before the full burst is written. For the
in-order Hazard3 core, first-access latency and cache behavior can matter more
than peak DDR transfer rate.

Do not confuse the ULX3S external SDRAM with ECP5 EBR. EBR is SRAM physically
inside the FPGA; the SDR SDRAM chip is a separate device on the board. LiteDRAM
is not used in the ULX3S native SDR path.

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
