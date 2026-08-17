Programming and Persistent Boot
===============================

There are two different programming goals:

Temporary FPGA load
-------------------

A normal volatile FPGA programming command is ideal while testing a new bitstream. It configures the ECP5 immediately but is lost when power is removed.

Persistent FPGA configuration
-----------------------------

For a standalone installation, write the validated FPGA bitstream to the ULX3S configuration SPI flash. On the next power-up the ECP5 configures itself from flash.

The intended standalone sequence is:

#. ECP5 configures from SPI flash.
#. Block RAM is initialized with the resident Hazard3 monitor image.
#. Hazard3 starts without a host PC.
#. The monitor initializes SDRAM and the micro-SD interface.
#. ``DOOM.H3D`` and ``DOOM.WAD`` are read from the SD card.
#. Doom is launched on HDMI.

.. warning::

   Validate a bitstream with a temporary load before writing it persistently. A broken persistent image is recoverable, but temporary testing is faster and safer during development.

See :doc:`../user-guide/sd-card` for the SD card contents and boot diagnostics.
