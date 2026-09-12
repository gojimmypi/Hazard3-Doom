Hazard3 RISC-V Processor
========================

Hazard3 is the processor at the center of Hazard3-Doom. It is a compact,
in-order, three-stage 32-bit RISC-V CPU designed for FPGA and ASIC use. The
Hazard3 project also provides the surrounding debug hardware and example SoC
integration used to turn the CPU core into a usable system.

This section explains the processor from an educational point of view and,
just as importantly, separates the **standard Hazard3 design** from the
**ULX3S/Hazard3-Doom integration** built around it.


The Raspberry Pi RP2350 connection
----------------------------------

Hazard3 is also one of the processor architectures built into Raspberry Pi's
RP2350 microcontroller. RP2350 contains two open-hardware Hazard3 RISC-V cores
alongside two Arm Cortex-M33 cores; software or OTP configuration selects which
processor pair is used. RP2350 is the microcontroller used by Raspberry Pi Pico
2 and Pico 2 W.

That makes the processor in Hazard3-Doom especially interesting educationally:
the FPGA project is built around the same open-source Hazard3 processor design
used in a mass-produced Raspberry Pi microcontroller. It is not, however, a
claim that the two synthesized CPUs are configured identically. Hazard3 is
parameterized, and RP2350 enables a different set of ISA extensions, custom
extensions, debug features, and SoC integration than the Hazard3-Doom FPGA
configuration described below.

Useful primary references:

* `Raspberry Pi RP2350 product page <https://www.raspberrypi.com/products/rp2350/>`_
* `Raspberry Pi RP2350 datasheet, section 3.8 Hazard3 processor <https://datasheets.raspberrypi.com/rp2350/rp2350-datasheet.pdf>`_
* `Raspberry Pi Pico 2 product page <https://www.raspberrypi.com/products/raspberry-pi-pico-2/>`_
* `Raspberry Pi microcontroller documentation - architecture switching <https://www.raspberrypi.com/documentation/microcontrollers/microcontroller-chips.html#architecture-switching>`_
* `Upstream Hazard3 source and RP2350 configuration notes <https://github.com/Wren6991/Hazard3>`_

Source snapshot used by this project
------------------------------------

The technical descriptions in these pages are anchored to the Hazard3 source
snapshot used for this documentation review:

* ULX3S Hazard3 fork commit: |hazard3_commit|
* Upstream Hazard3 stable commit: at ``8af992930f71a69b0e06c38734c1094f41a05ca0`` (`here <https://github.com/Wren6991/Hazard3/commit/8af992930f71a69b0e06c38734c1094f41a05ca0>`_)
* :hazard3-tree:`Browse the pinned source </>`
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

The exact wrapper is :hazard3-src:`fpga_ulx3s.v <example_soc/fpga/fpga_ulx3s.v>`.
The generic parameter definitions are in
:hazard3-src:`hazard3_config.vh <hdl/hazard3_config.vh>`.

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
