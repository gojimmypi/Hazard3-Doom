Processor Overview
==================

Hazard3 is a small 32-bit RISC-V implementation with an intentionally compact
pipeline. It is not a microcoded teaching CPU, but its structure is simple
enough to follow from instruction fetch to retirement in the RTL.

The architectural center is
`hazard3_core.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_core.v>`_. The core presents separate
instruction-fetch and load/store transaction interfaces. Wrapper modules then
adapt those internal interfaces to AHB5 buses:

* `hazard3_cpu_1port.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_cpu_1port.v>`_ arbitrates instruction
  and data traffic onto one AHB5 master port.
* `hazard3_cpu_2port.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_cpu_2port.v>`_ exposes independent
  instruction and data AHB5 master ports.

Hazard3-Doom uses the **one-port** wrapper, so instruction fetches and data
accesses ultimately share the SoC-side AHB path.

Three stages, not five
----------------------

Introductory RISC material often presents a five-stage pipeline named IF, ID,
EX, MEM, WB. Hazard3 instead organizes the processor into three broad stages:

``F`` - fetch and instruction preparation
   Fetches aligned memory words, buffers instruction halfwords, handles
   compressed-instruction alignment and expansion, and prepares register
   source information for the next stage.

``X`` - decode and execute
   Decodes the instruction, reads/forwards operands, performs ALU and branch
   work, calculates addresses, starts multi-cycle operations, and determines
   whether the instruction may advance.

``M`` - memory completion and retirement
   Completes loads/stores and other late operations, selects writeback data,
   updates architectural state, and performs trap/debug retirement actions.

This does not mean memory exists only in stage M. Instruction fetch has its own
memory traffic, and a load/store address is initiated from the execute path.
The stage names describe where an instruction is in the pipeline, not every
physical activity occurring in that cycle.

Core module map
---------------

.. list-table::
   :header-rows: 1
   :widths: 32 68

   * - Source module
     - Responsibility
   * - ``hazard3_frontend.v``
     - Fetch queue, instruction assembly/alignment, compressed-instruction handling, fetch redirects, and debug instruction injection.
   * - ``hazard3_decode.v``
     - Maps RISC-V instruction encodings to internal ALU, load/store, CSR, branch, and extension controls.
   * - ``hazard3_core.v``
     - Pipeline registers, forwarding, hazards, execution flow, traps, and top-level core control.
   * - ``hazard3_alu.v``
     - Integer arithmetic, logical, shift, compare, and bit-manipulation datapath support.
   * - ``hazard3_mul_fast.v`` / ``hazard3_muldiv_seq.v``
     - Fast multiply paths and iterative multiply/divide/remainder machinery selected by configuration.
   * - ``hazard3_csr.v``
     - Machine/debug CSRs, trap state, counters, privilege state, interrupt state, and optional PMP/trigger-facing control.
   * - ``hazard3_regfile_1w2r.v``
     - Integer register file with two read ports and one write port.
   * - ``hazard3_irq_ctrl.v``
     - Optional Hazard3 external interrupt-controller extension.
   * - ``hazard3_pmp.v``
     - Optional Physical Memory Protection address matching and permissions.
   * - ``hazard3_triggers.v``
     - Optional instruction-address debug triggers.

Integer register file
---------------------

The normal RV32I configuration has registers ``x0`` through ``x31``. ``x0`` is
architecturally fixed to zero. Hazard3's register file is organized for two
source operands and one destination write per cycle, matching the common
RISC-V instruction shape:

.. code-block:: text

   add x5, x6, x7
       ^   ^   ^
       |   |   +-- rs2
       |   +------ rs1
       +---------- rd

The project leaves ``EXTENSION_E`` disabled, so it uses RV32I's full register
set rather than RV32E's reduced register set.

Machine-mode embedded design
----------------------------

Hazard3 is configurable enough to support more privilege and protection
features, but the Hazard3-Doom instantiation is deliberately straightforward:

* Machine-mode CSR and trap support are enabled.
* User mode is not enabled.
* PMP regions are not enabled.
* The standard external debug path is enabled.
* One external interrupt input is configured; the example SoC connects it to
  the UART interrupt. The platform timer drives the machine timer interrupt.
* The software-interrupt input is tied low in the example SoC.

This makes the build well suited for bare-metal education: code can study
interrupts, CSRs, bus transactions, and debug behavior without an MMU or an
operating-system privilege stack obscuring the path.

Upstream status
---------------

As reviewed on 2026-08-19, current upstream Hazard3 still describes itself as
a three-stage RV32I/RV32E processor with configurable standard extensions,
machine/user execution support, PMP, external debug, and instruction-address
triggers. Those are upstream capabilities, not Hazard3-Doom inventions.

The project-specific question is therefore not "what was changed inside the
RISC-V CPU for Doom?" but rather "which Hazard3 options were selected, and what
SoC hardware was placed around the CPU?" The following pages answer those two
questions in detail.
