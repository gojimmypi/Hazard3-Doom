Video, micro-SD, and Runtime Storage
====================================

GPDI video
----------

ULX3S provides a GPDI connector for digital display output. Hazard3-Doom uses it
for the project's indexed framebuffer/video pipeline rather than requiring Doom
to render a full RGB framebuffer in software.

The primary Doom mode is 320x200 indexed color with hardware palette conversion
for display output. The ULX3S 85F build can support additional project video
modes, while the compact 12F target intentionally stays with the 320x200 path.

See :doc:`../../architecture/video` for the framebuffer/palette architecture and
:doc:`../../user-guide/web-serial` for Screen Snip, which captures the indexed
source over UART rather than sampling the physical TMDS signal.

HDMI displays and example enclosure
-----------------------------------

The GPDI output can be used with an HDMI display through the appropriate
GPDI-to-HDMI connection. The Hazard3-Doom video path is not tied to a specific
monitor: the Elecrow seven-inch display is one convenient hardware example, but
other HDMI displays can be used as well.

A 3D-printable enclosure is available for a compact ULX3S demonstration system
built around the Elecrow seven-inch 1024x600 IPS HDMI display. It mounts the
ULX3S and display together while retaining access to board controls, status
LEDs, GPIO/JTAG headers, display controls, and cable routing. The enclosure also
includes options for a stand, development feet, an OLED frame, and a small
internal fan.

The enclosure is mechanically designed for that Elecrow panel; it is not a
requirement for Hazard3-Doom and does not limit the FPGA video output to that
display. For design files, printing notes, assembly details, and compatibility
notes, see:

* `ULX3S Elecrow 7 inch HDMI Display Enclosure
  <https://github.com/gojimmypi/ulx3s-elecrow-7inch-hdmi-enclosure>`_
* `Crowd Supply: New Enclosure & Upcoming Campaign News
  <https://www.crowdsupply.com/radiona/ulx3s/updates/new-enclosure-and-upcoming-campaign-news>`_

.. warning::

   The enclosure documentation includes connection-specific cautions. In
   particular, do not use the enclosure's external HDMI input at the same time
   as the internally connected ULX3S video path, and do not connect the
   display's USB touch and USB power inputs simultaneously. Review the enclosure
   repository before assembly.

micro-SD storage
----------------

The micro-SD socket gives ULX3S a removable nonvolatile storage path. In
Hazard3-Doom it supports the standalone cold-boot flow for ``DOOM.IMG`` and
``DOOM.WAD``.

The SD card has a different job from both FPGA SPI flash and SDRAM:

* SPI flash stores persistent FPGA configuration.
* ECP5 EBR can hold the resident monitor preload after configuration.
* SDR SDRAM is volatile working memory for the running system.
* micro-SD stores removable files that the monitor can mount and load.

A standalone ULX3S Doom boot therefore crosses several layers:

.. code-block:: text

   SPI flash -> ECP5 configuration
       -> resident monitor in EBR
       -> SDRAM initialization
       -> micro-SD/FAT file reads
       -> DOOM.IMG + DOOM.WAD
       -> execution from the Hazard3 memory map

Shared SD ownership with ESP32
------------------------------

The ULX3S micro-SD signals are shared between the FPGA and ESP32. When Hazard3
owns the SD bus, the ESP32 side must not drive those lines. The current project
integration expects ESP32 GPIO14, GPIO15, GPIO2, and GPIO13 to remain high
impedance while the FPGA performs SD transactions.

.. important::

   SD ownership is an electrical rule, not merely a software lock. Two devices
   actively driving the same shared line can corrupt transfers and can create
   electrical contention.

See :doc:`../../user-guide/sd-card` for the current boot procedure and
:doc:`../../user-guide/sao` for the project's separate FPGA/ESP32 coordination
work.

Audio and display expansion
---------------------------

The upstream board also includes a 3.5 mm audio connector and a small display
header. These are useful ULX3S resources, but they are not required for the
normal Hazard3-Doom video/storage path. Their presence should not be confused
with a claim that the current Doom SoC drives every board peripheral.
