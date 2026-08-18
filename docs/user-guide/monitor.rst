Resident Monitor
================

The resident monitor is the firmware that remains available even when the loadable Doom application is replaced or exits. It provides UART commands, loader protocols, diagnostics, and the recovery path used during development.

Core Doom commands
------------------

.. list-table::
   :header-rows: 1
   :widths: 15 85

   * - Command
     - Function
   * - ``l``
     - Receive a packaged Doom executable image over UART.
   * - ``w``
     - Receive an IWAD into the reserved SDRAM region.
   * - ``j``
     - Launch the validated Doom image and IWAD.
   * - ``b``
     - Attempt the micro-SD boot flow.
   * - ``c``
     - Print SD/FAT boot status and counters.

SAO / I2C HDMI diagnostics
--------------------------

The monitor can launch the interactive HDMI I2C diagnostic interface with:

.. code-block:: text

   i2c gui

or ``sao gui``. While the GUI is active, UART keystrokes control the HDMI
interface. Exit with ``Q``, ``Ctrl-X``, or Esc when no operand prompt is active.
See :doc:`i2cdriver` for the complete control reference.

Returning from Doom
-------------------

Press ``Ctrl-X`` while Doom is running to return to the monitor. This is useful before uploading a replacement executable or WAD.

The repository also contains helper scripts for returning to or restarting from the monitor when a terminal is not convenient.

Monitor build
-------------

The current branch still names the monitor ELF ``build/hazard3-boot-monitor.elf``. Functionally, this ELF is the resident monitor firmware used for bring-up, debugging, loaders, and diagnostics.
