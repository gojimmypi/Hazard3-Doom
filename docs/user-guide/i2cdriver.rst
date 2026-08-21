I2CDriver HDMI Interface
========================

Hazard3-Doom includes an interactive I2C diagnostic interface inspired by
James Bowman's `I2CDriver <https://github.com/jamesbowman/i2cdriver>`_. The
original I2CDriver firmware is written in MyForth. Hazard3-Doom reuses the
project's existing FPGA SAO I2C controller for bus transactions and renders an
I2CDriver-style interface through the existing 320x200 indexed HDMI path.

The feature is implemented primarily by:

.. code-block:: text

   src/i2cdriver_hdmi.c
   src/i2cdriver_hdmi.h
   src/sao_console.c

The resident monitor must be rebuilt and loaded after these files change. No
FPGA resynthesis is required for software-only I2CDriver HDMI changes as long
as the running bitstream already provides the compatible SAO bridge and direct
indexed HDMI interface.

Starting the interface
----------------------

Return to the resident monitor first. If Doom is running, press ``Ctrl-X``.
Then enter either command:

.. code-block:: text

   i2c gui

or:

.. code-block:: text

   sao gui

A successful launch prints:

.. code-block:: text

   Starting I2CDriver HDMI...
   I2CDriver HDMI active. S scan, P probe, R read, W write, X recover, 1/4 speed, C clear, Q exit.

The HDMI display changes to the Hazard3 I2CDriver screen. While the interface
is active, UART keystrokes control the HDMI application rather than the normal
monitor command prompt.

Controls
--------

.. list-table::
   :header-rows: 1
   :widths: 10 22 68

   * - Key
     - Operation
     - Description
   * - ``S``
     - Scan
     - Probe normal 7-bit I2C addresses ``0x08`` through ``0x77``. Responding addresses are heated in the address map. The current implementation retains the logical probe trace for the last ACKing address.
   * - ``P``
     - Probe
     - Prompt for one 7-bit hexadecimal address and test whether it ACKs.
   * - ``R``
     - Register read
     - Prompt for a device address and 8-bit register, then perform a one-byte register read using a repeated START.
   * - ``W``
     - Register write
     - Prompt for a device address, 8-bit register, and one data byte, then write that register.
   * - ``X``
     - Recover
     - Invoke the FPGA SAO bridge bus-recovery operation. Use this when SDA/SCL or a target appears wedged.
   * - ``1``
     - 100 kHz
     - Select the normal 100-kHz I2C bus rate.
   * - ``4``
     - 400 kHz
     - Select the fast-mode setting. With a 50-MHz Hazard3 system clock, the integer divider produces approximately 403 kHz.
   * - ``C``
     - Clear
     - Clear the heatmap, transaction history, and logical trace. This does not reset an attached I2C device.
   * - ``Q``
     - Exit
     - Return UART control to the resident monitor and restore the SAO bus to 100 kHz.
   * - ``Ctrl-X``
     - Exit
     - Alternate exit key while the GUI is active.
   * - ``Esc``
     - Cancel/exit
     - Cancel an operand prompt. When no prompt is active, ``Esc`` exits the GUI.

Hexadecimal prompts
-------------------

``P``, ``R``, and ``W`` collect hexadecimal operands directly in the HDMI UI.
Do not type an ``0x`` prefix.

Probe address ``0x54``:

.. code-block:: text

   P
   54
   Enter

Read register ``0x00`` from device ``0x54``:

.. code-block:: text

   R
   5400
   Enter

Write value ``0x80`` to register ``0x04`` on device ``0x54``:

.. code-block:: text

   W
   540480
   Enter

While entering operands, Backspace/Delete edits the input, Enter executes a
complete command, and Esc cancels it.

.. warning::

   ``W`` changes the state of the attached device. Consult the target device's
   register documentation before writing. Reads can also have side effects on
   devices with read-to-clear or FIFO-style registers.

Address heatmap
---------------

The heatmap covers the complete 7-bit address space visually, but the normal
scan range is ``0x08`` through ``0x77``. Addresses outside that range are
reserved or otherwise unsuitable for the ordinary scan operation.

An address that ACKs is assigned maximum heat and then gradually fades. This
makes recently active devices conspicuous without permanently marking stale
responses.

A device outside the scan range can still be tested explicitly when the
underlying SAO probe API permits it. Do not assume that a device at a reserved
address will appear in ``S`` scan results.

Transaction log
---------------

The right-hand transaction log records recent GUI operations, including probe,
read, write, recovery, scan, and speed changes. The log is local diagnostic
state; ``C`` clears it without changing the attached device.

Logical trace
-------------

The lower HDMI panel shows SDA and SCL as a **logical transaction trace**.
This trace is synthesized from transactions initiated by Hazard3 through the
SAO bridge. It is useful for visualizing protocol structure, for example:

.. code-block:: text

   START
   address + WRITE     ACK
   register            ACK
   repeated START
   address + READ      ACK
   data                master NACK
   STOP

For ``S`` scan, the current implementation retains the probe trace for the
last address that ACKed. If one device responds at ``0x54``, the retained scan
trace represents START, address byte ``0xA8`` with ACK, and STOP.

The trace is **not an electrical capture of SDA/SCL edges**. The high-level
SAO API also reports an overall transaction result rather than the exact byte
phase that generated a NACK, so a failed multi-byte logical trace cannot always
identify the precise failing ACK position.

Passive capture status
----------------------

The original I2CDriver has a timing-sensitive passive capture implementation
in ``firmware/capture.fs``. Hazard3-Doom does not currently implement the
corresponding passive sniffer in software.

A true passive analyzer should be implemented as FPGA logic that samples SDA
and SCL independently of the Hazard3 CPU and places decoded events/timestamps
into a FIFO. The HDMI C interface can then render that captured data. Until
such a FIFO exists, the footer intentionally describes the display as
initiated traffic rather than passive capture.

Bus recovery
------------

``X`` calls the existing SAO bridge recovery operation rather than manually
bit-banging SDA/SCL from C. This keeps electrical timing and ownership inside
the FPGA bus controller.

Use recovery when a device was interrupted mid-transaction, SDA remains low,
or the bus no longer responds after hot-plugging. A healthy bus normally does
not require recovery.

HDMI presentation
-----------------

The interface renders a 320x200 indexed frame and uploads it to the inactive
internal EBR framebuffer using the direct HDMI register path. The software
selects the bank opposite the active internal framebuffer, then requests a
vertical-blank swap. This is the same double-buffering concept used by the
fast Doom presentation path.

Exiting the GUI does not reconstruct the frame that was visible before entry.
The last analyzer frame can remain on HDMI until Doom or another monitor video
operation presents a new frame. The UART monitor prompt is the authoritative
indication that the GUI has exited.

Web Serial screen snip
----------------------

The browser Web Serial console can capture the current I2CDriver HDMI screen
when the running GUI implements the screen-snip capability handshake. The GUI
intercepts the reserved control bytes before ordinary key/prompt processing, so
a screen request is not interpreted as an I2C command.

Current screen-snip source modes can be serialized as ``320x200`` or
``400x240``. Every ``H3SNIP1`` pixel is an 8-bit palette index. The 16 GUI
palette entries are transmitted first and the remaining palette entries are
zero.

See :doc:`web-serial` for the exact ``0x1c`` capability query, ``0x06`` ACK,
``0x1d`` capture request, payload sizes, RGB332 format, timeout behavior, and
PNG reconstruction.

Build and test workflow
-----------------------

For software-only changes to the I2CDriver HDMI implementation:

.. code-block:: bash

   ./scripts/build.sh
   ./scripts/load-firmware.sh ./build/hazard3-boot-monitor.elf

Before testing the GUI, confirm the ordinary SAO path:

.. code-block:: text

   sao info
   sao scan
   i2c gui

A useful validation sequence inside the GUI is:

.. code-block:: text

   S
   P 54 Enter
   4
   S
   1
   Q

Replace ``54`` with a known device on the attached SAO bus.

If ``i2c gui`` is reported as an unknown command, the board is running an older
resident monitor even if a newer monitor ELF exists on disk. Rebuild and load
``build/hazard3-boot-monitor.elf`` before troubleshooting the GUI itself.

Relationship to upstream I2CDriver
----------------------------------

This feature ports the useful interaction model rather than translating every
hardware-specific function from the original board. The Hazard3-Doom version
currently covers active-master scanning, probing, one-byte register reads and
writes, activity heat, transaction history, logical traces, bus recovery, and
100/400-kHz selection.

The original I2CDriver's board-specific analog measurements, switchable pull-up
resistor hardware, host binary protocol, and true passive capture are not
implicitly provided by this C interface.

I2CDriver is distributed under the BSD 3-Clause license. Preserve the project's
third-party attribution/license material when copying or redistributing code
derived from it.
