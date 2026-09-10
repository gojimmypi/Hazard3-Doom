FPGA Configuration, Flash, and Boot Paths
=========================================

ULX3S has several programming paths that can look similar from the host but have
very different persistence. Keep the destination clear: ECP5 configuration
SRAM, SPI flash, or Hazard3 runtime memory.

Volatile FPGA configuration
---------------------------

A normal development load can program the ECP5 configuration SRAM through the
``US1`` FT231X/JTAG path. Hazard3-Doom supports workflows using tools such as
``fujprog``, ``openFPGALoader``, OpenOCD/SVF, and the browser WebUSB FPGA
flasher.

A configuration-SRAM load is **volatile**. It is excellent for development and
does not, by itself, replace the persistent image in SPI flash. Removing power
causes the FPGA to lose that configuration.

Persistent SPI flash
--------------------

The onboard SPI flash stores FPGA configuration data that can be loaded at
power-up. Programming this flash changes what the board can configure without a
development PC.

Do not confuse a persistent FPGA image with the Hazard3 boot monitor ELF. A
complete Hazard3-Doom bitstream can contain a resident monitor preload in ECP5
block RAM; the monitor then appears after the FPGA configures from either a
volatile or persistent copy of that bitstream.

``US1`` and ``US2`` have different roles
----------------------------------------

The upstream ULX3S manual defines:

``US1``
   Main USB connector for power, FT231X communication, and the common FPGA/JTAG
   programming path.

``US2``
   Auxiliary USB connector wired to FPGA pins. It can host user USB logic and is
   also used by the optional/persistent ULX3S DFU bootloader flow.

The normal Hazard3-Doom WebUSB flasher uses ``US1``. The DFU bootloader is a
separate mechanism and should not be replaced merely to install a new Doom FPGA
image.

DFU user-image flow
-------------------

When the supported ULX3S DFU bootloader is already present, ``US2`` can program
the normal user image in SPI flash. The project bootloader documentation uses
DFU alternate setting 0 for the user image and keeps bootloader replacement as
an advanced recovery/development operation.

See :doc:`../../user-guide/bootloader` for the exact entry procedure and
:doc:`../../getting-started/programming` for the normal programming choices.

Runtime firmware loading
------------------------

OpenOCD/GDB can load or replace monitor/software state in a running FPGA without
rewriting the FPGA configuration flash. That is useful when debugging firmware,
but the change is volatile and disappears when the board is reconfigured or
powered down.

A practical rule is:

.. code-block:: text

   FPGA SRAM load      -> volatile hardware configuration
   SPI flash write     -> persistent FPGA configuration
   OpenOCD ELF load    -> volatile processor/monitor software state
   micro-SD files      -> persistent removable Doom/application data
