ULX3S Hardware Guide
====================

**Architecture, board resources, interfaces, and their use by Hazard3-Doom.**

ULX3S is an open-hardware Lattice ECP5 development board designed for education,
research, and general FPGA work. It combines the FPGA with external SDR SDRAM,
SPI configuration flash, micro-SD storage, GPDI digital video, USB/JTAG/UART,
GPIO, buttons, LEDs, audio, an ADC, an RTC, and an optional/on-board ESP32 path.

That combination makes ULX3S especially useful for Hazard3-Doom: the board can
host the processor, external working memory, indexed video output, removable
storage, a resident monitor, and several independent programming/debug paths.

.. important::

   FPGA density and PCB revision are different identities. A board may use a
   12F, 25F, 45F, or 85F ECP5 while also having a separate PCB revision such as
   a 3.0.x or 3.1.x board. Always identify both before relying on a schematic,
   constraint file, or build target.

Hazard3-Doom currently provides complete build paths for ULX3S 85F and the
compact ULX3S 12F target. The hardware family supports other FPGA densities,
but that does not imply that the complete Doom SoC is qualified for every
possible ULX3S population.

.. toctree::
   :maxdepth: 2

   overview-and-variants
   fpga-and-clocking
   memory
   boot-and-flash
   video-and-storage
   interfaces
   pinout-and-revisions
   sources

A useful mental model
---------------------

.. code-block:: text

   +---------------------------------------------------------------+
   | ULX3S board                                                   |
   |                                                               |
   |  +-------------+       +------------------+                   |
   |  | SPI flash   |<----->| Lattice ECP5     |<----> GPDI video  |
   |  +-------------+       | FPGA             |<----> US1/JTAG    |
   |                        |                  |<----> J1/J2 GPIO   |
   |  +-------------+       | Hazard3 SoC      |<----> micro-SD    |
   |  | SDR SDRAM   |<----->| + controllers    |<----> ESP32       |
   |  +-------------+       +------------------+                   |
   |                               |                               |
   |                          EBR resident monitor                 |
   +---------------------------------------------------------------+

The guide separates three questions that are easy to mix together:

* what hardware exists on ULX3S;
* what the selected PCB revision and FPGA density actually route; and
* what Hazard3-Doom currently implements and has qualified on real hardware.
