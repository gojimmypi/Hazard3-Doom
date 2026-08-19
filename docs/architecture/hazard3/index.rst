Hazard3 RISC-V Processor
========================

Hazard3 is the processor at the center of Hazard3-Doom. It is a compact,
in-order, three-stage 32-bit RISC-V CPU designed for FPGA and ASIC use. The
Hazard3 project also provides the surrounding debug hardware and example SoC
integration used to turn the CPU core into a usable system.

This section explains the processor from an educational point of view and,
just as importantly, separates the **standard Hazard3 design** from the
**ULX3S/Hazard3-Doom integration** built around it.

Source snapshot used by this project
------------------------------------

The technical descriptions in these pages are anchored to the Hazard3 source
snapshot used for this documentation review:

* ULX3S Hazard3 fork commit: ``736a74459b3f740c47803f20a62d820fcacbe5c3``
* `Browse the pinned source <https://github.com/ulx3s/Hazard3/tree/736a74459b3f740c47803f20a62d820fcacbe5c3>`_
* `Browse current upstream Hazard3 stable <https://github.com/Wren6991/Hazard3/tree/stable>`_

.. important::

   The pinned SHA is the authority for the FPGA build described here. Upstream
   Hazard3 continues to evolve. A feature present in current upstream
   ``stable`` or ``develop`` is not automatically present in this project
   until the Hazard3 submodule is deliberately updated.

What is upstream Hazard3?
-------------------------

The processor RTL under ``hdl/`` is upstream Hazard3 architecture: the
three-stage core, instruction front end, decoder, arithmetic units, CSRs,
interrupt logic, debug-mode hooks, register file, PMP support, triggers, and
the one-port/two-port CPU wrappers. The same architectural module families are
present in current upstream Hazard3.

Upstream also supplies a minimal example SoC and RISC-V debug implementation.
The normal upstream example is intentionally small: processor, debug, RAM,
UART, and a platform timer are enough to demonstrate and debug the CPU.

What is customized for Hazard3-Doom?
------------------------------------

The ULX3S fork expands the example-SoC and board-integration layer rather than
turning Hazard3 into a Doom-specific CPU. Project additions include external
SDRAM support, video access, SD-card SPI, SAO/ESP32 integration, board pin and
ownership logic, and a preloaded resident monitor image.

That boundary is useful when learning the design:

.. code-block:: text

   RISC-V software
         |
         v
   +-------------------------------+
   | Standard Hazard3 CPU          |
   | F -> X -> M pipeline          |
   | ISA, CSR, traps, debug hooks  |
   +-------------------------------+
         |
         | AHB5 master interface
         v
   +-------------------------------+
   | Example SoC / project fabric  |
   | RAM, APB, timer, UART         |  <- upstream foundation
   | SDRAM, video, SD, SAO, ESP32  |  <- ULX3S project additions
   +-------------------------------+
         |
         v
   ECP5 FPGA and board peripherals

Actual ULX3S processor configuration
------------------------------------

The pinned ULX3S FPGA wrapper selects a performance-oriented RV32I
configuration. The important effective settings are:

.. list-table::
   :header-rows: 1
   :widths: 34 18 48

   * - Feature
     - Project setting
     - Educational meaning
   * - Base ISA
     - RV32I
     - 32-bit integer ISA with 32 integer registers.
   * - ``M``
     - Enabled
     - Hardware multiply, divide, and remainder instructions.
   * - ``C``
     - Enabled
     - 16-bit compressed instructions can be mixed with 32-bit instructions.
   * - ``Zba`` / ``Zbb`` / ``Zbs``
     - Enabled
     - Address-generation, basic bit-manipulation, and single-bit operations.
   * - ``Zifencei``
     - Enabled
     - Instruction-fetch synchronization with ``fence.i``.
   * - ``A``
     - Disabled
     - Atomic memory instructions are not part of this synthesized CPU.
   * - Machine counters
     - Enabled
     - Cycle/instruction-retirement counter CSRs are implemented.
   * - Debug support
     - Enabled
     - The CPU connects to the Hazard3 RISC-V Debug Module.
   * - User mode / PMP
     - Not enabled
     - This project is a machine-mode embedded system, not a protected OS target.
   * - CPU clock
     - 50 MHz nominal
     - The wrapper passes ``CLK_MHZ=50`` to the example SoC.
   * - Branch predictor
     - Enabled
     - Hazard3's small backward-branch predictor is synthesized.

The exact wrapper is `fpga_ulx3s.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/example_soc/fpga/fpga_ulx3s.v>`_.
The generic parameter definitions are in
`hazard3_config.vh <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_config.vh>`_.

Learning path
-------------

.. toctree::
   :maxdepth: 1

   overview
   pipeline
   isa-and-configuration
   memory-and-bus
   traps-and-interrupts
   debug
   project-integration
   source-tour
