Original Design Sources and Further Reading
===========================================

Hazard3-Doom adds project-specific interpretation around ULX3S; it does not
replace the board's original design documentation. Keep the upstream hardware
sources visible when tracing a signal or resolving a revision difference.

Primary ULX3S sources
---------------------

* `ULX3S hardware repository <https://github.com/emard/ulx3s>`_ - KiCad design
  sources, schematics, PCB files, BOM data, constraints, and revision history.
* `ULX3S upstream manual <https://github.com/emard/ulx3s/blob/master/doc/MANUAL.md>`_ -
  connector roles, power behavior, programming paths, ESP32 notes, and board
  revision details.
* `ULX3S on Crowd Supply <https://www.crowdsupply.com/radiona/ulx3s>`_ - project
  overview, production context, and commercial board information.
* `ULX3S Quick Start <https://github.com/ulx3s/quick-start>`_ - basic connection
  and programming notes.
* `ULX3S Pinout <https://github.com/ulx3s/ulx3s-pinout>`_ - generated visual
  pinout material useful alongside the schematics and LPF.

Schematic PDFs
--------------

The upstream repository keeps revisioned schematic PDFs rather than one eternal
board drawing. Examples include:

* `v3.0.8 <https://github.com/emard/ulx3s/blob/master/doc/schematics_v308.pdf>`_
* `v3.1.4 <https://github.com/emard/ulx3s/blob/master/doc/schematics_v314.pdf>`_
* `v3.1.5 <https://github.com/emard/ulx3s/blob/master/doc/schematics_v315.pdf>`_
* `v3.1.6 <https://github.com/emard/ulx3s/blob/master/doc/schematics_v316.pdf>`_
* `v3.1.7 <https://github.com/emard/ulx3s/blob/master/doc/schematics_v317.pdf>`_

When local copies are added under ``docs/hardware/ulx3s/``, retain the revision
in the filename and keep the upstream link beside the download reference. That
makes it clear that the repository copy is a snapshot for reproducible hardware
reference rather than a claim that every ULX3S uses that revision.

Hazard3-Doom sources
--------------------

The ULX3S implementation used by this project is concentrated in:

.. code-block:: text

   third_party/Hazard3/example_soc/fpga/
   third_party/Hazard3/example_soc/synth/
   third_party/Hazard3/example_soc/soc/
   scripts/
   bootloader/
   openocd/
   web/

Important concepts to trace there include the ULX3S top-level wrapper, LPF,
``ahb_sdram.v``, ``ulx3s_sdram_controller.v``, SD/SAO integration, resident
monitor preload, board build wrappers, OpenOCD configuration, and the WebUSB
flasher.

How to use conflicting sources
------------------------------

Use a source hierarchy instead of assuming that the newest-looking page is
correct for the board in front of you:

#. **Physical board markings and measured behavior**.
#. **Matching schematic/PCB/BOM revision**.
#. **Constraint file and top-level wrapper used by the exact build**.
#. **Manufacturer datasheet for the fitted component**.
#. **General README, campaign page, examples, and forum discussions**.

A difference between sources is useful information. It may identify a PCB
revision, alternate population, connector change, or stale software assumption.
Document the difference rather than silently choosing one source.

Related Hazard3-Doom documentation
----------------------------------

* :doc:`../../reference/board-profiles` - current ULX3S memory/clock profiles
  and timing checkpoints.
* :doc:`../../architecture/hazard3/memory-and-bus` - processor and SDRAM-controller view.
* :doc:`../../architecture/video` - indexed framebuffer and GPDI video path.
* :doc:`../../getting-started/programming` - normal host programming workflows.
* :doc:`../../user-guide/bootloader` - optional DFU path and recovery cautions.
* :doc:`../../user-guide/sd-card` - standalone SD boot and shared-bus requirements.
* :doc:`../../user-guide/web-flasher` - ULX3S ``US1`` WebUSB/JTAG programming.
* :doc:`../../user-guide/jtag-debugging` - OpenOCD/GDB debug path.
