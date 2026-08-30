About Hazard3-Doom
==================

Hazard3-Doom is an open FPGA hardware/software project built around the
Hazard3 RISC-V processor and Lattice ECP5 FPGAs. It brings together a soft CPU,
memory controllers, a resident monitor, external-memory applications, HDMI
video, micro-SD storage, serial and JTAG debugging, and board-level I/O on the
ULX3S and ULX4M families.

Doom is the most visible application, but it is also a useful system workload.
Running it requires much more than a CPU core: executable loading, a working
memory map, sustained external-memory access, timers, input, storage, video,
and enough software infrastructure to keep a substantial C application
running. That makes the project useful for studying the complete path from RTL
to an interactive program.

What you can learn
------------------

Hazard3-Doom can be approached at several levels. A learner can begin by
loading a known bitstream and using the monitor, then progressively rebuild or
modify the layers underneath it.

.. list-table::
   :header-rows: 1
   :widths: 27 73

   * - Area
     - Example topics
   * - RISC-V processor design
     - Hazard3's pipeline, ISA configuration, CSRs, traps, interrupts, branch behavior, and debug support.
   * - SoC integration
     - AHB5/APB interconnect, address decoding, memory maps, timers, UARTs, and memory-mapped peripherals.
   * - Memory systems
     - Internal EBR SRAM, external SDR SDRAM, DDR3, memory controllers, latency, bandwidth, initialization, and timing tradeoffs.
   * - FPGA implementation
     - Yosys synthesis, nextpnr placement/routing, constraints, seed sweeps, timing closure, and resource tradeoffs on ECP5 devices.
   * - Embedded software
     - Startup code, linker maps, resident firmware, executable loading, heap placement, diagnostics, and recovery paths.
   * - Graphics and I/O
     - Indexed framebuffers, HDMI scanout, micro-SD storage, serial protocols, I2C/SAO devices, and shared board resources.
   * - Debugging
     - UART diagnostics, JTAG, OpenOCD, GDB, and correlating software failures with FPGA and memory behavior.
   * - Open engineering
     - Reproducible builds, submodule pinning, upstream versus project-local changes, licensing, documentation, and regression testing.

The processor-specific walkthrough begins at :doc:`../architecture/hazard3/index`.
The board and memory differences are summarized in
:doc:`../reference/board-profiles`.

Why Doom?
---------

A blinking LED or small bare-metal test can prove that one block works. Doom
forces many blocks to work together for a long time. It exercises instruction
execution, large data structures, external memory, file loading, framebuffer
updates, timing, and user interaction while producing a result that is easy to
observe.

This makes failures educational as well. A corrupted texture, slow frame rate,
boot failure, memory exception, or routing-timing regression can lead directly
to a lesson about a specific part of the computer system.

Beyond the classroom
--------------------

The project is also useful as an engineering and prototyping platform. The Doom
application can be treated as a demanding reference workload while the same
FPGA/SoC ideas are adapted to other software or custom RTL. Possible uses
include:

* evaluating a RISC-V soft CPU beside application-specific FPGA logic;
* prototyping custom peripherals, protocol bridges, or deterministic control logic;
* experimenting with memory architectures and hardware/software partitioning;
* building demonstrators around video, storage, sensors, cameras, or networking;
* evaluating an open FPGA tool flow before committing to a custom board; and
* using a modular FPGA as part of a proof-of-concept embedded product.

Hazard3-Doom itself should be considered a development and educational project,
not a certified production reference design. Product work should include the
normal review of timing closure, electrical requirements, reliability,
security, component availability, manufacturing test, and the licenses of each
hardware and software component. Doom game data also has separate distribution
rights from the open-source engine and FPGA project.

ULX4M and the Compute Module carrier ecosystem
----------------------------------------------

The ULX4M is particularly interesting for prototyping because it is a modular
FPGA system-on-module rather than an all-in-one development board. The ULX4M
hardware project describes it as compatible with the Raspberry Pi Compute
Module 4 (CM4) carrier-board pinout, allowing the FPGA module to be used with
CM4-style base boards or with a purpose-built carrier.

That modular split is useful in both teaching and product exploration: the FPGA
and memory remain on the ULX4M while the carrier can provide the connectors,
power, cameras, displays, networking, storage, or other application-specific
I/O. A team can therefore experiment with several carrier configurations before
designing a smaller custom carrier containing only the interfaces the final
application needs.

The ULX4M project has reported testing with several CM4-style carrier products,
including the Raspberry Pi Compute Module I/O board, Waveshare boards, Piunora,
and the TOFU carrier. Treat those reports as compatibility examples rather than
a guarantee for every board revision or every interface. Check the carrier
schematic, ULX4M revision, FPGA pin constraints, voltage requirements, and the
RTL that actually implements each interface before connecting hardware.

.. important::

   CM4 pin compatibility does **not** mean that ULX4M is a Raspberry Pi or that
   Raspberry Pi software runs on it. The shared carrier form factor is an
   electrical/mechanical integration opportunity; the ULX4M contains an ECP5
   FPGA and runs the logic implemented in its bitstream.

For Hazard3-Doom specifically, the current ULX4M-LS path uses SDR SDRAM while
the ULX4M-LD path uses DDR3 through LiteDRAM. This makes the two variants useful
for comparing not only carrier-board integration but also substantially
different memory-controller architectures. See :doc:`../reference/board-profiles`
for the current build and timing status.

External ULX4M resources
------------------------

* `ULX4M documentation <https://github.com/intergalaktik/ulx4m-documentation>`_
* `ULX4M hardware repository <https://github.com/intergalaktik/ulx4m>`_
* `ULX4M project and carrier compatibility notes <https://www.crowdsupply.com/intergalaktik/ulx4m/updates/pre-launch-progress>`_
* `Raspberry Pi Compute Module documentation <https://www.raspberrypi.com/documentation/computers/compute-module.html>`_
* `ULX4M Open Source Hardware certification <https://certification.oshwa.org/hr000013.html>`_
