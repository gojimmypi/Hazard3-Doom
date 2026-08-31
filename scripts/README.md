# Hazard3-Doom Scripts

Build, setup, programming, debugging, validation, benchmarking, source-audit,
and cleanup utilities for the Hazard3-Doom ULX3S and ULX4M-LD targets.

The scripts are intended to be run from the repository root unless a script's
usage text says otherwise. Most Bash scripts resolve the repository root from
their own location, so they also work when launched from another directory.

See the full Quick Start overview at https://ulx3s.github.io/ulx-doom/

## Quick Start

Complete board builds:

```bash
./scripts/build-ulx3s-doom.sh
./scripts/build-ulx3s-12f-doom.sh
ALLOW_TIMING_FAILURE=1 ./scripts/build-ulx4m-ld-doom.sh
```

The board wrappers build the monitor, FPGA bitstream, and Doom image with a
matched memory/clock profile. Existing nonempty FPGA bitstreams may be reused
where supported; set `FORCE_BITSTREAM_REBUILD=1` when a new synthesis and
nextpnr run is required.

Current primary profiles are:

| Target | Memory profile | Hazard3 clock | Doom/video profile |
| --- | --- | --- | --- |
| ULX3S 85F | `64m` | 50 MHz | 320x200 default; extended modes optional |
| ULX3S 12F | `32m` default, `64m` optional | 40 MHz | 320x200 compact SDRAM scanout |
| ULX4M-LD 85F | `64m` | 50 MHz | 320x200 default |

The monitor, FPGA configuration, Doom image, and SDRAM map must use compatible
settings. Do not mix 32 MiB and 64 MiB software images.

The current build defaults are seed 178 for ULX3S 85F, seed 65 for ULX3S 12F,
and seed 232 for ULX4M-LD. These are convenience baselines, not permanent
optima: rerun a seed sweep after placement-sensitive RTL, memory, video, clock,
or toolchain changes. ULX4M-LD still requires timing investigation; a timing
waiver keeps misses visible and does not claim timing closure.

## Build Scripts

- `build.sh` - Builds the shared Hazard3 monitor firmware. Defaults to the 64 MiB map at 50 MHz; accepts `HAZARD3_MEMORY_PROFILE`, `HAZARD3_SYS_CLK_HZ`, `HAZARD3_BUILD_DIR`, `TOOLCHAIN_PREFIX`, and `HAZARD3_MONITOR_LINKER_SCRIPT` overrides.
- `build-ecp5-bitstream-common.sh` - Internal shared ECP5 synthesis/place-and-route implementation used by the board-specific bitstream wrappers. Normally do not invoke it directly.
- `build-ulx3s-85f-bitstream.sh` - ULX3S 85F entry point for the shared ECP5 flow.
- `build-ulx3s-doom.sh` - Complete ULX3S 85F build: monitor, boot image, FPGA bitstream, Doom image, and SD-card staging files.
- `build-ulx3s-12f-bitstream.sh` - ULX3S 12F entry point for the shared ECP5 flow. Defaults to `HAZARD3_MEMORY_PROFILE=32m`.
- `build-ulx3s-12f-doom.sh` - Complete ULX3S 12F build. Uses a 40 MHz Hazard3 clock, defaults to the 32 MiB map, and intentionally accepts only `HAZARD3_DOOM_HDMI_RESOLUTION=320x200`.
- `build-ulx4m-ld-bitstream.sh` - ULX4M-LD 85F entry point for the shared ECP5 flow.
- `build-ulx4m-ld-doom.sh` - Complete ULX4M-LD 85F build using the 64 MiB map at 50 MHz, including LiteDRAM inputs and the embedded resident monitor. The current development route requires `ALLOW_TIMING_FAILURE=1` because the system and LiteDRAM timing constraints are not yet closed.
- `build-xpack.cmd` - Native Windows monitor build using the repository xPack RISC-V GCC installation. Supports `build`, `clean`, and `rebuild` plus memory-profile and clock arguments.
- `make-boot-hex.py` - Converts the monitor binary into the hexadecimal initialization format consumed by FPGA boot memory.

### ULX3S 12F compact target

The 12F and 85F use the same ULX3S board wiring, pin constraints, CPU ISA, SD
interface, and SAO/ESP32 peripherals. The 12F profile changes the EBR-heavy
storage architecture: the monitor executes from external SDRAM and HDMI uses a
compact line-buffered scanout path.

The normal 12F build defaults to the 32 MiB profile:

```bash
./scripts/build-ulx3s-12f-doom.sh
```

Use a 64 MiB SDRAM map only when the hardware and all software images are
intended to use that map:

```bash
HAZARD3_MEMORY_PROFILE=64m ./scripts/build-ulx3s-12f-doom.sh
```

After programming the FPGA and starting OpenOCD, load the SDRAM-resident monitor
with:

```bash
./scripts/load-firmware-12f.sh
```

The 12F build intentionally supports the standard 320x200 Doom/video path only.

### ULX3S 85F HDMI framebuffer profiles

The ULX3S 85F build supports a lean standard framebuffer and an extended profile.
The complete 85F wrapper defaults to extended modes enabled.

```bash
HAZARD3_HDMI_EXTENDED_MODES=0 ./scripts/build-ulx3s-doom.sh
HAZARD3_HDMI_EXTENDED_MODES=1 ./scripts/build-ulx3s-doom.sh
```

Use the standard profile for unrelated FPGA development or when only 320x200 is
needed. Use the extended profile when testing the optional larger video modes.
Changing the requested profile invalidates incompatible synthesized output.

## Seed Sweep and Timing Scripts

Placement-only sweeps are ranking aids. Routed sweeps are authoritative for
final timing. The common routed-sweep entry point is `sweep-ecp5.sh`; it
dispatches to the board-specific implementation so local runs and GitHub
Actions use the same routing code.

Supported routed targets:

```text
ulx3s-85f
ulx3s-12f
ulx4m-ld-85f
```

Examples:

```bash
./scripts/sweep-ecp5.sh ulx3s-85f 178
SWEEP_JOBS=8 ./scripts/sweep-ecp5.sh ulx3s-85f --all

HAZARD3_MEMORY_PROFILE=32m \
SWEEP_JOBS=8 \
    ./scripts/sweep-ecp5.sh ulx3s-12f 1-64

HAZARD3_ULX4M_SYS_CLK_MHZ=40 \
ULX4M_LITEDRAM_CPU=serv \
SWEEP_JOBS=8 \
    ./scripts/sweep-ecp5.sh ulx4m-ld-85f 48,130,176,223
```

The target-specific scripts remain directly usable:

- `sweep-ulx3s-85f.sh` - ULX3S 85F full routed sweep.
- `sweep.sh` - backward-compatible alias for `sweep-ulx3s-85f.sh`.
- `sweep-ulx3s-12f.sh` - ULX3S 12F full routed sweep.
- `sweep-ulx4m-ld.sh` - ULX4M-LD 85F full routed sweep.
- `sweep-peek.sh` - ULX3S 85F placement-only prescreen.
- `sweep-peek-ulx3s-12f.sh` - ULX3S 12F placement-only prescreen.
- `sweep-peek-ulx3s-12f-best-peek.sh` - routes selected strong 12F placement candidates.

All routed targets accept explicit seeds, comma-separated seeds, ranges such as
`1-32`, or `--all`. `SWEEP_JOBS` controls local concurrency. Each target writes
`metadata.txt`, per-seed result CSV files, and an aggregate results CSV. The
ULX3S targets also retain routed bitstreams locally.

Each nextpnr route is limited by `SWEEP_ROUTE_TIMEOUT_SECONDS`, which defaults
to 600 seconds. `SWEEP_ROUTE_KILL_AFTER_SECONDS` defaults to 30 seconds and
allows a route that ignores `SIGTERM` to be killed. A timed-out route is
recorded with `timing_status=TIMEOUT` and the sweep continues with the remaining
seeds; it is not treated as a tool failure. For example:

```bash
SWEEP_ROUTE_TIMEOUT_SECONDS=900 \
    ./scripts/sweep-ecp5.sh ulx3s-85f 1-32
```

The GitHub seed-sweep workflow also applies a 720-second whole-seed watchdog
around each `sweep-ecp5.sh` invocation. This is a second safety net for hangs
outside nextpnr itself; the normal nextpnr timeout should fire first.

Common optional nextpnr tuning is available on every routed target:

```bash
SWEEP_NEXTPNR_PLACER=heap
SWEEP_NEXTPNR_ROUTER=router2
SWEEP_NEXTPNR_HEAP_TIMINGWEIGHT=30
SWEEP_NEXTPNR_HEAP_CRITEXP=3
SWEEP_NEXTPNR_TMG_RIPUP=1
SWEEP_NEXTPNR_ROUTER2_ALT_WEIGHTS=1
SWEEP_NEXTPNR_EXTRA_ARGS='...'
```

The GitHub workflow `.github/workflows/ulx4m-ld-seed-sweep.yml` is now a
parameterized ECP5 seed-sweep workflow despite the retained historical filename.
Select the target and seed range with `workflow_dispatch`. The prepare job
synthesizes one frozen netlist; route jobs use `SWEEP_SKIP_SYNTH=1` against that
exact netlist, and the final summary is generated by
`summarize-ecp5-sweep.py`. Synthesis and routing OSS CAD Suite snapshots can be
selected independently for nextpnr A/B testing.

`SWEEP_PREPARE_ONLY=1` and `SWEEP_SKIP_SYNTH=1` are primarily CI plumbing, but
they are also useful for controlled local experiments where multiple routes
must use exactly the same synthesized JSON.

Run a new routed sweep whenever the FPGA netlist changes materially. A seed that
was optimal for an earlier design is not expected to remain optimal after EBR,
clock, cache, framebuffer, or other placement-sensitive changes.

## Submodule, Fork, and Source Status

These scripts have different purposes and should not be treated as substitutes
for one another.

- `setup-submodules.sh` - Initializes the submodules needed for normal builds: top-level DoomGeneric and Hazard3 plus Hazard3's nested `scripts` and `example_soc/libfpga`. Set `HAZARD3_INIT_ALL_SUBMODULES=1` to initialize the entire recursive tree.
- `doomgeneric-version.sh` - Defines the pinned DoomGeneric repository and commit used by the build helpers.
- `setup-doomgeneric.sh` - Validates the pinned DoomGeneric checkout and required source files; intentional dirty development trees require `HAZARD3_DOOM_ALLOW_DIRTY_DOOMGENERIC=1`.
- `hazard3-submodule.sh` - Bash inspection/restoration helper. `status` reports Hazard3 and DoomGeneric; `diff` and `restore` operate on Hazard3 and its pinned nested tree.
- `update-hazard3-submodule.sh` - Explicitly advances, reports, or restores the Hazard3 gitlink. It does not modify `.gitmodules`; use `update`, `status`, or `restore`.
- `check_submodules.bat` - Windows local-state safety check. It compares each checkout with the parent HEAD/index and with the configured branch from the matching `.gitmodules` URL. It checks top-level submodules and the nested `third_party/Hazard3/example_soc/libfpga` gitlink.
- `hazard3-doom-source-status.sh` - Network-wide fork/branch audit. It fetches every branch into temporary bare repositories, discovers actual default branches, compares branch tips within and across forks, and writes the report to both the terminal and `build/source_status.log`. Current families are Hazard3-Doom, DoomGeneric, Hazard3, and Hazard3-libfpga/libfpga.

The local checker answers "is this working tree and recorded gitlink safe and
current for its configured branch?" The source-status report answers "what
branches exist across the related forks and how do their histories compare?"

Typical use:

```bash
./scripts/hazard3-doom-source-status.sh
./scripts/hazard3-submodule.sh status
./scripts/update-hazard3-submodule.sh status
```

From Windows Command Prompt:

```bat
scripts\check_submodules.bat
```

## Programming and Debugging

- `start-openocd.sh` - Starts OpenOCD on Linux/WSL using the repository ULX3S configuration; converts paths when a Windows `.exe` is used from WSL.
- `start-openocd.bat` - Starts the Windows OpenOCD server using the repository configuration.
- `load-firmware.sh` - Loads, verifies, starts, and disconnects the normal monitor ELF through a running GDB/OpenOCD server.
- `load-firmware-12f.sh` - Loads the ULX3S 12F SDRAM-resident monitor after FPGA configuration.
- `load-firmware.bat` - Windows monitor loader through GDB/OpenOCD.
- `load-fpga-bitstream.bat` - Windows FPGA bitstream loader.
- `flash-ulx3s-persistent.sh` - Programs the built ULX3S 85F bitstream into persistent SPI flash for cold boot; requires `build/fpga_ulx3s.bit`.
- `hazard3-debug.gdb` - GDB command definitions used for source-level Hazard3 debugging through OpenOCD.
- `return-to-monitor.py` - Sends Ctrl-X over UART to stop a running Doom instance and return to the resident monitor; defaults to `/dev/ttyS7` at 115200 baud.
- `restart-from-monitor.py` - Sends monitor command `j` over UART to start the already loaded Doom image; defaults to `/dev/ttyS7` at 115200 baud.

### GDB command files

The `gdb/` directory contains focused command scripts for monitor and SAO tests:

- `gdb/load-hazard3-test-elf.gdb` - GDB command sequence for loading the Hazard3 test/monitor ELF.
- `gdb/sao-probe.gdb` - Probe SAO bridge state from GDB.
- `gdb/sao-scan.gdb` - Exercise the SAO I2C scan path from GDB.
- `gdb/sao-touchwheel-test.gdb` - Interactive/debug test sequence for the SAO touchwheel.
- `gdb/sao-touchwheel-led-off.gdb` - Turns off the touchwheel LED from GDB.

## CoreMark and ELF Inspection

- `build-coremark.sh` - Builds the Hazard3 CoreMark port. Supports `baseline` and `tuned` build profiles, configurable iteration count, and supported 25/50 MHz timing profiles.
- `run-coremark.sh` - Runs or qualifies CoreMark images over the target UART. Supports `performance`, `validation`, and `qualify` modes and stores run logs/results under the CoreMark build directory.
- `peek-elf.sh` - Inspects a linked RISC-V ELF/map, selected multilib, ISA attributes, and libgcc/archive selection. With no arguments it examines the baseline CoreMark output.

## Validation, Repository Hygiene, and VisualGDB

- `check-executable.sh` - Checks recently changed tracked shell scripts for the Git executable bit; defaults to the most recent five commits.
- `git-exe.sh` - Sets the Git executable bit for one tracked file and prints the resulting index entry.
- `check-nettype.sh` - Checks Verilog sources for consistent `default_nettype` handling.
- `check-windows-visualgdb.ps1` - Validates the native-Windows VisualGDB/NMake configuration and expected xPack monitor build commands.
- `check-wsl-visualgdb.ps1` - Validates the WSL VisualGDB bridge, expected build/debug paths, and LF-only tracked shell scripts.
- `inventory.sh` - Inventories Git-tracked files in the selected path and writes deterministic Markdown, TSV, and SHA-256 reports. It intentionally uses Git's index instead of walking ignored/untracked toolchains.
- `INVENTORY.md` - Human-readable generated inventory for the scripts directory.
- `INVENTORY.tsv` - Machine-readable generated inventory.
- `INVENTORY.sha256` - SHA-256 list for the generated inventory set.
- `full-clean.sh` - Cleans supported FPGA synthesis targets and removes the repository `build/` tree. Use `--dry-run` to preview; submodules, WADs, and checked-in LiteDRAM sources are preserved.

## Setup and Toolchain Helpers

- `setup-xpack-riscv-gcc.cmd` - Installs/configures the xPack GNU RISC-V Embedded GCC toolchain under `bin/riscv-gcc` for native Windows builds.

## Supercon Helpers

The normal Hazard3-Doom build remains unchanged by the Supercon helper flow.
The demo uses a dedicated noncombat image and a separately generated WAD.

- `build-doom-noncombat.sh` - Builds `build/doom-image-noncombat/hazard3-doom.h3d` with the dedicated noncombat source transform and verifies marker symbols in the compiled objects.
- `apply-doom-noncombat.py` - Internal transform applied only to the prepared DoomGeneric build copy; it does not edit the submodule.
- `build-supercon10-wad.py` - Verifies the Supercon PWAD, merges it with a local `wads/DOOM1.WAD`, verifies expected banner textures, and writes `wads/SUPERCON10.WAD` by default.
- `cleanup-supercon-dev.py.bak` - Retained backup of an older development cleanup helper; it is not part of the normal supported workflow.

Example:

```bash
./scripts/build-doom-noncombat.sh
./scripts/build-supercon10-wad.py
./scripts/return-to-monitor.py --port /dev/ttyS7
./doom/upload-doom-image.py ./build/doom-image-noncombat/hazard3-doom.h3d --port /dev/ttyS7
./doom/upload-wad.py ./wads/SUPERCON10.WAD --port /dev/ttyS7 --launch
```

## Directory Inventory Summary

The directory intentionally contains several types of files:

- `*.sh` - Linux/WSL build, validation, sweep, setup, programming, and audit helpers.
- `*.bat` / `*.cmd` - Native Windows programming, build, and submodule helpers.
- `*.ps1` - VisualGDB configuration validation.
- `*.py` - Host-side transforms, UART control, packaging, and generation helpers.
- `*.gdb` and `gdb/*.gdb` - GDB command files for Hazard3 and SAO debugging.
- `INVENTORY.*` - Generated file inventory/hash reports; regenerate them with `./scripts/inventory.sh ./scripts` when tracked contents change.
- `README.md` - This directory-level reference.

The Read the Docs version of the script reference is in
`docs/reference/scripts.rst`.
