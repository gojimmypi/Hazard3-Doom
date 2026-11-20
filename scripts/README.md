# Hazard3-Doom Scripts

Build, setup, programming, debugging, validation, benchmarking, source-audit,
and cleanup utilities for the Hazard3-Doom ULX3S and ULX4M-LD targets.

The scripts are intended to be run from the repository root unless a script's
usage text says otherwise. Most Bash scripts resolve the repository root from
their own location, so they also work when launched from another directory.

See the full Quick Start overview at https://ulx3s.github.io/ulx-doom/

Sweep summaries:

- [ULX3S-12F](./build-ulx3s-12f-sweep_summary.md)
- [ULX3S-85F](./build-ulx3s-85f-sweep_summary.md)
- [ULX4M-LD](./build-ulx4m-ld-sweep_summary.md)

## Quick Start

Complete board builds:

```bash
./scripts/build-ulx3s-12f-doom.sh
./scripts/build-ulx3s-85f-doom.sh
./scripts/build-ulx4m-ld-doom.sh
```

The board wrappers build the monitor, FPGA bitstream, and Doom image with a
matched memory/clock profile. Existing nonempty FPGA bitstreams may be reused
where supported; set `FORCE_BITSTREAM_REBUILD=1` when a fresh route/bitstream is
required. Normal bitstream builds synthesize before routing.

For ULX4M-LD only, `SKIP_SYNTH=1` preserves and routes the existing synthesized
`fpga_ulx4m_ld.json` instead of invoking Make/Yosys. Combine it with
`FORCE_BITSTREAM_REBUILD=1` to reroute and repack a deliberately frozen netlist:

```bash
SKIP_SYNTH=1 \
FORCE_BITSTREAM_REBUILD=1 \
    ./scripts/build-ulx4m-ld-bitstream.sh
```

The frozen-netlist path requires the recorded system-clock and LiteDRAM-CPU
profiles to match the requested build. It prints the JSON SHA256 before
nextpnr and never deletes or replaces the JSON when a profile check fails.
Synthesized JSON, synthesis logs, profile stamps, routed outputs, and sweep
results are written below the main repository's ignored `build/` directory;
the Hazard3 submodule supplies source files and constraints only.

Current primary profiles are:

| Target | Memory profile | Hazard3 clock | Doom/video profile |
| --- | --- | --- | --- |
| ULX3S 85F | `64m` | 25 MHz default; 40/50 selectable | 320x200 default; extended modes optional |
| ULX3S 12F | `32m` default, `64m` optional | 40 MHz | 320x200 compact SDRAM scanout |
| ULX4M-LD 85F | `64m` | 40 MHz | 320x200 default |
| ULX5M-GS | `32m` | 25 MHz | Phase-1 headless target |

The monitor, FPGA configuration, Doom image, and SDRAM map must use compatible
settings. Do not mix 32 MiB and 64 MiB software images.

The authoritative board-specific nextpnr defaults are kept together in
`ecp5-board-defaults.sh`. The board wrappers consume those shared
settings, so this README does not maintain a second copy of the seed values.
They are convenience baselines, not permanent optima: rerun a seed sweep after
placement-sensitive RTL, memory, video, clock, or toolchain changes.

## Build Scripts

- `build.sh` - Builds the shared Hazard3 monitor firmware. Defaults to the 64 MiB map at 50 MHz. Unless `TOOLCHAIN_PREFIX` is set, it searches `PATH` for supported RISC-V bare-metal prefixes (`riscv-none-elf-*`, `riscv32-unknown-elf-*`, or `riscv64-unknown-elf-*`) and uses the historical `/opt/riscv/bin/riscv32-unknown-elf-*` location only as a compatibility fallback; accepts `HAZARD3_MEMORY_PROFILE`, `HAZARD3_SYS_CLK_HZ`, `HAZARD3_BUILD_DIR`, `TOOLCHAIN_PREFIX`, and `HAZARD3_MONITOR_LINKER_SCRIPT` overrides.
- `build-ecp5-bitstream-common.sh` - Internal shared ECP5 synthesis/place-and-route implementation used by the board-specific bitstream wrappers. Normally do not invoke it directly.
- `build-ulx3s-85f-bitstream.sh` - ULX3S 85F entry point for the shared ECP5 flow.
- `build-ulx3s-85f-doom.sh` - Complete ULX3S 85F build: monitor, boot image, FPGA bitstream, Doom image, and SD-card staging files under `build/ulx3s-85f/`. Select the system clock with `HAZARD3_ULX3S_85F_SYS_CLK_MHZ=25|40|50` (default 25); the monitor and RTL use the same value. `40` and `50` are experimental until they pass timing at `--85k --speed 6`. At 40/50 MHz, `HAZARD3_ULX3S_85F_REGISTERED_READ_HITS=1` is the default; override with `0` only for comparisons. `HAZARD3_ULX3S_85F_SRAM_WRITE_BUFFER=1` retains the original EBR write buffer; set it to `0` for the experimental one-wait-state write-to-read collision implementation (not yet hardware qualified).
- `build-ulx3s-12f-bitstream.sh` - ULX3S 12F entry point for the shared ECP5 flow. Defaults to `HAZARD3_MEMORY_PROFILE=32m`.
- `build-ulx3s-12f-doom.sh` - Complete ULX3S 12F build. Uses a 40 MHz Hazard3 clock, defaults to the 32 MiB map, and intentionally accepts only `HAZARD3_DOOM_HDMI_RESOLUTION=320x200`.
- `build-ulx4m-ld-bitstream.sh` - ULX4M-LD 85F entry point for the shared ECP5 flow. Supports `SKIP_SYNTH=1` for routing an existing frozen JSON without invoking Make/Yosys.
- `build-ulx4m-ld-doom.sh` - Complete ULX4M-LD 85F build using the 64 MiB map at 40 MHz, including LiteDRAM inputs and the embedded resident monitor under `build/ulx4m-ld/`. The default route settings come from `build-ecp5-bitstream-common.sh`.
- `build-ulx5m-gs-bitstream.sh` - ULX5M-GS GateMate A1 phase-1 bitstream build using `nextpnr-himbaechel`, Router2, and `gmpack`.
- `build-ulx5m-gs-doom.sh` - Complete ULX5M-GS phase-1 build using the 32 MiB SDRAM map at 25 MHz.
- `build-xpack.cmd` - Native Windows monitor build using the repository xPack RISC-V GCC installation. Supports `build`, `clean`, and `rebuild` plus memory-profile and clock arguments, and refuses to build if `src/generated/version.h` is stale relative to the root `VERSION` file.
- `make-boot-hex.py` - Converts the monitor binary into the hexadecimal initialization format consumed by FPGA boot memory.

### ULX3S 85F system-clock experiments

The 50 MHz seed-11 baseline on November 12, 2026 reached only 30.37 MHz
with unregistered cache-hit responses. Its critical path ran from the SDRAM
cache tag RAM through cache/CPU control to the APB bridge. The existing 12F
registered-read-hit option is now selectable on the 85F. The default remains
unregistered at 25 MHz and becomes registered at 40/50 MHz. This is an
**experimental RTL change**, not a certified 50 MHz timing fix. The toggle
introduces an extra cycle for cache-hit responses. The 85F wrappers, routed
sweeps and placement sweeps keep separate netlist stamps and output directories
for registered/unregistered builds. Do not reuse an old netlist across modes.


The follow-up 50 MHz registered-hit seed-11 route reached 35.74 MHz with
`HAZARD3_ULX3S_85F_SRAM_WRITE_BUFFER=1`. Its new limiting path ended at
an on-chip SRAM EBR write-enable pin, with 5.81 ns logic plus 22.17 ns
routing. The SRAM adapter already supports a no-write-buffer mode. Set
`HAZARD3_ULX3S_85F_SRAM_WRITE_BUFFER=0` to test that existing option.
It may shorten this critical path, but also adds a wait state on some
write-to-read sequences; full functional and timing qualification is required.
The default remains 1 for all clock profiles. Bitstream builds and both
sweep types stamp this parameter and reject/rebuild mismatched netlists.

The older `synth/build-ulx3s-doom.sh` entry point also accepts this clock
selection, but use the canonical full board wrapper below for experimental
clock builds and verified monitor preload generation.


The ULX3S 85F is an LFE5U-85F-6BG381C (`--85k --speed 6`), regardless of
clock selection. The default 25 MHz system clock uses the oscillator; 40/50 MHz
use the existing 25-to-40/25-to-50 PLLs. All 85F profiles retain independent
25 MHz pixel and 125 MHz TMDS clocks for 640x480 HDMI. The 12F remains at 40
MHz and is not affected.

For a fresh 50 MHz build (timing failures cause a nonzero exit):

```bash
HAZARD3_ULX3S_85F_SYS_CLK_MHZ=50 NEXTPNR_SEED=11 \
    ./scripts/build-ulx3s-85f-doom.sh
```

Even if this exploratory build fails P&R, it creates a clock-matched monitor
preload and stamp for a subsequent seed sweep. Try a small 50 MHz sweep first:

```bash
HAZARD3_ULX3S_85F_SYS_CLK_MHZ=50 SWEEP_JOBS=4 \
    ./scripts/sweep-ulx3s-85f.sh 1-32
```

For an already-synthesized netlist, add `SWEEP_SKIP_SYNTH=1`. This mode rejects
clock/video profile mismatches rather than silently routing the wrong netlist.
Sweep outputs go to separate `build/ulx3s-seed-sweep-50mhz-vga640-standard*/`
directories. Timing status checks the actual 50 MHz system PLL and the separate
25/125 MHz video clocks, not `--freq` alone. Neither a historical pass under
`--um5g-85k` nor a pass at the 25 MHz clock certifies the correct speed-grade-6
50 MHz configuration. Do not load an experimental failing bitstream into flash.
After a timing-passing seed is found, rerun the complete 50 MHz build with
`NEXTPNR_SEED` set to that seed to produce a matched monitor, bitstream, and
Doom image. The default 25 MHz build remains unchanged in its invocation.

The normal build writes canonical outputs in `build/`; back up any existing
qualified bitstream before building an experimental clock profile.

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

The 12F bitstream contains a small resident EBR bootstrap rather than the full
monitor. At cold boot it initializes the 115200-baud UART and prints instructions
for loading the SDRAM-resident monitor. After programming the FPGA, run:

```bash
./scripts/load-firmware-12f.sh
```

The helper reuses OpenOCD when port 3333 is already listening; otherwise it
starts the project OpenOCD launcher, waits for the GDB server, loads and verifies
the board-specific monitor, and stops only the OpenOCD instance it started.
The 12F build intentionally supports the standard 320x200 Doom/video path only.

### HDMI output resolution during seed sweeps

The physical HDMI raster is fixed by each board's current RTL and PLL:
ULX3S 85F uses `640x480`; ULX3S 12F and ULX4M-LD use `1024x600`.
ULX5M-GS is headless. GitHub Actions offers `board-default`, `640x480`, and
`1024x600` as its HDMI output resolution choices. The scripts reject a
resolution not implemented by the selected target instead of reporting a
misleading value. For local ECP5 sweeps, the optional
`SWEEP_HDMI_OUTPUT_RESOLUTION` variable accepts only the existing mode for
that board. This setting does not reconfigure the pixel/TMDS clocks or RTL.

This is separate from the internal Doom framebuffer resolution. The 85F
`HAZARD3_HDMI_EXTENDED_MODES` flag enables additional framebuffer modes,
not a different physical HDMI output raster.

### ULX3S 85F HDMI framebuffer profiles

The ULX3S 85F build supports a lean standard framebuffer and an extended profile.
The complete 85F wrapper defaults to extended modes enabled.

```bash
HAZARD3_HDMI_EXTENDED_MODES=0 ./scripts/build-ulx3s-85f-doom.sh
HAZARD3_HDMI_EXTENDED_MODES=1 ./scripts/build-ulx3s-85f-doom.sh
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
ulx5m-gs
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

SWEEP_ULX5M_HEAP_BETA=0.6 \
SWEEP_JOBS=8 \
    ./scripts/sweep-ecp5.sh ulx5m-gs 1-20
```

The target-specific scripts remain directly usable:

- `sweep-ulx3s-85f.sh` - ULX3S 85F sweep wrapper (selects 85F defaults).
- `sweep-ulx3s-12f.sh` - ULX3S 12F sweep wrapper (selects 12F defaults).
- `sweep-ulx3s-common.sh` - shared ULX3S synthesis, routing, and reporting driver.
- `sweep.sh` - backward-compatible alias for `sweep-ulx3s-85f.sh`.
- `sweep-ulx4m-ld.sh` - ULX4M-LD 85F full routed sweep.
- `sweep-ulx5m-gs.sh` - ULX5M-GS GateMate A1 full routed sweep.
- `sweep-peek.sh` - ULX3S 85F placement-only prescreen; uses the same 25/40/50 MHz and video profile selections and preserves separate result directories.
- `sweep-peek-ulx3s-12f.sh` - ULX3S 12F placement-only prescreen.
- `sweep-peek-ulx3s-12f-best-peek.sh` - routes selected strong 12F placement candidates.

All routed targets accept explicit seeds, comma-separated seeds, ranges such as
`1-32` or `750-1300`, or `--all`. There is no 512-seed limit on local ranges.
`--all` selects 1-512 by default; set `SWEEP_ALL_SEED_LAST=1024` to run
1-1024 instead. The seed values themselves must fit the positive signed
32-bit range (1-2147483647). Large sweeps consume substantial time and disk
space. `SWEEP_JOBS` controls local concurrency. Each target writes
`metadata.txt`, per-seed result CSV files, and an aggregate results CSV. A
sweep with zero timing-passing seeds exits nonzero, but retains all results.
The ULX3S and ULX5M-GS retain timing-passing routed bitstreams locally. ULX4M-LD
results are under `build/ulx4m-ld-seed-sweep/<clock>-<cpu><tuning>/`; ULX5M-GS
results are under `build/ulx5m-gs-seed-sweep-beta<value>/`.

Each nextpnr route is limited by `SWEEP_ROUTE_TIMEOUT_SECONDS`, which defaults
to 7200 seconds. `SWEEP_ROUTE_KILL_AFTER_SECONDS` defaults to 30 seconds and
allows a route that ignores `SIGTERM` to be killed. A timed-out route is
recorded with `timing_status=TIMEOUT` and the sweep continues with the remaining
seeds; it is not treated as a tool failure. For example:

```bash
SWEEP_ROUTE_TIMEOUT_SECONDS=900 \
    ./scripts/sweep-ecp5.sh ulx3s-85f 1-32
```

The GitHub seed-sweep workflow also applies a 7600-second whole-seed watchdog
around each `sweep-ecp5.sh` invocation. This is a second safety net for hangs
outside nextpnr itself; the normal nextpnr timeout should fire first.

The ECP5 routed targets accept the common nextpnr tuning controls below:

```bash
SWEEP_NEXTPNR_PLACER=heap
SWEEP_NEXTPNR_ROUTER=router2
SWEEP_NEXTPNR_HEAP_TIMINGWEIGHT=30
SWEEP_NEXTPNR_HEAP_CRITEXP=3
SWEEP_NEXTPNR_TMG_RIPUP=1
SWEEP_NEXTPNR_ROUTER2_ALT_WEIGHTS=1
SWEEP_NEXTPNR_EXTRA_ARGS='...'
```

ULX5M-GS uses GateMate Router2 with the HeAP placer. Its primary placement knob is
`SWEEP_ULX5M_HEAP_BETA`, which defaults to `0.6`; `SWEEP_NEXTPNR_EXTRA_ARGS` is
also passed through to `nextpnr-himbaechel`.

The GitHub workflow `.github/workflows/ulx4m-ld-seed-sweep.yml` is now a
parameterized FPGA seed-sweep workflow despite the retained historical filename.
Select the target and seed range with `workflow_dispatch`. GitHub Actions
limits the matrix to 256 route jobs; increasing `seeds_per_job` allows ranges
larger than 512 seeds, subject to the available job timeout. Individual timing
failures are recorded, while groups with no passing seeds fail CI. The prepare job
synthesizes one frozen netlist; route jobs use `SWEEP_SKIP_SYNTH=1` against that
exact netlist, and the final summary is generated by
`summarize-ecp5-sweep.py`. Synthesis and routing OSS CAD Suite snapshots can be
selected independently for nextpnr A/B testing. For ULX5M-GS the route jobs
use `nextpnr-himbaechel` plus `gmpack` and freeze both the CCF and SDC inputs.

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
- `load-firmware.sh` - Loads, verifies, starts, and disconnects a monitor ELF through a running GDB/OpenOCD server. With no argument it uses the standalone `build/hazard3-boot-monitor.elf`; complete board builds should pass the board-specific `build/<board>/monitor/hazard3-boot-monitor.elf` explicitly or use the matching `gdb/load-*-monitor.gdb` helper.
- `load-firmware-12f.sh` - Loads the ULX3S 12F SDRAM-resident monitor after FPGA configuration.
- `load-firmware.bat` - Windows monitor loader through GDB/OpenOCD.
- `load-fpga-bitstream.bat` - Windows FPGA bitstream loader.
- `flash-ulx3s-persistent.sh` - Programs the built ULX3S 85F bitstream into persistent SPI flash for cold boot; requires `build/fpga_ulx3s_85f.bit`.
- `hazard3-debug.gdb` - GDB command definitions used for source-level Hazard3 debugging through OpenOCD.
- `return-to-monitor.py` - Sends Ctrl-X over UART to stop a running Doom instance and return to the resident monitor; defaults to `/dev/ttyS7` at 115200 baud.
- `restart-from-monitor.py` - Sends monitor command `j` over UART to start the already loaded Doom image; defaults to `/dev/ttyS7` at 115200 baud.

### GDB command files

The `gdb/` directory contains focused command scripts for monitor and SAO tests.
Use the board-specific monitor helper that matches the complete board build; do
not substitute a generic or stale monitor ELF because the system clock, memory
map, linker placement, and loader protocol must match the FPGA configuration.

- `gdb/load-ulx3s-85f-monitor.gdb` - Load and verify `build/ulx3s-85f/monitor/hazard3-boot-monitor.elf`.
- `gdb/load-ulx3s-12f-monitor.gdb` - Load and verify the SDRAM-resident `build/ulx3s-12f/monitor/hazard3-boot-monitor.elf`.
- `gdb/load-ulx4m-ld-85f-monitor.gdb` - Load and verify `build/ulx4m-ld/monitor/hazard3-boot-monitor.elf`.
- `gdb/sao-probe.gdb` - Probe SAO bridge state from GDB.
- `gdb/sao-scan.gdb` - Exercise the SAO I2C scan path from GDB.
- `gdb/sao-touchwheel-test.gdb` - Interactive/debug test sequence for the SAO touchwheel.
- `gdb/sao-touchwheel-led-off.gdb` - Turns off the touchwheel LED from GDB.

## CoreMark and ELF Inspection

- `build-coremark.sh` - Builds the Hazard3 CoreMark port. Supports `baseline` and `tuned` build profiles, configurable iteration count, and supported 25/50 MHz timing profiles.
- `run-coremark.sh` - Runs or qualifies CoreMark images over the target UART. Supports `performance`, `validation`, and `qualify` modes and stores run logs/results under the CoreMark build directory.
- `peek-elf.sh` - Inspects a linked RISC-V ELF/map, selected multilib, ISA attributes, and libgcc/archive selection. With no arguments it examines the baseline CoreMark output.

## Validation, Repository Hygiene, and VisualGDB

- `refresh-version.sh` - Reads the repository-root `VERSION` file and regenerates the C and web version files. Use `--check` to verify that generated version files are current without changing them. Firmware builds refresh them automatically, and publish checks require them to match `VERSION`.
- `check-executable.sh` - Checks recently changed tracked shell scripts for the Git executable bit; defaults to the most recent five commits.
- `git-exe.sh` - Sets the Git executable bit for one tracked file and prints the resulting index entry.
- `check-nettype.sh` - Checks Git-tracked project RTL in `src/` and `tests/` for consistent `default_nettype` handling; vendored bootloader and submodule sources are excluded.
- `generate-ecp5-seed-matrix.py` - Generates grouped seed jobs for the ECP5 sweep workflow without embedding Python in workflow YAML.
- `test-scripts.sh` - Runs syntax, lint, and safe smoke checks across the top-level Bash, Python, PowerShell, Windows command, and GDB script files. Add `--integration` to execute complete board builds and routed two-seed samples for every ECP5 target. Integration logs and isolated software products are written below `build/script-tests/`; normal FPGA and sweep products remain below `build/`. Hardware programming, UART/GDB sessions, intentionally mutating checkout operations, and destructive cleanup are excluded. The runner verifies that tracked repository and submodule state is unchanged.

Fast validation and the longer integration sample are separate:

```bash
./scripts/test-scripts.sh
./scripts/test-scripts.sh --integration
./scripts/test-scripts.sh --integration --dry-run
```

The integration sample has its own two-seed timing-passing lists, defined in
`test-scripts.sh`: `11` and `178` for ULX3S 85F, `82` and `37` for ULX3S 12F,
and `83` and `45` for ULX4M-LD. These are integration-test inputs, not a second
definition of the board build defaults. Override
one list with `SCRIPT_TEST_ULX3S_85F_SEEDS`,
`SCRIPT_TEST_ULX3S_12F_SEEDS`, or `SCRIPT_TEST_ULX4M_LD_SEEDS`.
`SCRIPT_TEST_SWEEP_SEEDS` overrides all three lists, and
`SCRIPT_TEST_SWEEP_JOBS` sets route concurrency. For example:

```bash
SCRIPT_TEST_SWEEP_SEEDS="11 178" \
SCRIPT_TEST_SWEEP_JOBS=2 \
    ./scripts/test-scripts.sh --integration
```

Routed sweep commands now exit nonzero when none of their seeds meet timing,
so the integration test reports a failed routed-sweep command in that case.
`SCRIPT_TEST_REQUIRE_TIMING_PASS=1` also makes the integration CSV timing
check fail when no passing seed is found; it cannot override the routed
sweep's own exit status.
- `check-windows-visualgdb.ps1` - Validates the native-Windows VisualGDB/NMake configuration and expected xPack monitor build commands.
- `check-wsl-visualgdb.ps1` - Validates the WSL VisualGDB bridge, expected build/debug paths, and LF-only tracked shell scripts.
- `inventory.sh` - Inventories Git-tracked files in the selected path and writes deterministic Markdown, TSV, and SHA-256 reports. It intentionally uses Git's index instead of walking ignored/untracked toolchains. The human-readable inventory records the project release from the root `VERSION` file.
- `INVENTORY.md` - Human-readable generated inventory for the scripts directory.
- `INVENTORY.tsv` - Machine-readable generated inventory.
- `INVENTORY.sha256` - SHA-256 list for the generated inventory set.
- `full-clean.sh` - Cleans supported FPGA synthesis targets and removes the repository `build/` tree. Use `--dry-run` to preview; submodules, WADs, and checked-in LiteDRAM sources are preserved.

## Setup and Toolchain Helpers

- `full-install.sh` - Ensures the development environment is usable without replacing compatible tools unnecessarily. It reuses a supported RISC-V toolchain, CMake 3.28 or newer, qualified Yosys/nextpnr/Project Trellis tools, and an available OpenOCD installation. OSS CAD Suite is installed only when qualified FPGA tools are missing or incompatible. Use `--install-oss-cad-suite` to force the managed OSS CAD Suite release, or `--fpga-tools-from-source` to force the pinned source builds.
- `install-riscv-toolchain.sh` - Reuses a compatible RISC-V bare-metal toolchain when one is already available and otherwise installs xPack `riscv-none-elf-gcc` under `~/.local/xPacks`. Build scripts prefer supported prefixes on `PATH`, retain the historical `/opt/riscv/bin/riscv32-unknown-elf-*` location as a compatibility fallback, and let an explicit `TOOLCHAIN_PREFIX` take precedence. Ubuntu/Debian `riscv64-unknown-elf-*` toolchains use Picolibc when the matching package/specs are installed.
- `setup-xpack-riscv-gcc.cmd` - Installs/configures the xPack GNU RISC-V Embedded GCC toolchain under `bin/riscv-gcc` for native Windows builds.

### Safe validation after toolchain changes

Do not use `full-install.sh` as the first regression test on an established machine. Start with the non-mutating requirements check and the real Doom build.

For native Ubuntu/Debian Linux using the distro RISC-V toolchain:

```bash
command -v riscv64-unknown-elf-gcc
dpkg -s picolibc-riscv64-unknown-elf | grep '^Status:'
./scripts/requirements-check.sh
./scripts/install-riscv-toolchain.sh
./scripts/build-doom-noncombat.sh
./scripts/test-scripts.sh
```

The installer check should report that the existing `riscv64-unknown-elf-` toolchain is reused and xPack is skipped. The Doom build should report `Target C runtime: picolibc` and produce `build/doom-image-noncombat/hazard3-doom.h3img`.

For WSL systems that already use the historical `/opt/riscv` Newlib toolchain, test the toolchain actually present instead of assuming a distro prefix:

```bash
command -v /opt/riscv/bin/riscv32-unknown-elf-gcc
/opt/riscv/bin/riscv32-unknown-elf-gcc --version
./scripts/requirements-check.sh
./scripts/install-riscv-toolchain.sh
./scripts/build-doom-noncombat.sh
./scripts/test-scripts.sh
```

Run `./scripts/full-install.sh` afterward only when testing installer idempotence or setting up a machine. On an already-qualified environment it should report that compatible CMake, FPGA tools, OpenOCD, and the RISC-V toolchain are being reused.

## Supercon Helpers

The normal Hazard3-Doom build remains unchanged by the Supercon helper flow.
The demo uses a dedicated noncombat image and a separately generated WAD.

- `build-doom-noncombat.sh` - Builds `build/doom-image-noncombat/hazard3-doom.h3img` with the dedicated noncombat source transform and verifies marker symbols in the compiled objects.
- `apply-doom-noncombat.py` - Internal transform applied only to the prepared DoomGeneric build copy; it does not edit the submodule.
- `build-supercon10-wad.py` - Verifies the Supercon PWAD, merges it with a local `wads/DOOM1.WAD`, verifies expected banner textures, and writes `wads/SUPERCON10.WAD` by default.
- `cleanup-supercon-dev.py.bak` - Retained backup of an older development cleanup helper; it is not part of the normal supported workflow.

Example:

```bash
./scripts/build-doom-noncombat.sh
./scripts/build-supercon10-wad.py
./scripts/return-to-monitor.py --port /dev/ttyS7
./doom/upload-doom-image.py ./build/doom-image-noncombat/hazard3-doom.h3img --port /dev/ttyS7
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

### ULX3S 85F experimental dual-port EBR SRAM timing mode

The verified 50 MHz seed-11 timing experiments produced 30.37 MHz with the
original cache response, 35.74 MHz with registered cache hits and SRAM write
buffering, and 35.15 MHz with registered hits and write buffering disabled.
These are FAIL results for a 50 MHz speed-grade-6 target. Do not run a large
seed sweep before checking the critical path of a new architectural variant.

`HAZARD3_ULX3S_85F_SRAM_DUAL_PORT_RW=1` selects a new, opt-in adapter with
independent synchronous EBR read and write ports. A bypass merges bytes from
a simultaneous read of the word being written. It removes the live AHB read
address/HTRANS condition from the RAM write-enable path; the separate read
address and collision check may still be critical. This is NOT timing or
hardware qualified. Default 0 preserves the original adapter, and ULX3S 12F
and ULX4M are unchanged. The option requires `SRAM_WRITE_BUFFER=1` (the
original default), so the no-buffer experiment is kept separate.

Before an FPGA build, check functional behavior with Icarus Verilog in WSL:

```bash
cd /mnt/c/workspace/Hazard3-Doom
iverilog -g2012 -DSIM -s tb_ulx3s_sram_dualport \
  -o /tmp/tb_ulx3s_sram_dualport.vvp \
  tests/tb_ulx3s_sram_dualport.v \
  third_party/Hazard3/example_soc/libfpga/mem/ahb_sync_sram.v \
  third_party/Hazard3/example_soc/libfpga/mem/sram_sync.v
vvp /tmp/tb_ulx3s_sram_dualport.vvp
```

Expected result: `PASS: ... AHB cycles; original and dual-port SRAM match
reference`. A failing or unavailable simulation must not be treated as a pass.
The regression covers partial writes and read/write collisions but is not a
complete proof of all AHB stall/error or cold-boot cases.

After a simulation PASS, run one correct-device routed build:

```bash
HAZARD3_ULX3S_85F_SYS_CLK_MHZ=50 \
HAZARD3_ULX3S_85F_REGISTERED_READ_HITS=1 \
HAZARD3_ULX3S_85F_SRAM_WRITE_BUFFER=1 \
HAZARD3_ULX3S_85F_SRAM_DUAL_PORT_RW=1 \
NEXTPNR_SEED=11 ./scripts/build-ulx3s-85f-doom.sh
```

Compare the last `clk_sys` reported in `build/fpga_ulx3s_85f.pnr.log`
against the original registered-hit 35.74 MHz result. Only if the new Fmax
approaches 50 MHz should you attempt a small, fully routed seed sweep using
exactly the same environment settings. Build and sweep scripts stamp the
experimental option and refuse to reuse a mismatched frozen netlist.
Do not program flash or treat any timing-failing bitstream as qualified.


### ULX3S 85F experimental registered SDRAM cache tag lookup (November 2026)

The November 14 seed-11 50 MHz build with registered cache hits and the
independent EBR SRAM read/write ports passed its 4010-cycle SRAM adapter
simulation and routed at 39.32 MHz, still **FAIL** against 50 MHz on the
LFE5U-85F speed grade 6. The next opt-in experiment adds a register after the
SDRAM cache's synchronous tag RAM lookup. It registers hit/miss status, dirty
status, selected way, and dirty victim address before downstream bus control.
The writeback cache's original behaviour is retained when the parameter is 0.

The extra lookup stage introduces one additional AHB stall cycle on cached
lookups, even hits. This changes memory latency and needs functional and
performance validation; no 50 MHz timing closure is implied. No ULX3S 12F,
ULX4M, or ULX5M top-level configuration enables this experiment by default.

Select it only alongside registered cache-hit responses. Retain the previously
successful independent SRAM R/W port configuration for comparison:

```bash
cd /mnt/c/workspace/Hazard3-Doom

HAZARD3_ULX3S_85F_SYS_CLK_MHZ=50 \
HAZARD3_ULX3S_85F_REGISTERED_READ_HITS=1 \
HAZARD3_ULX3S_85F_SRAM_WRITE_BUFFER=1 \
HAZARD3_ULX3S_85F_SRAM_DUAL_PORT_RW=1 \
HAZARD3_ULX3S_85F_CACHE_TAG_PIPELINE=1 \
NEXTPNR_SEED=11 \
./scripts/build-ulx3s-85f-doom.sh
```

The build and both sweep scripts stamp `fpga_ulx3s_85f.cache-tag-pipeline`,
reject mismatched frozen netlists, and separate timing results by `tagp0` or
`tagp1`. This is *not* a timing-allow-fail production build. The timing model
remains `--85k --speed 6` and all clocks must pass.

First run the cache regression with Icarus Verilog:

```bash
cd /mnt/c/workspace/Hazard3-Doom
iverilog -g2012 -DSIM -DHAS_REGISTERED_READ_HITS \
  -s tb_ulx3s_cache_tag_pipeline \
  -o /tmp/tb_ulx3s_cache_tag_pipeline.vvp \
  tests/tb_ulx3s_cache_tag_pipeline.v \
  third_party/Hazard3/example_soc/libfpga/mem/ahb_cache_writeback.v \
  third_party/Hazard3/example_soc/libfpga/mem/cache_mem_set_associative.v \
  third_party/Hazard3/example_soc/libfpga/mem/ahb_sync_sram.v \
  third_party/Hazard3/example_soc/libfpga/mem/sram_sync.v
vvp /tmp/tb_ulx3s_cache_tag_pipeline.vvp
```

A `PASS` for both pipeline modes is necessary before proceeding to a single
seed-11 synthesis/route. The test covers read/write hits and misses, partial
writes and dirty evictions, but is not a replacement for SoC-level simulation,
physical RAM collision testing, Doom operation, or hardware qualification.
Do not flash an unqualified 50 MHz image.


### ULX3S 85F fast tag-RAM write-data experiment (November 2026)

The 50 MHz seed-11 design with cache tag pipeline enabled reported 36.84 MHz.
The final path started at Hazard3 `m_result`, crossed CPU/debug and the AHB
address multiplexers, and ended on the SDRAM cache tag RAM `DIA5` write-data
input (27.14 ns total, including 21.89 ns routing). The registered tag-hit
experiment did not cut this write-data path.

`HAZARD3_ULX3S_85F_TAG_RAM_MODE` selects the new opt-in implementation:

- `0`: original shared cache tag RAM and combinational write tag (default).
- `1`: shared tag RAM using the tag captured at the previous cache lookup.
- `2`: same registered tag, but one RAM per cache way, each with an independent
  write enable; avoids the read-modify-write mux for unselected ways. Only use
  with the zero-filled ULX3S tag preload file. Nonzero preload files would
  need to be split into one file per way first.

For the speed-grade-6 experiment, retain the best tested SRAM/cache settings
(`REGISTERED_READ_HITS=1`, `SRAM_WRITE_BUFFER=1`, `SRAM_DUAL_PORT_RW=1`) and
turn the unsuccessful `CACHE_TAG_PIPELINE` option back off (`0`). Test
`TAG_RAM_MODE=2` first, using the `tests/tb_ulx3s_fast_tag_ram.v` regression
and a single nextpnr seed. A change to tag RAM mode invalidates the saved
netlist and makes its own sweep directory (`trm0`, `trm1`, or `trm2`). The
qualified 25 MHz profile and the ULX3S 12F retain mode `0`.

The change targets a measured path, but no 50 MHz route is yet verified.

### ULX3S 85F AHB cache address pipeline experiment (November 2026)

The speed-grade-6 seed-11 route with `TAG_RAM_MODE=2` failed at 35.82 MHz.
Its critical path ends at cache **data** RAM pin `ADA1` (27.92 ns total,
6.47 ns logic + 21.45 ns routing). The cache previously drove that RAM
address directly from the live AHB address bus.

`HAZARD3_ULX3S_85F_CACHE_ADDR_PIPELINE=1` adds an AHB wait cycle for
cacheable accesses: the cache captures the address in its existing
`src_addr_dphase` register, then reads synchronous tag/data RAM in a new
`S_READ_LOOKUP` / `S_WRITE_LOOKUP` state. The RAM address mux no longer
depends on `src_haddr`. It requires registered cache hits, is disabled by
default, and does not change 12F. This mode is unqualified until simulation,
routing and board-level testing pass.

For the next comparison, use the best previously measured settings:

```bash
HAZARD3_ULX3S_85F_SYS_CLK_MHZ=50 \
HAZARD3_ULX3S_85F_REGISTERED_READ_HITS=1 \
HAZARD3_ULX3S_85F_SRAM_WRITE_BUFFER=1 \
HAZARD3_ULX3S_85F_SRAM_DUAL_PORT_RW=1 \
HAZARD3_ULX3S_85F_CACHE_TAG_PIPELINE=0 \
HAZARD3_ULX3S_85F_TAG_RAM_MODE=0 \
HAZARD3_ULX3S_85F_CACHE_ADDR_PIPELINE=1 \
NEXTPNR_SEED=11 ./scripts/build-ulx3s-85f-doom.sh
```

For the AHB cache address-stage regression, run `tests/tb_ulx3s_cache_addr_pipeline.v`
with `iverilog -g2012 -DSIM -DHAS_REGISTERED_READ_HITS`, the cache RTL,
`cache_mem_set_associative.v`, `ahb_sync_sram.v`, and `sram_sync.v`.

## ECP5 experimental sweep options

Local ECP5 sweeps and the `FPGA seed sweep` workflow accept the same
settings. Unset settings retain the established board defaults:

| Board | Device | Speed | Package | System / video / TMDS (MHz) |
| --- | --- | --- | --- | --- |
| ULX3S 85F | `--85k` | 6 | CABGA381 | 25 / 25 / 125 |
| ULX3S 12F | `--12k` | 6 | CABGA381 | 40 / 50 / 250 |
| ULX4M-LD 85F | `--um-85k` | 8 | CABGA381 | 40 / 50 / 250 |

By default, the ULX3S 12F uses `LFE5U-12F-6`, the ULX3S 85F uses
`LFE5U-85F-6`, and ULX4M-LD uses `LFE5UM-85F-8`. These are **board
baselines**; the chip fitted to an individual unit may differ.

Set `ECP5_PNR_DEVICE` to the exact device family/capacity/speed, such as
`LFE5UM5G-85F-8`, for local builds and sweeps. GitHub Actions offers the
same choice as the single `ecp5_fpga_part` dropdown. The selection changes
nextpnr's device/timing model **and** ecppack's JTAG IDCODE. It does not
change the RTL, physical clock, or the installed chip. Do not use a faster
chip model to qualify a slower chip's bitstream.

`ECP5_PNR_SPEED_GRADE=6|7|8` remains available for local, same-family
speed-only experiments. Omit `ECP5_PNR_DEVICE` when using this override;
if both are supplied, they must agree. The optional `ECP5_PNR_PACKAGE`
continues to default to `CABGA381`. A different family/package must be
verified for physical pin and electrical compatibility with the board.

The ECP5-5G (`LFE5UM5G`) family supports speed grade 8 only. In particular,
`LFE5U-85F-8` and `LFE5UM5G-85F-8` have **different timing models**.
The 12F and 85F sweep entry points retain their original filenames but now
call `sweep-ulx3s-common.sh`. This shared driver handles seed parsing, routing,
bitstream packaging and CSV reporting. Board-specific synthesis and validation
remain explicit: the 12F keeps its fixed 40 MHz PLL, memory profile and 32-EBR
limit; the 85F keeps its selectable clock, cache/SRAM synthesis stamps, and
physical clock PASS checks. Changing `ECP5_PNR_DEVICE` selects the actual chip,
not a different board configuration. ULX4M-LD is unchanged by this refactor.

For the **physical** ULX3S 85F or ULX4M system clock, use
`HAZARD3_ULX3S_85F_SYS_CLK_MHZ` (25, 40, 50) or
`HAZARD3_ULX4M_SYS_CLK_MHZ` (25, 40, 50). These options control the
existing supported RTL clock profiles. ULX3S 12F remains fixed at 40 MHz.

`SWEEP_SYS_TARGET_MHZ`, `SWEEP_VIDEO_TARGET_MHZ`, and
`SWEEP_TMDS_TARGET_MHZ` accept decimal MHz for metadata and reporting.
ULX4M also accepts `SWEEP_LITEDRAM_TARGET_MHZ` and
`SWEEP_INIT_TARGET_MHZ` (defaults 60.01 and 25.00). Matching workflow
inputs have lower-case names. None of these overrides changes the physical
PLL frequencies or nextpnr constraints.

**ULX3S 85F routed sweeps:** `timing_status=PASS` requires both nextpnr's
PASS verdict for all three clocks **and** reported Fmax at or above the
physical 25/40/50 MHz system-clock profile, 25 MHz video, and 125 MHz TMDS.
The three `SWEEP_*_TARGET_MHZ` values are also enforced if they are higher;
setting them lower cannot weaken the physical clock requirements. Missing,
non-numeric, or below-target frequencies produce `timing_status=FAIL`.
Other board sweep scripts still rely on nextpnr's clock verdict; the CI
summarizer independently checks their reported MHz targets. No reporting
override by itself is evidence of timing qualification.

Examples (experimental device selection; physical clocks unchanged):

```bash
ECP5_PNR_DEVICE=LFE5UM5G-85F-8 SWEEP_JOBS=4 ./scripts/sweep-ulx3s-85f.sh 11
ECP5_PNR_SPEED_GRADE=6 SWEEP_JOBS=4 ./scripts/sweep-ulx4m-ld.sh 1-32
```

Default-device sweep directories remain unchanged. Different chip families,
speed grades, or packages create separate sweep output directories so a 5G
PASS cannot be confused with an ordinary ECP5 route. The selected part and
IDCODE are recorded in per-sweep metadata.
