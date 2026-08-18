Monitor Command Reference
=========================

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
