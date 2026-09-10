Hazard3-Doom
============

**Doom running on the Hazard3 RISC-V CPU in an ECP5 FPGA - and a hands-on playground for learning how processors, FPGA logic, memory, video, firmware, and software fit together.**

Hazard3-Doom is more than just Doom running on another FPGA board. It is an
educational hardware and software ecosystem built around the open-source
Hazard3 RISC-V processor and the ULX3S and ULX4M ECP5 FPGA families.


.. admonition:: The same Hazard3 CPU used in Raspberry Pi RP2350
   :class: important

   Hazard3 is not a one-off processor created for this project. Raspberry Pi's
   RP2350 microcontroller contains a pair of open-hardware Hazard3 RISC-V cores,
   selectable in place of its Arm Cortex-M33 pair, and RP2350 powers the
   Raspberry Pi Pico 2 family. Hazard3-Doom synthesizes that same open-source
   Hazard3 processor architecture into the ECP5 FPGA.

   The processor configuration is not identical: RP2350 and Hazard3-Doom enable
   different optional Hazard3 features and ISA extensions for their respective
   SoCs. The common CPU lineage and RTL make Hazard3-Doom a useful way to study
   the processor architecture in a system you can rebuild and modify.

   * `Raspberry Pi RP2350 <https://www.raspberrypi.com/products/rp2350/>`_
   * `RP2350 datasheet - Hazard3 processor <https://datasheets.raspberrypi.com/rp2350/rp2350-datasheet.pdf>`_
   * `Raspberry Pi Pico 2 <https://www.raspberrypi.com/products/raspberry-pi-pico-2/>`_
   * `Upstream Hazard3 RTL <https://github.com/Wren6991/Hazard3>`_

The project brings together C and Verilog examples, FPGA board designs, HDMI
video and framebuffer support, external memory controllers, SD card access,
UART and JTAG debugging, a resident boot monitor, host-side upload tools, and a
loadable DoomGeneric application.

There's also an I2C diagnostic tool, based on the `I2CDriver <https://i2cdriver.com/>`
by Excamera Labs. Leveraging the same code - there's also a bonus :doc:`Hackaday Supercon SAO feature <user-guide/sao>`.

You can use Hazard3-Doom simply to play Doom on a RISC-V soft CPU, or dig deeper
into the system to see how a complete FPGA-based computer is built. Explore
processor integration, memory interfaces, clocking and timing, video generation,
peripherals, boot and upload mechanisms, debugging tools, and the boundary
between hardware and software.

Whether you are experimenting with RISC-V, learning Verilog, exploring FPGA
development, or just curious about what it takes to make Doom run on hardware
you can inspect and modify from top to bottom, Hazard3-Doom is designed to give
you plenty to explore.

.. note::

   These pages describe the selected documentation version. Features that are
   still evolving are called out explicitly. The detailed processor
   architecture pages are additionally anchored to the exact Hazard3 source
   snapshot named in :doc:`architecture/hazard3/index`.

Start here
----------

* :doc:`about/index` - understand what the project is, what it teaches, and why ULX4M is useful for modular prototyping.
* :doc:`getting-started/quick-start` - get a board running with the minimum number of steps.
* :doc:`getting-started/build` - build the FPGA, resident monitor, and Doom image.
* :doc:`getting-started/tiny-tapeout-ulx3s` - build Tiny Tapeout projects for ULX3S ECP5 locally or in GitHub Actions.
* :doc:`hardware/ulx4m/index` - explore the ULX4M board itself: FPGA, clocks, SDR/DDR3, flash, video, SD, SerDes, pin constraints, and revisions.
* :doc:`reference/timing-sweeps` - run local/GitHub ECP5 seed sweeps and interpret live timing results.
* :doc:`user-guide/web-tool` - use the browser device tool for UART, FPGA programming, console firmware loading, H3D/IWAD upload, and screen snip.
* :doc:`user-guide/web-flasher` - detailed ULX3S FPGA SRAM programming with WebUSB.
* :doc:`user-guide/sd-card` - configure standalone cold boot from micro-SD.
* :doc:`user-guide/i2cdriver` - scan and inspect the SAO I2C bus on HDMI.
* :doc:`user-guide/jtag-debugging` - debug Hazard3 through OpenOCD/GDB or VisualGDB.
* :doc:`architecture/hazard3/index` - learn the Hazard3 RISC-V processor, pipeline, ISA configuration, CSRs, buses, and debug architecture.
* :doc:`architecture/system` - understand how the FPGA, monitor, SDRAM, HDMI, SD, SAO, and ESP32 pieces fit together.

.. toctree::
   :maxdepth: 2
   :caption: Project Overview

   about/index

.. toctree::
   :maxdepth: 2
   :caption: Getting Started

   getting-started/index

.. toctree::
   :maxdepth: 2
   :caption: Hardware

   hardware/index

.. toctree::
   :maxdepth: 2
   :caption: User Guide

   user-guide/index

.. toctree::
   :maxdepth: 2
   :caption: Architecture

   architecture/index

.. toctree::
   :maxdepth: 2
   :caption: Reference

   reference/index
   faq
   troubleshooting
   contributing

Project links
-------------

* `Hazard3-Doom repository <https://github.com/ulx3s/Hazard3-Doom>`_
* `ULX3S Hazard3 hardware fork on ulx-doom branch <https://github.com/ulx3s/Hazard3/tree/ulx-doom>`_
* `Hazard3 upstream <https://github.com/Wren6991/Hazard3>`_
* `Hazard3-libfpga fork on ulx-doom branch <https://github.com/ulx3s/Hazard3-libfpga/tree/ulx-doom>`_
* `Hazard3-libfpga upstream <https://github.com/Wren6991/libfpga>`_
* `DoomGeneric upstream <https://github.com/ozkl/doomgeneric>`_
* `ULX4M hardware sources <https://github.com/intergalaktik/ulx4m>`_
* `ULX4M hardware documentation <https://github.com/intergalaktik/ulx4m-documentation>`_
* `ULX4M Crowd Supply page <https://www.crowdsupply.com/intergalaktik/ulx4m>`_
* `ULX3S Pinout Tool <https://github.com/ulx3s/ulx3s-pinout>`_
* `ULX3S ulx3s.github.io <https://github.com/ulx3s/ulx3s.github.io>`_
* `Tiny Tapeout for the ULX3S <https://github.com/ulx3s/ttsky-verilog-template/tree/ulx3s>`_
* `ULX3S Tiny Tapeout GitHub Action <https://github.com/ulx3s/tt-gds-action/tree/experimental>`_
* `ULX3S Tiny Tapeout support tools <https://github.com/ulx3s/tt-support-tools/tree/experimental>`_
* `Verilog Language Extension for Visual Studio <https://github.com/gojimmypi/VerilogLanguageExtension>`_
