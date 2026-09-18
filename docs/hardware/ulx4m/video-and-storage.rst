Video and Removable Storage
===========================

ULX4M exposes both display and removable-storage connections, but the physical
connector is only the first layer. Hazard3-Doom still needs FPGA logic,
constraints, clocks, and software to make those signals useful.

GPDI / HDMI-style video
-----------------------

Hazard3-Doom keeps Doom's native indexed framebuffer and implements video in the
FPGA. The current standard path renders 320x200 indexed pixels and scales them
to a 1024x600 output. Palette conversion and scanout happen in hardware rather
than requiring Doom to render a large RGB framebuffer.

The ULX4M wrappers use a dedicated video PLL with a 50 MHz pixel clock and a
250 MHz serializer clock. Keeping video on its own clock tree prevents a video
clock change from automatically becoming a CPU or external-memory clock change.

See :doc:`../../architecture/video` for the software-to-display data path.

Published ULX4M hardware material describes true/fake differential GPDI output
options depending on revision and signal group. The Hazard3-Doom LS wrapper
explicitly drives positive and complementary LVCMOS pins for its selected GPDI
mapping. The LD design uses the constraints and top-level mapping supplied for
that target. Always treat the matching LPF and wrapper as the implementation
source of truth for a specific build.

micro-SD hardware
-----------------

Public ULX4M documentation routes the SD-card interface through the
CM4-compatible/HAT pin environment. Some upstream documentation describes those
signals as shareable with an ESP32 on an attached carrier/HAT arrangement.
The ULX4M module itself should not therefore be described as containing an
on-board ESP32.

Hazard3-Doom's ULX4M-LD top level currently exposes:

.. code-block:: text

   sd_clk
   sd_mosi
   sd_miso
   sd_csn
   sd_pwr_on

``sd_pwr_on`` is driven active while the bitstream runs. The SoC enables its
SD SPI block for ULX4M-LD, so the project has the correct architectural path for
software-driven card initialization. Hardware bring-up status is documented
separately from the board capability because a routed socket does not guarantee
that a particular FPGA driver revision has been validated.

See :doc:`../../user-guide/sd-card` for the current software/boot procedure and
known target-specific status.

SD versus external DRAM
-----------------------

The SD card and DDR3 solve completely different storage problems:

* SPI flash configures the FPGA at startup.
* The resident monitor lives in FPGA block RAM after configuration.
* DDR3/SDRAM is volatile working memory for executable code, heap, IWAD data,
  and runtime buffers.
* micro-SD is removable, nonvolatile file storage used for standalone loading.

A standalone Doom boot therefore crosses several hardware boundaries:

.. code-block:: text

   SPI flash -> FPGA configuration
       -> resident monitor in EBR
       -> external DRAM initialization
       -> micro-SD/FAT file reads
       -> DOOM.IMG + DOOM.WAD in external memory
       -> execution on Hazard3

Keeping those roles separate makes boot failures much easier to diagnose.
