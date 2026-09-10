Hardware Guides
===============

Hazard3-Doom is designed to be explored from software down to the board. These
pages describe the physical FPGA platforms, the devices around the FPGA, and
how those devices become usable resources in the Hazard3-Doom system.

The hardware guides complement the original board documentation. They are not
manufacturer manuals and they do not replace schematics, BOMs, datasheets, or
board-revision notes. Their purpose is different: connect the physical hardware
to the Verilog, constraints, memory controllers, firmware, and debugging tools
used by this project.

.. toctree::
   :maxdepth: 2

   ulx3s/index
   ulx4m/index

Why a hardware guide?
---------------------

A board name alone hides several important layers. A useful FPGA design must
know which FPGA package is fitted, which memory device is populated, which pin
carries each signal, which I/O standard is required, where clocks come from,
and which interfaces are actually routed to a connector. Software then adds a
second set of questions: which controller owns that hardware, where it appears
in the address map, and what has been validated on real boards.

The guides keep those layers visible. When a public board description, an
upstream schematic, and a populated board disagree, the difference is recorded
rather than silently choosing one source.
