Pin Constraints, Schematics, and PCB Revisions
==============================================

A ULX3S signal becomes real hardware through several independent artifacts:

.. code-block:: text

   schematic net
        |
        v
   PCB trace / ECP5 package ball
        |
        v
   LPF LOCATE + I/O constraint
        |
        v
   top-level Verilog port
        |
        v
   Hazard3-Doom peripheral / software behavior

A correct Verilog signal name is not enough. The active LPF must map that port
to the package ball actually routed by the selected PCB revision.

Project constraint sources
--------------------------

The main Hazard3-Doom ULX3S board implementation is under the pinned Hazard3
submodule, including the ULX3S FPGA wrapper and synthesis constraints beneath:

.. code-block:: text

   third_party/Hazard3/example_soc/fpga/
   third_party/Hazard3/example_soc/synth/

The reusable Tiny Tapeout ULX3S flow has its own LPF under ``tt/fpga/ulx3s/``.
Do not update one constraint file assuming that every other ULX3S build consumes
it. See :doc:`../../getting-started/tiny-tapeout-ulx3s` for that separate flow.

Upstream revisioned schematics
------------------------------

The upstream ULX3S repository intentionally keeps generated schematic PDFs for
multiple board revisions, including 3.0.8 and several 3.1.x revisions. Use the
PDF that best matches the physical PCB instead of treating a generic
"ULX3S schematic" as timeless.

Useful upstream references include:

* `ULX3S v3.0.8 schematic <https://github.com/emard/ulx3s/blob/master/doc/schematics_v308.pdf>`_
* `ULX3S v3.1.4 schematic <https://github.com/emard/ulx3s/blob/master/doc/schematics_v314.pdf>`_
* `ULX3S v3.1.6 schematic <https://github.com/emard/ulx3s/blob/master/doc/schematics_v316.pdf>`_
* `ULX3S v3.1.7 schematic <https://github.com/emard/ulx3s/blob/master/doc/schematics_v317.pdf>`_

If local copies are committed beside this guide, keep the PCB revision in each
filename. A name such as ``ULX3S-v3.1.7-schematics.pdf`` is much less ambiguous
than ``ulx3s-schematics.pdf``.

Header-numbering caution
------------------------

Upstream constraint comments distinguish angled female headers from vertical
male headers when interpreting the two physical pins associated with a
``GP``/``GN`` pair. This can make a seemingly correct pin number wrong by one
physical position if connector orientation is ignored.

For Hazard3-Doom's tested external UART wiring, the relevant J1 locations are:

.. code-block:: text

   J1 pin 6  / GP0  -> Hazard3 TxD
   J1 pin 8  / GP1  -> Hazard3 RxD
   adjacent GND      -> serial ground

Use those as project-tested reference points, but still confirm the active LPF
when changing or diagnosing the design.

Revision discipline
-------------------

Before changing a ULX3S pin or board-specific interface:

#. Identify the PCB revision.
#. Identify the fitted ECP5 density/package.
#. Find the signal in the matching schematic.
#. Confirm the package ball and I/O bank.
#. Check the required voltage and I/O standard.
#. Identify the LPF consumed by the exact build wrapper.
#. Confirm the top-level Verilog port direction and width.
#. Check whether the signal is shared with ESP32, ADC, SD, or another device.
#. Build and review warnings/timing.
#. Validate the physical function on hardware.

This makes schematic/constraint differences visible rather than hiding them in
a locally copied pin number.
