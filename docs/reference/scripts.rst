Script Reference
================

Build
-----

``scripts/build-ulx3s-doom.sh``
   Build the complete ULX3S FPGA + monitor + Doom target.

``scripts/build-ulx4m-ld-doom.sh``
   Build the complete ULX4M-LD target.

``scripts/build.sh``
   Build the resident monitor firmware.

``doom/build-doom-image.sh``
   Build and package the linked Doom application.

Setup
-----

``scripts/setup-submodules.sh``
   Synchronize and initialize the recursive submodule tree.

``scripts/setup-doomgeneric.sh``
   Compatibility helper for DoomGeneric setup.

Debug/load
----------

``scripts/load-firmware.sh``
   Load the resident monitor ELF through a running OpenOCD GDB server.

``scripts/hazard3-debug.gdb``
   GDB startup helper for the Hazard3 monitor/debug target.

Host upload
-----------

``doom/upload-doom-image.py``
   Send a packaged ``.h3d`` image to the resident monitor.

``doom/upload-wad.py``
   Send an IWAD and optionally launch Doom.

.. note::

   Script names and options evolve faster than the architecture pages. Treat ``--help`` and the checked-out script as authoritative when this reference disagrees with a newer branch.
