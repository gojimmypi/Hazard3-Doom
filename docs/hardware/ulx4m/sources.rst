Original Design Sources and Further Reading
===========================================

This guide intentionally keeps upstream design material visible. Hazard3-Doom
adds interpretation and project-specific integration notes; it does not take
ownership of the ULX4M hardware design.

Primary ULX4M sources
---------------------

* `ULX4M on Crowd Supply <https://www.crowdsupply.com/intergalaktik/ulx4m>`_ -
  project overview and promoted LS/LD feature tables.
* `Intergalaktik ULX4M hardware repository <https://github.com/intergalaktik/ulx4m>`_ -
  KiCad design sources, schematics, PCB files, BOM material, constraints, and
  revision history.
* `Intergalaktik ULX4M documentation <https://github.com/intergalaktik/ulx4m-documentation>`_ -
  separate LS/LD user-manual material and DFU bootloader notes.
* `ULX4M examples <https://github.com/lawrie/ulx4m_examples>`_ - upstream example
  designs useful when comparing basic board mappings.

ULX4M schematics
----------------

Local copies of the schematics for both ULX4M variants are included with
this documentation:

:download:`ULX4M-LD v003 schematic <ULX4M-LD-v003.pdf>`

:download:`ULX4M-LS v0.0.3 schematic <ULX4M-LS-v0.0.3.pdf>`

ULX4M-LD and ULX4M-LS are different board variants rather than revisions
of one another. Refer to the schematic matching the board being used.

The schematics are useful when tracing the FPGA, DDR3, power, JTAG, USB,
SD-card, video, and other board-level connections discussed throughout
this guide.

The original design files are maintained by the ULX4M project. Refer to
the upstream repository for source files and newer schematic revisions.

Hazard3-Doom sources
--------------------

The board-facing implementation used by this project lives mainly below:

.. code-block:: text

   third_party/Hazard3/example_soc/fpga/
   third_party/Hazard3/example_soc/synth/
   third_party/Hazard3/example_soc/soc/
   third_party/Hazard3/example_soc/third_party/LiteDRAM/
   bootloader/
   openocd/

The most important ULX4M files include the LS/LD top-level Verilog wrappers,
matching LPFs, ``ahb_litedram.v``, the generated LiteDRAM cores and editable YAML
profiles, the ULX4M makefiles, and the bootloader/OpenOCD configuration files.

How to use conflicting sources
------------------------------

Use a source hierarchy rather than assuming the newest-looking page is always
correct:

#. **The physical board in front of you** - markings and measured behavior win.
#. **Matching schematic/PCB/BOM revision** - best design-intent evidence.
#. **Matching LPF and project wrapper** - source of truth for what a specific
   Hazard3-Doom bitstream actually drives.
#. **Manufacturer datasheet for the fitted component** - electrical/timing
   limits and geometry.
#. **Campaign pages, READMEs, examples, and forum posts** - valuable context,
   but often revision-dependent.

When a discrepancy matters to a build, document it in the project instead of
silently resolving it locally. That keeps the next board owner from having to
repeat the same investigation.

Related Hazard3-Doom documentation
----------------------------------

* :doc:`../../reference/board-profiles` - supported clocks, memory profiles, and qualification checkpoints.
* :doc:`../../architecture/hazard3/memory-and-bus` - CPU/SoC view of SDR SDRAM and LiteDRAM.
* :doc:`../../architecture/video` - indexed framebuffer and GPDI video pipeline.
* :doc:`../../user-guide/bootloader` - normal DFU use versus rare bootloader recovery.
* :doc:`../../user-guide/sd-card` - SD boot flow and current target status.
* :doc:`../../user-guide/jtag-debugging` - OpenOCD/GDB and physical debug setup.
* :doc:`../../reference/timing-sweeps` - nextpnr sweep methodology and ULX4M-LD timing qualification.
