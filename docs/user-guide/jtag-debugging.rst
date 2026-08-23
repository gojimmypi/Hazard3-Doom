JTAG Debugging
==============

Hazard3 includes an upstream RISC-V Debug Module and Debug Transport Module.
On ULX3S, Hazard3's ECP5 adapter attaches the RISC-V DTM registers to the ECP5
chip JTAG TAP through the ``JTAGG`` primitive. This allows source-level debug
through the board's normal USB/JTAG connection.

For an explanation of the hardware path, abstract commands, instruction
injection, system-bus access, and which debug features are selected in this
bitstream, see :doc:`../architecture/hazard3/debug`.

OpenOCD
-------

The project keeps its OpenOCD configuration under ``openocd/`` and helper
scripts under ``scripts/``. On Windows, the current ULX3S ``ft232r`` OpenOCD
path has been verified with both **WinUSB** and **libusbK** on the on-board
FT231X. WinUSB is the preferred development binding when the same machine also
uses the Hazard3-Doom WebUSB FPGA flasher. The default FTDI VCP/D2XX binding is
for FTDI-native tools such as Windows ``fujprog`` and is not the OpenOCD
libusb path.

GDB connects to OpenOCD over TCP, normally ``localhost:3333``. It therefore
inherits the USB compatibility of the OpenOCD process; GDB itself does not
open the FT231X. See :doc:`web-flasher` for the driver compatibility matrix.

A typical workflow is:

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

Windows users can use the project files under ``VisualGDB/`` with Visual
Studio. The debugger still talks to the same OpenOCD/GDB target, so the
command-line path remains the reference workflow.

The GDB startup helper is:

.. code-block:: text

   scripts/hazard3-debug.gdb

Troubleshooting
---------------

If the debug module is not detected reliably, reduce the JTAG clock before
changing the HDL. USB/JTAG signal quality and adapter timing can cause failures
that look like CPU debug failures.

See :doc:`../troubleshooting` for common OpenOCD and ownership problems.
