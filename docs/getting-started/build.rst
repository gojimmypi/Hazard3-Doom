Building Hazard3-Doom
=====================

Complete board builds
---------------------

The complete board wrappers are the safest way to build a matched FPGA,
monitor, and Doom image for one target.

ULX3S 85F, 64 MiB, 50 MHz:

.. code-block:: bash

   ./scripts/build-ulx3s-doom.sh

ULX3S 12F compact target, 32 MiB default, 40 MHz:

.. code-block:: bash

   ./scripts/build-ulx3s-12f-doom.sh

ULX4M-LD 85F, 64 MiB software map, 40 MHz Hazard3:

.. code-block:: bash

   ALLOW_TIMING_FAILURE=1 ./scripts/build-ulx4m-ld-doom.sh

The current ULX4M-LD route has known ``clk_sys`` and LiteDRAM timing misses.
``ALLOW_TIMING_FAILURE=1`` keeps those misses visible while allowing a
development bitstream to be generated; it does not make the constraints pass.
See :doc:`../reference/board-profiles` for the current validation results.

The 12F wrapper supports either a 32 MiB or 64 MiB SDRAM map, but defaults to
32 MiB. If the 64 MiB map is selected, keep the monitor and Doom image matched:

.. code-block:: bash

   HAZARD3_MEMORY_PROFILE=64m ./scripts/build-ulx3s-12f-doom.sh

The compact 12F target intentionally supports the 320x200 Doom/video path only.
After programming the 12F bitstream and starting OpenOCD, load its SDRAM-resident
monitor with:

.. code-block:: bash

   ./scripts/load-firmware-12f.sh

Resident monitor only
---------------------

The generic monitor builder defaults to the 64 MiB map at 50 MHz:

.. code-block:: bash

   ./scripts/build.sh

Typical outputs:

.. code-block:: text

   build/hazard3-boot-monitor.elf
   build/hazard3-boot-monitor.map
   build/hazard3-boot-monitor.bin

The complete board wrappers set the target-specific memory profile, system clock,
and linker script for you. For manual builds, the main controls are
``HAZARD3_MEMORY_PROFILE``, ``HAZARD3_SYS_CLK_HZ``, and
``HAZARD3_MONITOR_LINKER_SCRIPT``.

Linked Doom image only
----------------------

For the 64 MiB profile used by ULX3S 85F and ULX4M-LD 85F:

.. code-block:: bash

   HAZARD3_MEMORY_PROFILE=64m ./doom/build-doom-image.sh

For a 32 MiB 12F image:

.. code-block:: bash

   HAZARD3_MEMORY_PROFILE=32m \
   HAZARD3_DOOM_HDMI_RESOLUTION=320x200 \
       ./doom/build-doom-image.sh

Typical outputs:

.. code-block:: text

   build/doom-image/hazard3-doom.elf
   build/doom-image/hazard3-doom.map
   build/doom-image/hazard3-doom.bin
   build/doom-image/hazard3-doom.h3d

Testing another Hazard3 checkout
--------------------------------

You can test a hardware checkout without changing the pinned Hazard3-Doom
submodule pointer:

.. code-block:: bash

   HAZARD3_ROOT=/mnt/c/workspace/Hazard3 \
       ./scripts/build-ulx3s-doom.sh

Submodule preparation and verification
--------------------------------------

Initialize the build-required submodules:

.. code-block:: bash

   ./scripts/setup-submodules.sh

This initializes DoomGeneric and Hazard3 plus the nested Hazard3 ``scripts`` and
``example_soc/libfpga`` submodules. To initialize the complete recursive tree:

.. code-block:: bash

   HAZARD3_INIT_ALL_SUBMODULES=1 ./scripts/setup-submodules.sh

For source-history and submodule diagnostics, see :doc:`../reference/scripts`.
In particular, the Windows ``check_submodules.bat`` command validates the local
recorded gitlinks, while ``hazard3-doom-source-status.sh`` compares branches
across the related GitHub forks.

Seed selection
--------------

Do not reuse a previously good nextpnr seed blindly after a material netlist
change. Use the placement-only scripts for fast candidate ranking and the routed
sweeps for authoritative timing and bitstream generation.

For example, the 12F flow can use:

.. code-block:: bash

   SWEEP_JOBS=30 ./scripts/sweep-peek-ulx3s-12f.sh --all
   SWEEP_JOBS=30 ./scripts/sweep-ulx3s-12f.sh --all

See :doc:`../reference/scripts` for the sweep helper catalog and
:doc:`../reference/timing-sweeps` for the GitHub Actions matrix, parameter
selection, live timing monitor, timeouts, artifacts, and reproducibility rules.

Build ownership
---------------

The project intentionally keeps reusable FPGA/CPU hardware in Hazard3 while
keeping Doom-specific monitor/application ownership in Hazard3-Doom. See
:doc:`../architecture/repositories`.
