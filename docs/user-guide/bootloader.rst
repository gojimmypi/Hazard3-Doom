DFU Bootloader Operation and Recovery
=====================================

.. important::

   Replacing the board DFU bootloader is **highly unusual** and is **not** part
   of normal Hazard3-Doom installation, FPGA development, firmware loading, or
   Doom updates.

   In normal use, keep the existing bootloader and replace only the **user
   bitstream** in its normal DFU user-image area. Do not expose or write the
   bootloader flash area unless you are intentionally developing the bootloader
   itself or recovering a board whose persistent bootloader is missing,
   corrupted, or known to be incompatible with the board.

This page describes the board-level USB DFU bootloader used by ULX3S and
ULX4M-LD. It intentionally keeps ordinary DFU operation separate from the rare
bootloader replacement and recovery procedure.

Do not confuse these three components
--------------------------------------

Hazard3-Doom uses several pieces of software and FPGA configuration that can all
participate in startup, but they are not interchangeable:

``DFU bootloader``
   A persistent FPGA configuration and small firmware environment stored at the
   beginning of SPI flash. It provides USB DFU access and then transfers control
   to the user FPGA image. This is the component discussed on this page.

``FPGA user bitstream``
   The normal Hazard3-Doom FPGA image. Updating this image is routine and does
   **not** require replacing the DFU bootloader.

``Hazard3 boot monitor``
   The RISC-V monitor/firmware built by Hazard3-Doom, for example
   ``hazard3-boot-monitor.elf``. Loading or rebuilding the Hazard3 monitor does
   **not** mean that the board DFU bootloader must be replaced.

If the goal is to test or install a new Hazard3-Doom FPGA image, use the normal
programming procedures in :doc:`../getting-started/programming`. If the goal is
source-level firmware debugging, use :doc:`jtag-debugging`.

When bootloader replacement is actually appropriate
----------------------------------------------------

Replacing the bootloader should be treated as an advanced maintenance or
recovery operation. Typical reasons are limited to:

* the persistent DFU bootloader no longer enumerates and has been diagnosed as
  missing or corrupted;
* a board revision requires a deliberate bootloader pin-mapping or hardware
  compatibility change; or
* you are actively developing and validating the bootloader itself.

The following are **not** reasons to replace the bootloader:

* installing or updating Hazard3-Doom;
* loading a newly built FPGA bitstream;
* changing Hazard3 or LiteDRAM RTL;
* updating ``hazard3-boot-monitor.elf``;
* loading Doom or an IWAD; or
* testing a new FPGA route in SRAM or in the normal user-bitstream flash area.

Normal bootloader operation
---------------------------

At power-up, the bootloader normally transfers control to the user FPGA image.
Holding the board-specific DFU-entry control instead keeps the bootloader active
so a host can program the user image through USB.

The bootloader USB device enumerates as VID:PID ``1d50:614b``. The normal user
bitstream is DFU alternate setting 0.

A normal user-image update therefore targets **alt 0**, not the bootloader
region.

ULX3S normal DFU operation
~~~~~~~~~~~~~~~~~~~~~~~~~~

The ULX3S bootloader provides USB DFU on connector ``US2``. It also provides the
ULX3S-specific ``US1`` passthrough behavior used for ESP32 programming. That
ESP32 passthrough behavior is specific to ULX3S and should not be assumed for
ULX4M-LD.

For the ULX3S bootloader described by ``bootloader/README.md``:

#. Remove or cycle board power as appropriate.
#. Hold ``BTN1`` or set DIP ``SW1`` ON.
#. Connect ``US2`` and wait for USB DFU enumeration.
#. Release the button after DFU is active if desired.

In bootloader mode, ULX3S LEDs 0 through 2 are expected to be on while LEDs 3
through 7 are off.

If the board does not power from ``US2`` because of its USB/RTC power state,
the upstream bootloader README documents two recovery options: also connect
``US1``, or hold ``BTN1`` and briefly press ``BTN0`` to power the board.

Confirm USB enumeration with:

.. code-block:: bash

   dfu-util -l

A normal user-bitstream transfer can use:

.. code-block:: bash

   dfu-util -a 0 -D blink.bit

or:

.. code-block:: bash

   openFPGALoader --dfu \
       --vid 0x1d50 --pid 0x614b --altsetting 0 \
       blink.bit

To leave DFU and start the stored user bitstream:

.. code-block:: bash

   dfu-util -a 0 -e

ULX4M-LD normal DFU operation
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The validated ULX4M-LD v0.0.3 bootloader uses a different physical button
mapping from ULX3S. PCB labels are one-based while the Verilog button vector is
zero-based, so use the PCB labels in the table below when operating the board.

.. list-table:: ULX4M-LD startup behavior
   :header-rows: 1
   :widths: 35 65

   * - Startup condition
     - Result
   * - No buttons
     - Boot the user bitstream beginning at flash address ``0x200000``.
   * - PCB ``BTN3``
     - Stay in ordinary DFU. Alt 0 through alt 4 are visible; alt 5 is hidden.
   * - PCB ``BTN2`` + ``BTN3``
     - Stay in bootloader-upgrade DFU. Alt 0 through alt 5 are visible.

.. warning::

   ``BTN2`` + ``BTN3`` is **not** the normal programming mode. It exposes alt 5,
   which contains the bootloader itself. For routine Hazard3-Doom FPGA updates,
   use PCB ``BTN3`` alone and program alt 0.

The validated ULX4M-LD DFU layout is:

.. list-table:: ULX4M-LD DFU alternate settings
   :header-rows: 1
   :widths: 10 35 55

   * - Alt
     - Flash range
     - Purpose
   * - 5
     - ``0x000000-0x1FFFFF``
     - Bootloader bitstream. Hidden during ordinary DFU operation.
   * - 4
     - ``0x800000-0xFFFFFF``
     - User data.
   * - 3
     - ``0x400000-0xFFFFFF``
     - User data.
   * - 2
     - ``0x360000-0x3FFFFF``
     - SaxonSoc U-Boot area.
   * - 1
     - ``0x340000-0x35FFFF``
     - SaxonSoc ``fw_jump`` area.
   * - 0
     - ``0x200000-0xFFFFFF``
     - Normal user bitstream area.

For a routine Hazard3-Doom user-bitstream update:

#. Remove power.
#. Hold PCB ``BTN3``.
#. Connect the ULX4M Micro-B USB cable/apply power.
#. Wait for ``1d50:614b`` to enumerate, then release ``BTN3``.
#. Program alt 0.

A validated command is:

.. code-block:: bash

   ./bin/openFPGALoader.exe --dfu \
       --vid 0x1d50 --pid 0x614b --altsetting 0 \
       ./build/fpga_ulx4m_ld.bit

To tell the bootloader to leave DFU and start the already stored user image:

.. code-block:: bash

   ./bin/dfu-util.exe -a 0 -e

The ``-e`` operation does not replace the bootloader and does not download a
new FPGA image. It requests the transition from the currently running DFU
bootloader to the user image already stored in flash.

Rare bootloader replacement and recovery
----------------------------------------

.. danger::

   Do not replace a working bootloader merely because a new Hazard3-Doom build
   is available. A bootloader update writes the first 2 MiB of flash, including
   the component that normally provides the easiest recovery path.

   A failed or mismatched bootloader write can leave JTAG recovery as the only
   practical way to regain DFU access.

The ULX4M-LD recovery procedure documented in
``bootloader/README_ULX4M_BOOTLOADER.md`` was validated on ULX4M-LD v0.0.3 with
an LFE5UM-85F FPGA and JTAG IDCODE ``0x01113043``. Do not use an image built for
a different FPGA density or an unverified board mapping.

Safe replacement sequence
~~~~~~~~~~~~~~~~~~~~~~~~~

The important rule is: **validate the replacement bootloader in FPGA SRAM
before writing the persistent bootloader flash region**.

A conservative replacement sequence is:

#. Build the intended bootloader for the exact board and FPGA.
#. Repack an SRAM-only test image without the persistent ``--bootaddr`` setting.
#. Load that image through JTAG and verify ordinary DFU operation.
#. Verify bootloader-upgrade mode separately.
#. Back up the existing alt-5 bootloader region before overwriting it.
#. Prepare an image that is exactly 2 MiB for alt 5.
#. Run a known-good bootloader from FPGA SRAM in upgrade mode.
#. Write the replacement to alt 5 while that SRAM copy is running.
#. Read alt 5 back before power-cycling.
#. Verify the readback byte-for-byte or by matching SHA256 hashes.
#. Only after successful readback, remove power and perform cold-boot tests.

This procedure deliberately avoids executing the flash-resident bootloader while
that same flash region is being replaced.

Back up ULX4M-LD alt 5
~~~~~~~~~~~~~~~~~~~~~~

When alt 5 has intentionally been exposed by the bootloader-upgrade mode, back
up the existing first 2 MiB before writing anything:

.. code-block:: bash

   ./bin/dfu-util.exe \
       -d 1d50:614b \
       -a 5 \
       -U bootloader-alt5-before-update.bin

Verify the backup size and record a hash:

.. code-block:: bash

   stat -c '%n: %s bytes' bootloader-alt5-before-update.bin
   sha256sum bootloader-alt5-before-update.bin

The expected size is exactly ``2097152`` bytes.

Write and verify a replacement
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

With a known-good SRAM bootloader still running in the intentional
bootloader-upgrade mode, write an exact 2 MiB image to alt 5:

.. code-block:: bash

   ./bin/dfu-util.exe \
       -d 1d50:614b \
       -a 5 \
       -D bootloader-alt5-2m.img

Do **not** power-cycle immediately. Read the region back first:

.. code-block:: bash

   ./bin/dfu-util.exe \
       -d 1d50:614b \
       -a 5 \
       -U bootloader-alt5-after-update.bin

Then verify both files are exactly 2 MiB and have identical hashes:

.. code-block:: bash

   stat -c '%n: %s bytes' \
       bootloader-alt5-2m.img \
       bootloader-alt5-after-update.bin

   sha256sum \
       bootloader-alt5-2m.img \
       bootloader-alt5-after-update.bin

Do not cold-boot the replacement if the sizes or hashes differ.

ULX4M-LD cold-boot verification
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

After a verified alt-5 readback, remove all power so the SRAM-loaded test image
is lost. Then verify all three persistent startup paths:

#. No buttons: the normal user bitstream starts.
#. PCB ``BTN3``: ordinary DFU starts and alt 5 remains hidden.
#. PCB ``BTN2`` + ``BTN3``: upgrade DFU starts and alt 5 is visible.

Only after all three tests pass should the bootloader replacement be considered
complete.

JTAG recovery when persistent DFU is unavailable
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

If the persistent bootloader does not enumerate as ``1d50:614b``, the validated
ULX4M-LD recovery path uses Tigard/JTAG to load an emergency bootloader into
FPGA SRAM. The bootloader source provides ``EMERGENCY_RESTORE2`` to force both
"stay in DFU" and bootloader write-enable behavior so alt 5 can be restored.

The recovery chain is:

.. code-block:: text

   Tigard JTAG
       -> emergency bootloader in FPGA SRAM
       -> USB DFU 1d50:614b
       -> alt 5 access
       -> restore exactly first 2 MiB
       -> read back exactly first 2 MiB
       -> SHA256 match
       -> cold boot from SPI flash

For the exact ULX4M-LD build commands, SRAM repacking procedure, button remapper,
pin mapping, and emergency build details, use the repository source document
``bootloader/README_ULX4M_BOOTLOADER.md``. Those steps are intentionally kept
out of the normal Hazard3-Doom programming path because they are board recovery
and bootloader-development procedures, not routine application programming.

ULX3S bootloader write protection note
--------------------------------------

The upstream ULX3S bootloader can write-protect the first 2 MiB on supported
16 MiB ISSI IS25LP128 and Winbond W25Q128 flash devices. Protection behavior is
flash-vendor-specific. The upstream README also warns that some
``openFPGALoader`` versions can remove non-OTP write protection while writing
flash.

Treat any ULX3S bootloader-region update as a separate maintenance operation.
Do not use persistent-flash commands that overwrite the first 2 MiB merely to
install a new Hazard3-Doom user image.

Source documentation
--------------------

The implementation and recovery details summarized here come from the bootloader
source documentation included with the Hazard3-Doom tree:

* ``bootloader/README.md`` - ULX3S DFU bootloader operation and flash-protection
  notes.
* ``bootloader/README_ULX4M_BOOTLOADER.md`` - validated ULX4M-LD build, SRAM
  test, backup, recovery, installation, readback, and cold-boot procedure.
