RISC-V Debug Architecture
=========================

Hazard3 includes an upstream RISC-V external-debug implementation. This is a
processor/platform capability, not a Doom-specific debugger added by the
application project.

The path used on ULX3S is particularly instructive because it demonstrates how
a standard RISC-V debug protocol can be attached to FPGA-vendor JTAG hardware.

Debug path
----------

The conceptual chain is:

.. code-block:: text

   GDB
    |
    v
   OpenOCD
    |
    v
   ECP5 chip JTAG TAP
    |
    v
   ECP5 JTAGG custom data registers
    |
    v
   Hazard3 JTAG Debug Transport Module (DTM)
    |
    v
   Debug Module Interface (DMI)
    |
    v
   Hazard3 Debug Module (DM)
    |
    +--> halt/resume CPU
    +--> inject instructions
    +--> access debug data register
    `--> system-bus access

The ECP5-specific transport is implemented in
`hazard3_ecp5_jtag_dtm.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/debug/dtm/hazard3_ecp5_jtag_dtm.v>`_. It
uses the ECP5 ``JTAGG`` primitive to attach the DTMCS and DMI data registers to
the FPGA's existing chip TAP. The design can therefore use the board's normal
USB/JTAG connection rather than requiring a second soft JTAG TAP in fabric.

Debug Module
------------

The standard Hazard3 Debug Module is in
`hazard3_dm.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/debug/dm/hazard3_dm.v>`_. It implements the control
plane between a debugger and one or more Hazard3 harts. Important mechanisms
include:

* halt and resume requests;
* abstract register-access commands;
* a debug ``data0`` register shared with a halted hart;
* a small program buffer for injected debug instructions; and
* system-bus access for debugger memory reads/writes independent of normal
  software execution.

The project enables ``DEBUG_SUPPORT=1`` in the CPU instance, which turns on the
core-side debug mode, debug CSRs, run/halt behavior, and instruction-injection
interface required by the DM.

Instruction injection
---------------------

Instruction injection is an elegant part of RISC-V debug. Instead of building
a completely separate path to every internal CPU register, the Debug Module can
halt the hart and cause carefully chosen instructions to execute in debug
mode. Those instructions can move data between architectural registers and
the debug data register.

The Hazard3 front end participates directly: when halted in debug mode, it can
accept debugger-provided instruction words instead of normal instruction
fetch traffic. This reuses the real decode/execute datapath and keeps debug
behavior close to architectural execution.

System-bus access
-----------------

The Debug Module can also request memory transactions through the CPU wrapper's
debug system-bus interface. This is different from injected instructions:
OpenOCD can inspect or modify memory without asking the halted program to
execute a normal RISC-V load/store sequence for every access.

The one-port wrapper arbitrates this debug traffic with the same SoC-facing
bus resources used by the processor. When debugging a memory-mapped peripheral,
remember that a debugger read can have the same hardware side effects as a
software read if the peripheral defines read side effects.

Hardware breakpoint triggers
----------------------------

Upstream Hazard3 can implement instruction-address triggers. However, the
pinned ULX3S wrapper does not override ``BREAKPOINT_TRIGGERS``, whose pinned
default is zero. Therefore students should not assume this bitstream contains
optional hardware execute-trigger slots merely because the upstream core can
support them.

Software breakpoints, debug halt, single-step behavior supported by the debug
stack, and debugger memory/register access are separate mechanisms from those
optional trigger comparators.

What is standard and what is board-specific?
--------------------------------------------

.. list-table::
   :header-rows: 1
   :widths: 40 60

   * - Standard Hazard3/upstream concept
     - ULX3S project selection
   * - RISC-V Debug Module
     - Used directly.
   * - Hazard3 JTAG-DTM logic
     - Used through the ECP5-specific DTM wrapper.
   * - ECP5 ``JTAGG`` adapter
     - Upstream Hazard3 already provides this ECP5 integration; it is not a Hazard3-Doom invention.
   * - ``DEBUG_SUPPORT`` configurability
     - Enabled in the project CPU instance.
   * - OpenOCD/GDB protocol flow
     - Project supplies configuration/helper scripts for its board/build artifacts.
   * - Optional execute-address triggers
     - Not selected in this pinned ULX3S CPU configuration.

Practical debugging
-------------------

See :doc:`../../user-guide/jtag-debugging` for the project OpenOCD/GDB and
VisualGDB workflow. This architecture page explains what those tools are
actually talking to inside the FPGA.

A useful lab exercise is to halt the resident monitor at a known function,
inspect integer registers, read a RAM word through the debugger, single-step
one instruction, and then identify which of those operations used CPU debug
state versus system-bus access.
