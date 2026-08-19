Three-Stage Pipeline
====================

The best way to understand Hazard3 is to follow an instruction through the
``F``, ``X``, and ``M`` stages in
`hazard3_core.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_core.v>`_ and
`hazard3_frontend.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_frontend.v>`_.

Stage F: fetch and prepare
--------------------------

The front end requests 32-bit aligned words from instruction memory. Because
the ``C`` extension is enabled in this project, the instruction stream itself
may contain either 16-bit or 32-bit instructions. A 32-bit instruction can
also begin in the upper half of one fetched word and finish in the lower half
of the next.

Hazard3 handles that mismatch with buffering rather than forcing the bus to
perform 16-bit instruction reads. The pinned front end contains:

* a two-entry, 32-bit prefetch queue; and
* an instruction assembly buffer made from instruction halfwords.

The queue decouples bus response timing from pipeline consumption. The
halfword buffer allows the core to form the next architectural instruction at
either 16-bit alignment. Compressed instructions are expanded before normal
execution logic consumes them.

Conceptually:

.. code-block:: text

   32-bit fetch words
        |
        v
   +-------------------+
   | prefetch queue    |  two words
   +-------------------+
        |
        v
   +-------------------+
   | halfword assembly |  handles 16/32-bit boundaries
   +-------------------+
        |
        v
   +-------------------+
   | C decompressor    |  if instruction is compressed
   +-------------------+
        |
        v
        X stage

A fetch redirect caused by a branch, jump, trap, return, debug event, or
``fence.i`` invalidates work from the old instruction stream and starts the
front end at the new PC.

Stage X: decode and execute
---------------------------

The X stage combines work that a textbook five-stage processor might split
between decode and execute stages. Important jobs include:

* decode the instruction and validate enabled ISA extensions;
* select ``rs1`` and ``rs2`` values, including bypassed results;
* perform integer ALU operations;
* compare branch operands;
* calculate branch/jump targets;
* calculate load/store addresses;
* initiate CSR, multiply/divide, and memory-side operations; and
* decide whether the instruction can advance into M.

The decoder is parameter-aware. For example, an atomic encoding is not merely
ignored when ``EXTENSION_A=0``; it is decoded as an illegal instruction. This
is why the synthesized configuration is part of the architectural contract
seen by software.

Stage M: complete and retire
----------------------------

The M stage holds the oldest in-flight instruction. It is where late results
are selected and where architectural completion becomes final. Examples
include:

* waiting for a load or store data phase to complete;
* selecting loaded data for register writeback;
* committing ALU/multiply/CSR results to ``rd``;
* entering a trap after a synchronous exception or accepted interrupt;
* completing debug-mode transitions; and
* retiring an instruction for the instruction-retired counter.

If the memory system asserts wait states, the M stage can stall. Backpressure
then propagates toward X and F so no younger instruction overtakes the older
one.

Data forwarding and hazards
---------------------------

A short pipeline can still suffer read-after-write hazards. Hazard3 includes
bypass paths so a result does not always need to be written to the register
file and then read back before the next instruction may use it.

Consider two dependent ALU instructions:

.. code-block:: asm

   add  x5, x6, x7
   xor  x8, x5, x9

With the normal full-bypass configuration, the ``xor`` can receive the
producer result through forwarding rather than waiting for a register-file
round trip.

A load-use dependency is different:

.. code-block:: asm

   lw   x5, 0(x6)
   add  x8, x5, x9

The load value does not exist until memory returns it. The pinned core's hazard
logic specifically treats load-use as a RAW case that can require a stall.
Actual delay also depends on the memory/bus response time.

The project does not enable ``REDUCED_BYPASS``, so it uses the more complete
bypass configuration.

Branches and the small predictor
--------------------------------

Hazard3 can synthesize a small branch-prediction mechanism. The project sets
``BRANCH_PREDICTOR=1``.

This is intentionally much simpler than a desktop CPU predictor. The pinned
core records a recently useful backward branch target and can redirect fetch
early for a predicted taken loop branch. Backward branches are a good target
for a tiny predictor because they commonly implement loops:

.. code-block:: asm

   loop:
       # loop body
       addi x5, x5, -1
       bnez x5, loop

The predictor reduces repeated fetch bubbles in tight loops when its simple
assumption is correct. On a mismatch, the core redirects the front end and
continues on the architectural path. Trap entry and instruction-fetch
synchronization also clear/invalidate prediction state where required.

Fast branch comparison
----------------------

``FAST_BRANCHCMP=1`` is selected in the ULX3S build. This enables the dedicated
fast branch-comparison path rather than relying only on a more serialized ALU
comparison route. It is a timing/performance implementation option; it does
not change RISC-V-visible branch semantics.

Multiply and divide behavior
----------------------------

The project enables the ``M`` extension and selects the fast multiply options:

.. code-block:: text

   MUL_FAST       = 1
   MUL_FASTER     = 1
   MULH_FAST      = 1
   MULDIV_UNROLL  = 4

The multiplication parameters trade FPGA logic for lower multiply latency and
better throughput. Division/remainder still use iterative arithmetic; the
unroll factor controls how much work the sequential unit performs per cycle.
This is a useful example of a recurring processor-design tradeoff: the ISA is
unchanged, while area, timing, and CPI can change substantially with RTL
parameters.

Pipeline study exercise
-----------------------

A useful source-reading exercise is to trace these four sequences in the RTL:

#. independent ALU operations;
#. an ALU result consumed by the next instruction;
#. a load immediately consumed by the next instruction; and
#. a taken backward branch in a loop.

Start in ``hazard3_core.v`` at the stage comments, then follow the stall,
bypass, branch-redirect, and M-stage writeback signals. Use
``hazard3_frontend.v`` to see what a redirect does to queued instruction data.
