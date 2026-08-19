Guided Source-Code Tour
=======================

This page is a reading map for students who want to move from the block diagram
to actual RTL. All project links below are pinned to commit ``736a74459b3f740c47803f20a62d820fcacbe5c3``, so line
content will not silently change when a branch advances.

Recommended reading order
-------------------------

1. Configuration first
~~~~~~~~~~~~~~~~~~~~~~

Start with
`hazard3_config.vh <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_config.vh>`_ and
`hazard3_config_inst.vh <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_config_inst.vh>`_.

Questions to answer before reading the datapath:

* Which ISA extensions can this snapshot synthesize?
* Which features default on or off?
* Which parameters affect architecture and which affect performance/area?
* How are parameters propagated through nested module instances?

Then open
`fpga_ulx3s.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/example_soc/fpga/fpga_ulx3s.v>`_ and compare the project
values with those generic defaults.

2. Find the CPU in the SoC
~~~~~~~~~~~~~~~~~~~~~~~~~~

Open
`example_soc.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/example_soc/soc/example_soc.v>`_ and locate
``hazard3_cpu_1port``. Note the fixed system-level choices around the instance:
reset vector, trap CSR support, debug enable, IRQ count, UART interrupt, and
timer interrupt.

Next open
`hazard3_cpu_1port.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_cpu_1port.v>`_. Identify three groups
of signals:

* the single SoC-facing AHB5 master;
* the internal instruction/data traffic connected to ``hazard3_core``; and
* the debugger control/system-bus signals.

The wrapper is a good lesson in interface adaptation: the architectural core
does not have to contain the policy for sharing one external bus.

3. Walk the pipeline
~~~~~~~~~~~~~~~~~~~~

Open `hazard3_core.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_core.v>`_ and search for the stage
headings. Follow:

* F-stage inputs from the front end;
* X-stage decode/execute signals;
* the X-to-M pipeline register set;
* M-stage writeback and stall signals; and
* redirect/trap/debug paths back toward fetch.

Do not try to understand every wire on the first pass. Track one simple
instruction such as ``addi``, then a load, then a branch.

4. Study instruction fetch
~~~~~~~~~~~~~~~~~~~~~~~~~~

Open
`hazard3_frontend.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_frontend.v>`_ and
`hazard3_instr_decompress.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_instr_decompress.v>`_.

Look for:

* the two-word prefetch FIFO;
* instruction halfword buffering;
* compressed-versus-32-bit instruction selection;
* fetch PC redirects;
* PMP execute-permission checking hooks; and
* debug instruction injection.

Exercise: draw the halfwords required when a 32-bit instruction begins at an
address ending in ``...2`` while ``C`` is enabled.

5. Decode a few instructions
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Open `hazard3_decode.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_decode.v>`_. Pick one instruction
from each class:

* ``add`` - base integer ALU;
* ``lw`` - load/store path;
* ``beq`` - branch path;
* ``mul`` - M extension;
* a Zba scaled-add instruction; and
* an atomic instruction encoding while ``EXTENSION_A=0``.

The last example is particularly useful: configuration parameters participate
in legality checking, so synthesis configuration becomes visible to software
through illegal-instruction traps.

6. Follow the ALU and M extension
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Relevant arithmetic sources include:

* `hazard3_alu.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/arith/hazard3_alu.v>`_
* `hazard3_mul_fast.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/arith/hazard3_mul_fast.v>`_
* `hazard3_muldiv_seq.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/arith/hazard3_muldiv_seq.v>`_

Compare the fast multiplier with the iterative unit and relate them back to
``MUL_FAST``, ``MUL_FASTER``, ``MULH_FAST``, and ``MULDIV_UNROLL``. This is a
practical FPGA architecture exercise in exchanging LUT/DSP/route cost for
latency.

7. Read CSR and trap state
~~~~~~~~~~~~~~~~~~~~~~~~~~

Open `hazard3_csr.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_csr.v>`_. Search for these names in
order:

.. code-block:: text

   MSTATUS
   MTVEC
   MEPC
   MCAUSE
   MIE
   MIP
   MCYCLE
   MINSTRET
   DCSR

Notice that CSR presence is parameterized. Then return to ``hazard3_core.v``
and find where trap entry and return drive pipeline redirection.

8. Read the debug stack
~~~~~~~~~~~~~~~~~~~~~~~

Use this order:

* `hazard3_dm.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/debug/dm/hazard3_dm.v>`_ - Debug Module state,
  abstract commands, program buffer, and system-bus access.
* `hazard3_ecp5_jtag_dtm.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/debug/dtm/hazard3_ecp5_jtag_dtm.v>`_ -
  DMI transport through ECP5 JTAGG.
* ``hazard3_frontend.v`` and ``hazard3_core.v`` - core-side halt/debug-mode and
  injected-instruction behavior.

Then compare the hardware flow with the commands in
:doc:`../../user-guide/jtag-debugging`.

9. Cross the CPU/SoC boundary
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Only after understanding the CPU wrapper should you study the project-specific
SoC additions:

.. list-table::
   :header-rows: 1
   :widths: 35 65

   * - Pinned source
     - What to learn
   * - `ahb_sdram.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/example_soc/soc/ahb_sdram.v>`_
     - How normal AHB CPU traffic is adapted to external SDRAM behavior.
   * - `ulx3s_sdram_controller.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/example_soc/soc/ulx3s_sdram_controller.v>`_
     - Board-oriented SDR SDRAM command/data timing.
   * - `apb_sd_spi.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/example_soc/soc/apb_sd_spi.v>`_
     - A compact APB peripheral and SPI state machine.
   * - `apb_sao_bridge.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/example_soc/soc/apb_sao_bridge.v>`_
     - Memory-mapped project control around the SAO subsystem.
   * - `sao_shared_controller.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/example_soc/soc/sao_shared_controller.v>`_
     - Ownership/arbitration policy for shared board resources.
   * - `sao_esp32_uart_bridge.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/example_soc/soc/sao_esp32_uart_bridge.v>`_
     - Project sideband communication with the ESP32.

This ordering helps prevent a common source-reading mistake: assuming every
module under ``example_soc`` is part of the Hazard3 processor.

Suggested lab questions
-----------------------

Pipeline
   Which dependency patterns are satisfied by bypassing, and which force X to
   wait for M?

Compressed ISA
   Why can the bus fetch aligned 32-bit words while the architectural PC is
   only 16-bit aligned?

Configuration
   What software symptom would appear if a binary contained an ``amo*``
   instruction in this ``EXTENSION_A=0`` build?

Interrupts
   Trace the UART IRQ wire from the UART peripheral to ``hazard3_cpu_1port``,
   then to ``mip``/trap selection.

Debug
   Which debugger operations require the hart to execute injected
   instructions, and which can use system-bus access?

Integration
   Pick an SDRAM address from :doc:`../memory-map` and trace how the CPU's
   ordinary load/store becomes an external SDRAM transaction.

Upstream comparison
-------------------

After studying the pinned files, open
`current upstream stable <https://github.com/Wren6991/Hazard3/tree/stable>`_ and compare the same modules. Treat changes
there as upstream processor evolution until the Hazard3-Doom project updates
its pinned submodule. This habit keeps source archaeology reproducible.
