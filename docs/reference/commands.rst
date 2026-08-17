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
