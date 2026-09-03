Monitor Command Reference
=========================

External-memory qualification
-----------------------------

The ULX4M-LD DDR3 route was hardware-qualified with these monitor commands.
Wait for ``s`` to report ``external_memory_ready=YES`` before destructive
memory tests.

.. list-table::
   :header-rows: 1

   * - Command
     - Description
   * - ``m``
     - Destructive 1 MiB sequential diagnostic-window test. Checks access
       widths plus zero, ones, address, and inverse-address patterns.
   * - ``a``
     - Sparse address/bank alias test across the full 64 MiB software-visible
       external-memory window.
   * - ``r``
     - Pseudorandom 1 MiB test in each of four separated memory regions.
   * - ``q``
     - Run the complete sequential + sparse + pseudorandom qualification suite.
   * - ``k``
     - Heap allocation/stress test. The 64 MiB ULX4M-LD profile exercises the
       40 MiB heap window.
   * - ``d``
     - Doom platform memory/timer smoke test.
   * - ``x``
     - Copy RV32 payload code to external memory and execute it, including
       normal-GP and foreign-GP phases with timer interrupts and guard checks.
   * - ``z``
     - Reset the heap; all existing heap pointers become invalid.
   * - ``s``
     - Print runtime status, including external-memory readiness and LiteDRAM
       initialization/PLL/user-clock state.
   * - ``v``
     - Print firmware, FPGA, memory-core, and adapter version IDs.

A startup ``TIMEOUT`` is not by itself a final DDR failure. During the current
ULX4M-LD bring-up, LiteDRAM finished after the monitor's initial 5-second wait;
``s`` later reported ready and the complete qualification suite passed.

Boot and Doom
-------------

.. list-table::
   :header-rows: 1

   * - Command
     - Description
   * - ``l``
     - Receive a packaged Doom image over UART.
   * - ``w``
     - Receive the IWAD over UART.
   * - ``j``
     - Launch the validated executable and WAD.
   * - ``b``
     - Run the SD boot loader.
   * - ``c``
     - Print SD/FAT boot status.

SAO / I2C
---------

.. list-table::
   :header-rows: 1

   * - Command
     - Description
   * - ``sao info``
     - Show SAO bridge/ownership state.
   * - ``sao gui``
     - Launch the I2CDriver-style HDMI diagnostic interface.
   * - ``sao recover``
     - Attempt bus recovery.
   * - ``sao scan``
     - Scan the SAO I2C bus.
   * - ``sao probe``
     - Probe a device/address.
   * - ``sao read``
     - Read from an SAO I2C target.
   * - ``sao write``
     - Write to an SAO I2C target.
   * - ``i2c scan``
     - Scan the I2C bus using the compatibility command.
   * - ``i2c gui``
     - Alias for ``sao gui``.

Interactive HDMI I2C controls
-----------------------------

After ``sao gui`` or ``i2c gui`` starts, the UART becomes the keyboard input
for the HDMI interface. ``S`` scans, ``P`` probes, ``R`` reads one register,
``W`` writes one register, ``X`` attempts bus recovery, ``1``/``4`` select
100/400 kHz, ``C`` clears display state, and ``Q`` exits. See
:doc:`../user-guide/i2cdriver` for operand entry, safety notes, and logical
trace behavior.

Web Serial reserved control bytes
---------------------------------

These raw bytes are part of the browser screen-snip transport rather than
resident-monitor text commands:

.. list-table::
   :header-rows: 1

   * - Byte
     - Purpose
   * - ``0x1c``
     - Screen-snip capability query.
   * - ``0x06``
     - Capability ACK from a supported monitor cache or active display application.
   * - ``0x1d``
     - Screen-snip capture request.

See :doc:`../user-guide/web-serial` for the complete ``H3SNIP1`` protocol and
state machine.
