Repository Layout and Ownership
===============================

Hazard3-Doom intentionally separates application ownership from reusable
Hazard3 processor/debug RTL and from the ULX3S-specific SoC integration built
around it.

Repository tree
---------------

.. code-block:: text

   Hazard3-Doom/
   |-- benchmarks/coremark/
   |-- bin/
   |-- doom/
   |-- examples/esp32-sao-shared/
   |-- openocd/
   |-- scripts/
   |-- src/
   |-- tests/
   |-- third_party/Hazard3/
   |-- third_party/doomgeneric/
   |-- VisualGDB/
   |-- wads/
   `-- build/                  generated, ignored

Three ownership layers
----------------------

It is useful to split the hardware ownership into three layers rather than
calling everything under the Hazard3 submodule simply "Hazard3 hardware":

.. list-table::
   :header-rows: 1
   :widths: 32 24 44

   * - Item
     - Primary owner/origin
     - Location / notes
   * - Hazard3 CPU pipeline and reusable processor RTL
     - Wren6991/Hazard3 upstream
     - ``third_party/Hazard3/hdl/``; F/X/M pipeline, decoder, CSR, ALU, register file, CPU wrappers, and optional architectural features.
   * - Hazard3 Debug Module and DTM
     - Wren6991/Hazard3 upstream
     - ``third_party/Hazard3/hdl/debug/``; includes the ECP5 JTAGG transport used on ULX3S.
   * - Minimal example-SoC foundation
     - Wren6991/Hazard3 upstream
     - CPU/debug/RAM/UART/timer integration that the fork extends.
   * - ULX3S/ULX4M SoC and board extensions
     - ulx3s/Hazard3 fork / project integration
     - Additional SDRAM, video, SD SPI, SAO/ESP32, resident-monitor preload, synthesis, and board wiring under ``third_party/Hazard3/example_soc/``.
   * - Resident monitor and loaders
     - Hazard3-Doom
     - ``src/`` and ``doom/``.
   * - Complete board/application build wrappers
     - Hazard3-Doom
     - ``scripts/build-*-doom.sh`` and related helpers.
   * - DoomGeneric upstream/forked application source
     - DoomGeneric
     - ``third_party/doomgeneric/``.

Hazard3 source snapshot
-----------------------

The processor documentation is anchored to the project Hazard3 snapshot:

``736a74459b3f740c47803f20a62d820fcacbe5c3``

* `Pinned ULX3S Hazard3 source <https://github.com/ulx3s/Hazard3/tree/736a74459b3f740c47803f20a62d820fcacbe5c3>`_
* `Current upstream Hazard3 stable <https://github.com/Wren6991/Hazard3/tree/stable>`_
* :doc:`hazard3/project-integration` - detailed upstream-versus-project comparison.

The pinned commit is the source of truth for the project build. Current
upstream is the reference for what Hazard3 maintains today, but newer upstream
features do not become project features until the submodule is deliberately
updated.

How to classify a change
------------------------

A practical rule of thumb is:

Processor behavior
   ISA decode, pipeline hazards, CSR semantics, trap behavior, generic debug,
   and reusable CPU wrapper fixes should normally be evaluated as upstream
   Hazard3 work.

Reusable but platform-specific SoC behavior
   SDRAM controllers, board clocking, ECP5 integration, and generalized
   peripherals may belong in the Hazard3 fork/example-SoC layer.

Application behavior
   Resident monitor commands, Doom loading, framebuffer policy, host tools,
   and end-user workflows belong in Hazard3-Doom.

Submodules
----------

The superproject pins exact Hazard3 and DoomGeneric commits. Always inspect
both the superproject branch and submodule commit before diagnosing a
regression. A branch name alone is not sufficient to reproduce the hardware.
