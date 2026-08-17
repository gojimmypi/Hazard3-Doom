micro-SD Cold Boot
==================

The SD boot path allows a programmed ULX3S to recover from complete power loss and launch Doom without a connected development PC.

Card contents
-------------

Place these files in the root directory of a FAT-formatted micro-SD card:

.. code-block:: text

   DOOM.H3D
   DOOM.WAD

``DOOM.WAD`` is the canonical IWAD filename used by the current cold-boot flow.

Filesystem support
------------------

The monitor supports FAT16/FAT32 root-directory files with 8.3 names. Fragmented files are supported.

Cold-boot sequence
------------------

#. The ECP5 loads its configuration from onboard SPI flash.
#. The lower internal EBR contains the resident monitor initialization image.
#. Hazard3 begins at its reset/monitor entry point.
#. SDRAM is initialized.
#. The monitor initializes the SD card and mounts FAT.
#. ``DOOM.H3D`` is loaded into SDRAM and validated.
#. ``DOOM.WAD`` is located and loaded into its reserved region.
#. The monitor launches Doom.

Monitor diagnostics
-------------------

Use ``c`` to print the current SD/FAT status and counters. Use ``b`` to retry the SD boot path manually.

A healthy status report includes information such as:

.. code-block:: text

   sd_initialized=YES
   type=SDHC/SDXC
   fat_type=FAT32
   mounted=YES
   wad=DOOM.WAD

Shared ESP32/FPGA SD pins
-------------------------

On ULX3S, the micro-SD socket is also connected to ESP32 GPIOs. When Hazard3 owns the SD card, the ESP32 firmware must leave GPIO 14, 15, 2, and 13 high-impedance so it does not contend with the FPGA SD interface.

.. important::

   SD ownership is an electrical issue, not just a software mutex. Both devices must never actively drive the shared bus at the same time.

See :doc:`sao` for the separate FPGA/ESP32 shared-access mechanism used for SAO traffic.
