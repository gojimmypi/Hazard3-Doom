Hazard3-Doom
============

**Doom running on the Hazard3 RISC-V CPU in an ECP5 FPGA, with HDMI video, UART/JTAG debugging, and ULX3S/ULX4M board support.**

Hazard3-Doom combines a resident monitor, a loadable DoomGeneric application,
FPGA board builds, host-side upload tools, and hardware/software integration
for the ULX3S and ULX4M families.

.. note::

   These pages track the active ``develop`` branch. Features that are still
   evolving are called out explicitly. The detailed processor architecture
   pages are additionally anchored to the exact Hazard3 source snapshot named
   in :doc:`architecture/hazard3/index`.

Start here
----------

* :doc:`about/index` - understand what the project is, what it teaches, and why ULX4M is useful for modular prototyping.
* :doc:`getting-started/quick-start` - get a board running with the minimum number of steps.
* :doc:`getting-started/build` - build the FPGA, resident monitor, and Doom image.
* :doc:`reference/timing-sweeps` - run local/GitHub ECP5 seed sweeps and interpret live timing results.
* :doc:`user-guide/web-flasher` - program ULX3S FPGA SRAM directly from Chrome/Edge with WebUSB.
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

* `Hazard3-Doom repository <https://github.com/gojimmypi/Hazard3-Doom>`_
* `ULX3S Hazard3 hardware fork <https://github.com/ulx3s/Hazard3>`_
* `Hazard3 upstream <https://github.com/Wren6991/Hazard3>`_
* `DoomGeneric upstream <https://github.com/ozkl/doomgeneric>`_
