Repository Layout and Ownership
===============================

Hazard3-Doom intentionally separates application ownership from reusable CPU/SoC hardware.

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

Ownership boundary
------------------

.. list-table::
   :header-rows: 1
   :widths: 35 25 40

   * - Item
     - Owner
     - Location
   * - Resident monitor and loaders
     - Hazard3-Doom
     - ``src/`` and ``doom/``
   * - Complete board/application build wrappers
     - Hazard3-Doom
     - ``scripts/build-*-doom.sh``
   * - Hazard3 CPU and reusable SoC hardware
     - Hazard3
     - ``third_party/Hazard3/``
   * - Board synthesis makefiles and constraints
     - Hazard3
     - ``third_party/Hazard3/example_soc/synth/``
   * - DoomGeneric upstream source
     - DoomGeneric
     - ``third_party/doomgeneric/``

Submodules
----------

The superproject pins exact Hazard3 and DoomGeneric commits. Always inspect both the superproject branch and submodule commit before diagnosing a regression.
