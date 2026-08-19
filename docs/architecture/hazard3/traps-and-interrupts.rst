Traps, Interrupts, and CSRs
===========================

RISC-V uses the term **trap** for a transfer of control caused by either a
synchronous exception or an asynchronous interrupt. Hazard3 implements the
machine-mode trap state used by this project in
`hazard3_csr.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_csr.v>`_.

Project privilege model
-----------------------

The Hazard3-Doom CPU is configured as a machine-mode embedded system:

* machine CSR support is enabled;
* machine trap support is enabled;
* user mode is not enabled;
* software interrupt input is tied low;
* one external interrupt input is used for the UART; and
* the platform timer drives the machine timer interrupt input.

The processor reset vector is ``0x00000040``. The initial ``mtvec`` value is
``0x00000000`` in the example-SoC instantiation; startup firmware is responsible
for establishing the desired runtime trap entry arrangement.

Important machine CSRs
----------------------

The following standard CSRs are the most useful starting point for students:

.. list-table::
   :header-rows: 1
   :widths: 22 78

   * - CSR
     - Role
   * - ``mstatus``
     - Global machine interrupt enable and saved interrupt/privilege state used across trap entry and return.
   * - ``mtvec``
     - Machine trap-vector base and direct/vectored mode selection.
   * - ``mepc``
     - Program counter associated with the trapped instruction or interrupted execution point.
   * - ``mcause``
     - Identifies whether the trap was an interrupt or exception and records the cause code.
   * - ``mie``
     - Per-source machine interrupt enables.
   * - ``mip``
     - Pending interrupt state visible to software.
   * - ``mtval``
     - Trap-value CSR. In this pinned Hazard3 implementation it is hardwired to zero.
   * - ``mcycle`` / ``minstret``
     - Cycle and retired-instruction counters when counter support is enabled.

The pinned CSR RTL masks ``mepc`` according to instruction alignment. Because
``C`` is enabled, a valid instruction PC may be aligned on a 16-bit boundary;
it need not always be 32-bit aligned.

Exception versus interrupt
--------------------------

A useful mental model is:

.. code-block:: text

   synchronous problem in current instruction
       -> exception
       -> examples: illegal instruction, access fault, ecall, ebreak

   asynchronous event from outside instruction stream
       -> interrupt
       -> examples: UART or timer event

Both enter the machine trap path, but ``mcause`` distinguishes them. The high
bit indicates interrupt versus exception, while the cause field identifies the
specific source implemented by the core.

Trap entry
----------

At a high level, machine trap entry performs these architectural actions:

#. stop normal retirement at a precise instruction boundary;
#. save the appropriate PC into ``mepc``;
#. write the trap reason into ``mcause``;
#. update machine interrupt-enable stack state in ``mstatus``; and
#. redirect instruction fetch to the address selected from ``mtvec``.

The exact PC saved for an exception is not always the same conceptual point as
for an interrupt. Hazard3's M-stage control explicitly distinguishes trap
conditions so that ``mret`` can resume at the architecturally correct PC.

Trap return
-----------

``mret`` restores machine trap state and redirects fetch to ``mepc``. This is
one reason trap handling must be coordinated with the pipeline front end: any
instructions fetched from the old path must be discarded when execution
returns to the saved PC.

External interrupt wiring in this project
-----------------------------------------

The pinned
`example_soc.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/example_soc/soc/example_soc.v>`_ connects the processor's
interrupt ports as follows:

.. code-block:: text

   hazard3_cpu_1port
       irq[0]    <- UART IRQ
       soft_irq  <- 0
       timer_irq <- platform timer IRQ

``NUM_IRQS=1`` is the normal Hazard3 setting here. The optional Hazard3 custom
interrupt-controller extension is not selected by the ULX3S wrapper, so this
is intentionally close to the standard RISC-V machine interrupt model.

Interrupt enable layering
-------------------------

Receiving an electrical/peripheral interrupt signal is only one part of
handling an interrupt. Software typically must also arrange:

#. the peripheral-specific interrupt-enable state;
#. the appropriate bit in ``mie``; and
#. global machine interrupt enable in ``mstatus``.

Then the handler must service/acknowledge the peripheral source before
returning, or a level-sensitive interrupt can immediately become pending again.

Educational example
-------------------

A minimal timer/UART interrupt exercise can be approached in this order:

#. install a trap handler and set ``mtvec``;
#. inspect ``mcause`` in the handler;
#. enable one interrupt source at a time;
#. record ``mepc`` and selected CSRs over UART;
#. acknowledge the peripheral; and
#. return with ``mret``.

This makes the relationship between **peripheral**, **CSR interrupt state**,
**pipeline redirect**, and **handler software** directly visible.

Source study
------------

Use these pinned files together:

* `hazard3_csr.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_csr.v>`_ - CSR decode, ``mstatus``,
  ``mepc``, ``mcause``, interrupt state, and trap-state updates.
* `hazard3_core.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_core.v>`_ - exception detection, trap
  sequencing, fetch redirects, and M-stage completion.
* `example_soc.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/example_soc/soc/example_soc.v>`_ - actual UART/timer
  interrupt wiring in the project.
