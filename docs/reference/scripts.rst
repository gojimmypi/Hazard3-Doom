Script Reference
================

The ``scripts/`` directory contains the host-side build, setup, programming,
debugging, validation, benchmarking, source-audit, and cleanup helpers used by
Hazard3-Doom. This page describes the checked-in scripts by purpose and explains
which tools are authoritative for common maintenance tasks.

Most Bash scripts resolve the repository root from their own location. Unless a
script says otherwise, examples below assume the current directory is the
Hazard3-Doom repository root.

For the shorter directory-oriented summary, see ``scripts/README.md`` in the
repository.

Complete board builds
---------------------

The complete board wrappers keep the monitor, FPGA design, Doom image, and SDRAM
memory map aligned.

``scripts/build-ulx3s-doom.sh``
   Complete ULX3S 85F build. It builds the 50 MHz/64 MiB monitor, prepares the
   FPGA resident boot image, builds or reuses the 85F bitstream, builds the Doom
   image, and stages files used by the SD-card workflow. The 85F wrapper defaults
   to extended HDMI modes enabled; set ``HAZARD3_HDMI_EXTENDED_MODES=0`` for the
   lean 320x200-only framebuffer profile.

``scripts/build-ulx3s-12f-doom.sh``
   Complete ULX3S 12F compact build. The default is the 32 MiB memory profile at
   a 40 MHz Hazard3 system clock. The 64 MiB map is optional through
   ``HAZARD3_MEMORY_PROFILE=64m``. The compact target intentionally accepts only
   ``HAZARD3_DOOM_HDMI_RESOLUTION=320x200`` and uses an SDRAM-resident monitor.

``scripts/build-ulx4m-ld-doom.sh``
   Complete ULX4M-LD 85F build. It uses the 64 MiB map at 50 MHz and checks the
   required LiteDRAM generated sources before building the monitor, embedded boot
   image, FPGA bitstream, and Doom image.

Examples:

.. code-block:: bash

   ./scripts/build-ulx3s-doom.sh
   ./scripts/build-ulx3s-12f-doom.sh
   ./scripts/build-ulx4m-ld-doom.sh

To test another Hazard3 checkout without changing the Hazard3-Doom gitlink:

.. code-block:: bash

   HAZARD3_ROOT=/mnt/c/workspace/Hazard3 \
       ./scripts/build-ulx3s-doom.sh

Monitor and bitstream build helpers
-----------------------------------

``scripts/build.sh``
   Build the resident monitor firmware. The default is the 64 MiB memory map at
   50 MHz. Important overrides include ``HAZARD3_MEMORY_PROFILE``,
   ``HAZARD3_SYS_CLK_HZ``, ``HAZARD3_BUILD_DIR``, ``TOOLCHAIN_PREFIX``, and
   ``HAZARD3_MONITOR_LINKER_SCRIPT``. Outputs include
   ``hazard3-boot-monitor.elf``, ``.map``, and ``.bin`` in the selected build
   directory.

``scripts/build-ulx3s-85f-bitstream.sh``
   Board-specific ULX3S 85F entry point for the shared ECP5 flow.

``scripts/build-ulx3s-12f-bitstream.sh``
   Board-specific ULX3S 12F entry point for the shared ECP5 flow. Defaults to
   ``HAZARD3_MEMORY_PROFILE=32m``.

``scripts/build-ulx4m-ld-bitstream.sh``
   Board-specific ULX4M-LD 85F entry point for the shared ECP5 flow.

``scripts/build-ecp5-bitstream-common.sh``
   Internal shared synthesis/place-and-route implementation used by the three
   board-specific bitstream wrappers. It is not normally invoked directly.

``scripts/make-boot-hex.py``
   Convert a monitor binary into the hexadecimal initialization file consumed by
   FPGA boot memory.

``scripts/build-xpack.cmd``
   Native Windows monitor build using ``bin/riscv-gcc``. Its arguments are
   ``[build|clean|rebuild] [64m|32m] [50000000|25000000]``. With no arguments it
   builds the 64 MiB/50 MHz monitor.

Doom and Supercon build helpers
-------------------------------

``doom/build-doom-image.sh``
   Build and package the linked Doom application. The monitor and Doom image must
   use the same memory profile.

``scripts/build-doom-noncombat.sh``
   Build the dedicated Supercon noncombat image under
   ``build/doom-image-noncombat/``. The script applies the transform only to a
   prepared DoomGeneric copy and verifies marker symbols in the resulting object
   files.

``scripts/apply-doom-noncombat.py``
   Internal source transform used by the dedicated noncombat build. It does not
   modify the checked-out DoomGeneric submodule.

``scripts/build-supercon10-wad.py``
   Validate and merge the project Supercon PWAD with a local ``DOOM1.WAD``. By
   default the resulting combined image is ``wads/SUPERCON10.WAD``.

``scripts/cleanup-supercon-dev.py.bak``
   Retained backup of an older Supercon development cleanup helper. It is not
   part of the normal supported workflow.

Placement and routed seed sweeps
--------------------------------

Placement-only sweeps rank candidates quickly. They are not final timing proof.
Use the routed sweep before selecting a production seed.

``scripts/sweep-peek.sh``
   ULX3S 85F placement-only nextpnr sweep. It stops before routing. With no seed
   argument it scans the configured range; an explicit seed limits the run.
   ``SWEEP_JOBS`` controls concurrent placements and
   ``HAZARD3_HDMI_EXTENDED_MODES`` selects the 85F video profile.

``scripts/sweep.sh``
   ULX3S 85F full place-and-route sweep. Accepts explicit seeds, comma-separated
   seeds, or ``--all``. ``SWEEP_JOBS`` controls concurrent routing jobs. Routed
   logs and bitstreams are retained under ``build/ulx3s-seed-sweep/``.

``scripts/sweep-peek-ulx3s-12f.sh``
   ULX3S 12F placement-only sweep. Accepts explicit seeds or ``--all``. Defaults
   to four concurrent jobs and the 32 MiB profile. Results are written under
   ``build/ulx3s-12f-placement-sweep/<profile>/``.

``scripts/sweep-ulx3s-12f.sh``
   ULX3S 12F full routed sweep. Accepts explicit seeds or ``--all``. Defaults to
   four concurrent routes and the 32 MiB profile. Routed logs, configuration,
   SVF, bitstreams, metadata, and CSV results are retained under
   ``build/ulx3s-12f-seed-sweep/<profile>/``.

``scripts/sweep-peek-ulx3s-12f-best-peek.sh``
   Convenience follow-up helper that launches a routed sweep for the strongest
   12F placement candidates.

``scripts/sweep-ulx4m-ld.sh``
   ULX4M-LD routed seed sweep. Accepts a single seed or a seed range and defaults
   to two concurrent jobs.

Examples:

.. code-block:: bash

   SWEEP_JOBS=8 ./scripts/sweep-peek.sh
   SWEEP_JOBS=8 ./scripts/sweep.sh --all
   SWEEP_JOBS=30 ./scripts/sweep-peek-ulx3s-12f.sh --all
   SWEEP_JOBS=30 ./scripts/sweep-ulx3s-12f.sh --all
   ./scripts/sweep-ulx4m-ld.sh 1-32

A previously good seed is not guaranteed to remain good after a material RTL,
clock, cache, EBR, or framebuffer change.

Submodule initialization and local-state checks
-----------------------------------------------

``scripts/setup-submodules.sh``
   Initialize the build-required submodule set. The normal mode initializes
   top-level DoomGeneric and Hazard3, then Hazard3's nested ``scripts`` and
   ``example_soc/libfpga`` submodules. Set ``HAZARD3_INIT_ALL_SUBMODULES=1`` to
   initialize every recursive submodule instead.

``scripts/doomgeneric-version.sh``
   Define the DoomGeneric repository/commit expected by the Doom build helpers.

``scripts/setup-doomgeneric.sh``
   Validate the DoomGeneric checkout and required source files. Intentional dirty
   development builds require ``HAZARD3_DOOM_ALLOW_DIRTY_DOOMGENERIC=1``.

``scripts/hazard3-submodule.sh``
   Inspect or restore the Hazard3 submodule. ``status`` reports Hazard3 and
   DoomGeneric. ``diff`` and ``restore`` operate on Hazard3; restore returns it to
   the gitlink recorded by Hazard3-Doom HEAD and updates its nested submodules.

``scripts/update-hazard3-submodule.sh``
   Explicitly update, report, or restore the Hazard3 gitlink. It intentionally
   does not edit ``.gitmodules``. Commands are ``update``, ``status``, and
   ``restore``.

``scripts/check_submodules.bat``
   Windows local-state safety check. For each checked submodule it compares the
   checkout, parent index, parent HEAD gitlink, dirty state, and configured remote
   branch. The remote is selected by matching the URL from the appropriate
   ``.gitmodules`` instead of assuming that the correct remote is named
   ``origin``. In addition to the Hazard3-Doom top-level submodules, it checks the
   nested ``third_party/Hazard3/example_soc/libfpga`` gitlink against Hazard3's
   own index and HEAD.

The local submodule checker is deliberately conservative. A staged pointer,
unrecorded update, behind branch, divergent branch, or mismatched checkout is a
problem that should be understood before committing.

Fork and branch audit
---------------------

``scripts/hazard3-doom-source-status.sh``
   Comprehensive network-wide source-history report. The script does not depend
   on the remotes configured in the working tree. It creates temporary bare Git
   repositories, fetches every branch from each configured fork, discovers each
   repository's actual default branch from remote HEAD, and compares histories.

   Current source families are:

   * Hazard3-Doom: the current user's fork and ``ulx3s/Hazard3-Doom``.
   * DoomGeneric: the current user's fork, ``ulx3s/doomgeneric``, and
     ``ozkl/doomgeneric``.
   * Hazard3: the current user's fork, ``ulx3s/Hazard3``, and
     ``Wren6991/Hazard3``.
   * Hazard3-libfpga/libfpga: the current user's ``Hazard3-libfpga`` fork,
     ``ulx3s/Hazard3-libfpga``, and canonical ``Wren6991/libfpga``.

   For every branch, the report shows ahead/behind counts relative to that
   repository's own default branch and the canonical upstream default, along with
   commit date, SHA, and subject. It also performs default-to-default and
   same-named-branch comparisons across forks. ``UNRELATED`` means Git found no
   common merge base.

   Output is displayed live and simultaneously written to
   ``build/source_status.log``. The optional first argument selects the GitHub
   username; it defaults to ``gojimmypi``.

.. code-block:: bash

   ./scripts/hazard3-doom-source-status.sh
   ./scripts/hazard3-doom-source-status.sh gojimmypi

The distinction is important: ``check_submodules.bat`` validates the safety of
the local recorded submodule state, while ``hazard3-doom-source-status.sh``
compares the larger family of branches and forks on GitHub.

Programming and OpenOCD
-----------------------

``scripts/start-openocd.sh``
   Start OpenOCD from Linux or WSL using the repository ULX3S configuration. If
   a native Windows OpenOCD ``.exe`` is invoked from WSL, the script converts the
   configuration path to Windows syntax.

``scripts/start-openocd.bat``
   Native Windows OpenOCD launcher. An explicit OpenOCD executable may be passed
   as the first argument; otherwise the repository binary is used.

``scripts/load-firmware.sh``
   Load the normal monitor ELF through a running OpenOCD GDB server, halt the
   target, load and compare sections, set ``$pc`` to ``_start``, resume, and
   disconnect. This avoids leaving GDB attached after programming.

``scripts/load-firmware-12f.sh``
   Load the ULX3S 12F SDRAM-resident monitor after the compact FPGA bitstream has
   been programmed and OpenOCD is running.

``scripts/load-firmware.bat``
   Native Windows monitor loader using GDB and OpenOCD.

``scripts/load-fpga-bitstream.bat``
   Native Windows helper for loading a generated or prebuilt FPGA bitstream.

``scripts/flash-ulx3s-persistent.sh``
   Program ``build/fpga_ulx3s.bit`` into ULX3S SPI flash for persistent cold
   boot. This is distinct from volatile SRAM programming.

UART control
------------

``scripts/return-to-monitor.py``
   Send Ctrl-X over the UART so a running Doom instance exits to the resident
   monitor, then release the serial port. Defaults are ``/dev/ttyS7`` and 115200
   baud.

``scripts/restart-from-monitor.py``
   Send monitor command ``j`` to launch an already validated Doom image/IWAD,
   then release the serial port. Defaults are ``/dev/ttyS7`` and 115200 baud.

GDB helpers
-----------

``scripts/hazard3-debug.gdb``
   Common Hazard3 GDB command definitions used by the project debug setup.

``scripts/gdb/load-hazard3-test-elf.gdb``
   Focused GDB command file for loading the Hazard3 monitor/test ELF.

``scripts/gdb/sao-probe.gdb``
   Probe SAO bridge state from GDB.

``scripts/gdb/sao-scan.gdb``
   Exercise the SAO I2C scan path from GDB.

``scripts/gdb/sao-touchwheel-test.gdb``
   SAO touchwheel test/debug sequence.

``scripts/gdb/sao-touchwheel-led-off.gdb``
   Turn off the touchwheel LED through the GDB debug path.

CoreMark and ELF analysis
-------------------------

``scripts/build-coremark.sh``
   Build the Hazard3 CoreMark port. ``COREMARK_BUILD_PROFILE`` selects
   ``baseline`` or ``tuned``; iteration count, system clock, build directory,
   Hazard3 checkout, and toolchain prefix can also be overridden.

``scripts/run-coremark.sh``
   Run ``performance`` or ``validation`` CoreMark images, or use ``qualify`` to
   run both and summarize the result. A serial port may be supplied for automated
   UART capture.

``scripts/peek-elf.sh``
   Inspect a RISC-V map/ELF, the selected GCC multilib, linked libgcc members,
   and final ISA attributes. With no arguments it examines the baseline CoreMark
   build under ``build/coremark/baseline/``.

Repository hygiene and generated inventory
------------------------------------------

``scripts/check-executable.sh``
   Verify that tracked shell scripts changed in recent commits carry the Git
   executable bit. The default window is the five most recent commits.

``scripts/git-exe.sh``
   Mark one tracked file executable in the Git index and print the resulting
   index entry.

``scripts/check-nettype.sh``
   Validate Verilog ``default_nettype`` handling.

``scripts/inventory.sh``
   Inventory Git-tracked files for the requested path and write deterministic
   Markdown, TSV, and SHA-256 reports. The script asks Git for tracked files
   instead of walking ignored/untracked toolchains.

``scripts/INVENTORY.md``
   Generated human-readable scripts-directory inventory.

``scripts/INVENTORY.tsv``
   Generated machine-readable scripts-directory inventory.

``scripts/INVENTORY.sha256``
   Generated SHA-256 inventory output.

``scripts/full-clean.sh``
   Clean supported FPGA synthesis targets and remove the Hazard3-Doom ``build/``
   tree. ``--dry-run`` previews the cleanup. Submodules, WAD files, and checked-in
   LiteDRAM sources are intentionally preserved.

VisualGDB and Windows toolchain validation
------------------------------------------

``scripts/check-windows-visualgdb.ps1``
   Validate the native-Windows VisualGDB/NMake project settings and expected
   xPack monitor build/clean commands.

``scripts/check-wsl-visualgdb.ps1``
   Validate the WSL VisualGDB bridge, expected WSL build/debug paths, and tracked
   shell-script line endings needed by Bash.

``scripts/setup-xpack-riscv-gcc.cmd``
   Install/configure xPack GNU RISC-V Embedded GCC under ``bin/riscv-gcc`` for
   the native Windows build flow.

.. note::

   Script behavior evolves faster than the architecture documentation. When an
   option is not documented here, use the checked-out script's usage/help text
   and environment-variable validation as the authoritative source.
