Building Hazard3-Doom
=====================

Complete board builds
---------------------

The complete board wrappers are the safest way to build a matched FPGA,
monitor, and Doom image for one target.

ULX3S 85F, 64 MiB, 50 MHz:

.. code-block:: bash

   ./scripts/build-ulx3s-85f-doom.sh

ULX3S 12F compact target, 32 MiB default, 40 MHz:

.. code-block:: bash

   ./scripts/build-ulx3s-12f-doom.sh

ULX4M-LD 85F, 64 MiB software map, 40 MHz Hazard3 and 60 MHz LiteDRAM.
The normal complete-build route must close every required clock:

.. code-block:: bash

   ./scripts/build-ulx4m-ld-doom.sh

The complete board wrappers keep target-specific artifacts under board-scoped
directories. In particular, the Doom upload images are:

.. code-block:: text

   build/ulx3s-85f/doom-image/hazard3-doom.h3img
   build/ulx3s-12f/doom-image/hazard3-doom.h3img
   build/ulx4m-ld/doom-image/hazard3-doom.h3img

The standalone ``doom/build-doom-image.sh`` command documented later on this
page still uses the generic ``build/doom-image/`` directory unless
``HAZARD3_DOOM_BUILD_DIR`` is set.

The build uses the shared ULX4M-LD routing defaults defined in
``scripts/build-ecp5-bitstream-common.sh`` and summarized in
:doc:`../reference/board-profiles`. The historical frozen seed-2 checkpoint
also passed the full DDR qualification suite on a
Micron-populated ULX4M-LD, but a complete rebuild changes the synthesized
netlist when the resident monitor or generated LiteDRAM profile changes. Rerun
the timing sweep and hardware tests for a release artifact rather than assuming
the selected seed remains valid. ``ALLOW_TIMING_FAILURE=1`` is reserved for explicit
ULX4M-LD sweep experiments, not release builds. See
:doc:`../reference/board-profiles` and :doc:`../reference/timing-sweeps`.

The 12F wrapper supports either a 32 MiB or 64 MiB SDRAM map, but defaults to
32 MiB. If the 64 MiB map is selected, keep the monitor and Doom image matched:

.. code-block:: bash

   HAZARD3_MEMORY_PROFILE=64m ./scripts/build-ulx3s-12f-doom.sh

The compact 12F target intentionally supports the 320x200 Doom/video path only.
Its 1 KiB EBR cannot contain the full monitor, so the complete build generates a
small resident UART bootstrap and embeds that in ``fpga_ulx3s_12f.bit``. At cold
boot the bootstrap initializes the 115200-baud console and explains that the full
monitor is SDRAM-resident. After programming the 12F bitstream, run:

.. code-block:: bash

   ./scripts/load-firmware-12f.sh

The helper reuses an OpenOCD server already listening on ``localhost:3333`` or
starts ``scripts/start-openocd.sh`` automatically, waits for the GDB server,
loads and verifies ``build/ulx3s-12f/monitor/hazard3-boot-monitor.elf``, and
stops only the OpenOCD process that it started.

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

For a software-only ULX4M-LD monitor update against an already configured
40 MHz FPGA, keep the output separate from the resident preload:

.. code-block:: bash

   HAZARD3_BUILD_DIR="$PWD/build/ulx4m-ld-monitor-test/monitor" \
   HAZARD3_MEMORY_PROFILE=64m \
   HAZARD3_SYS_CLK_HZ=40000000 \
       ./scripts/build.sh

Load it through an already-running OpenOCD session with:

.. code-block:: bash

   ./scripts/load-firmware.sh \
       ./build/ulx4m-ld-monitor-test/monitor/hazard3-boot-monitor.elf

This updates only processor software in the running FPGA and does not reroute
the known-good bitstream.

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
   build/doom-image/hazard3-doom.h3img

Testing another Hazard3 checkout
--------------------------------

You can test a hardware checkout without changing the pinned Hazard3-Doom
submodule pointer:

.. code-block:: bash

   HAZARD3_ROOT=/mnt/c/workspace/Hazard3 \
       ./scripts/build-ulx3s-85f-doom.sh

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
