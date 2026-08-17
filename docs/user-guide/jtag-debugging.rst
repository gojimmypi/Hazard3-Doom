JTAG Debugging
==============

Hazard3 includes a RISC-V debug module, allowing source-level debug of the resident monitor through the ECP5 JTAG path and OpenOCD/GDB.

OpenOCD
-------

The project keeps its OpenOCD configuration under ``openocd/`` and helper scripts under ``scripts/``. A typical workflow is:

#. Connect the ULX3S through its normal USB/JTAG interface.
#. Start OpenOCD with the project configuration.
#. Connect a RISC-V GDB client to ``localhost:3333``.
#. Load or attach to ``build/hazard3-boot-monitor.elf``.

Batch monitor load
------------------

With OpenOCD already running and no other GDB client attached:

.. code-block:: bash

   ./scripts/load-firmware.sh

Or provide an explicit ELF:

.. code-block:: bash

   ./scripts/load-firmware.sh /path/to/hazard3-boot-monitor.elf

VisualGDB
---------

Windows users can use the project files under ``VisualGDB/`` with Visual Studio. The debugger still talks to the same OpenOCD/GDB target, so the command-line path remains the reference workflow.

The GDB startup helper is:

.. code-block:: text

   scripts/hazard3-debug.gdb

Troubleshooting
---------------

If the debug module is not detected reliably, reduce the JTAG clock before changing the HDL. USB/JTAG signal quality and adapter timing can cause failures that look like CPU debug failures.

See :doc:`../troubleshooting` for common OpenOCD and ownership problems.
