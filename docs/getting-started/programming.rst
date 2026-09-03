Programming and Persistent Boot
===============================

There are two different programming goals: configure an FPGA for the current
test session, or arrange for the board bootloader/configuration flash to load a
validated image later. The ULX3S and ULX4M-LD paths are different and should
not be mixed.

ULX3S temporary FPGA load
-------------------------

A normal volatile ULX3S FPGA programming command is ideal while testing a new
bitstream. It configures the ECP5 immediately but is lost when power is removed.

For ULX3S, the browser-based :doc:`../user-guide/web-flasher` can perform this
temporary load directly from a ``.bit`` or compatible ``.svf`` file through
``US1``. The browser probes the physical ECP5 JTAG ID, verifies that a ``.bit``
file targets the same FPGA variant, executes the Project Trellis SRAM
programming sequence, and starts the new image immediately.

The WebUSB flasher does not modify persistent SPI flash. On Windows its direct
access to the FT231X requires the WinUSB driver. The same WinUSB binding has
also been verified with the project's ULX3S OpenOCD/GDB path, so a debug
workflow does not inherently require switching to libusbK. See the flasher
guide's driver compatibility matrix before changing the USB binding.

ULX3S persistent FPGA configuration
------------------------------------

For a standalone ULX3S installation, write the validated FPGA bitstream to the
configuration SPI flash. On the next power-up the ECP5 configures itself from
flash.

The intended standalone sequence is:

#. ECP5 configures from SPI flash.
#. Block RAM is initialized with the resident Hazard3 monitor image.
#. Hazard3 starts without a host PC.
#. The monitor initializes SDRAM and the micro-SD interface.
#. ``DOOM.H3D`` and ``DOOM.WAD`` are read from the SD card.
#. Doom is launched on HDMI.

ULX4M-LD DFU programming
------------------------

ULX4M-LD uses its Micro-B USB DFU bootloader for FPGA image storage. Windows
normally sees the DFU device as VID:PID ``1d50:614b`` with WinUSB. This USB
connection is separate from the external Tigard JTAG/UART debug adapter.

.. important::

   Normal Hazard3-Doom programming updates the **user bitstream**, not the DFU
   bootloader itself. Replacing the bootloader is highly unusual and should be
   reserved for bootloader development or recovery of a missing/corrupted
   bootloader. See :doc:`../user-guide/bootloader` for the separate bootloader
   operation and recovery procedure.

To enter the established DFU recovery/programming mode:

#. Remove power.
#. Hold the board recovery button used by your ULX4M revision.
#. Connect the ULX4M Micro-B USB cable.
#. Release the button after the DFU device enumerates.

The working programming command is:

.. code-block:: bash

   ./bin/openFPGALoader.exe --dfu \
       --vid 0x1d50 --pid 0x614b --altsetting 0 \
       ./build/fpga_ulx4m_ld.bit

DFU alternate setting 0 is the user-bitstream area; the ULX4M bootloader keeps
its own protected area below the user image region. During bring-up, a
successfully written image did not begin executing until the bootloader was
explicitly told to leave DFU. Use:

.. code-block:: bash

   ./bin/dfu-util.exe -a 0 -e

No FPGA data is downloaded or erased by this ``-e`` command. It requests the
bootloader transition that starts the already stored user image. The validated
sequence produced UART output immediately after ``-e``.

This distinction is important when debugging. If the ECP5 IDCODE is visible
through Tigard but the UART is silent and OpenOCD reports ``dtmcontrol is 0``,
check whether the board is still in DFU before changing JTAG wiring or Hazard3
RTL. See :doc:`../user-guide/jtag-debugging`.

Persistent cold boot is a separate qualification step from "DFU write +
execute now". Verify a candidate image with ``dfu-util -a 0 -e`` and the DDR
qualification tests first, then verify the board's normal power-up behavior.
Do not treat a successful DFU transfer alone as proof that cold boot has been
qualified.

ULX4M-LD qualified image checkpoint
-----------------------------------

The current hardware-qualified development checkpoint is the 40 MHz Hazard3 /
60 MHz LiteDRAM seed-2 route documented in
:doc:`../reference/board-profiles`. The locally tested bitstream SHA256 was:

.. code-block:: text

   294602982dfc4a9906961f2e8b6f43de925d8c11a7e5e6bb0f5e392965a868de

After programming and leaving DFU, use monitor ``s`` to confirm LiteDRAM is
ready and run ``q`` before treating a newly generated image as a DDR-qualified
replacement.

.. warning::

   Validate a bitstream before making it the normal standalone image. For
   ULX4M-LD this includes both static timing and real DDR tests; a nextpnr PASS
   alone is not sufficient.

See :doc:`../user-guide/sd-card` for SD card contents and boot diagnostics.
