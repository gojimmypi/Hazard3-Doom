# Hazard3-Doom Scripts

Build, setup, programming, debugging, validation, and cleanup utilities for the
Hazard3-Doom ULX3S and ULX4M-LD targets.

## Quick Start

- `build-ulx3s-doom.sh` - Builds the complete ULX3S 85F Doom target: bitstream, monitor, and Doom image.
- `build-ulx3s-12f-doom.sh` - Builds the compact ULX3S 12F target with SDRAM line-buffered HDMI.
- `build-ulx4m-ld-doom.sh` - Builds the complete ULX4M-LD Doom target: bitstream, monitor, and Doom image.

Existing nonempty FPGA bitstreams are reused and displayed with their modification
timestamps. Set `FORCE_BITSTREAM_REBUILD=1` to run synthesis and nextpnr again.

See the full Quick Start overview at https://ulx3s.github.io/ulx-doom/  

## Build Scripts

- `build.sh` - Builds the shared Hazard3 monitor firmware.
- `build-ulx3s-85f-bitstream.sh` - Builds or reuses the ULX3S 85F FPGA bitstream.
- `build-ulx3s-doom.sh` - Builds the complete ULX3S 85F Doom target.
- `build-ulx3s-12f-bitstream.sh` - Builds or reuses the ULX3S 12F FPGA bitstream.
- `build-ulx3s-12f-doom.sh` - Builds the complete compact ULX3S 12F target.
- `build-ulx4m-ld-bitstream.sh` - Builds or reuses the ULX4M-LD 85F FPGA bitstream.
- `build-ulx4m-ld-doom.sh` - Builds the complete ULX4M-LD Doom target.
- `build-xpack.cmd` - Builds the Hazard3 firmware on Windows using the configured xPack RISC-V GCC toolchain.
- `sweep-peek.sh` - Runs a placement-only nextpnr seed scan without routing or bitstream generation. Use it to quickly rank candidate seeds before a full sweep.
- `sweep.sh` - Runs the full FPGA build, placement, routing, timing analysis, and bitstream generation for every configured nextpnr seed.

### ULX3S 12F compact target

The 12F and 85F use the same ULX3S board wrapper, pin constraints, clocks, CPU
ISA, SD interface and SAO/ESP32 peripherals. The 12F device profile changes only
the EBR-heavy storage architecture: the monitor and completed video frames move
to external SDRAM, the unified cache is 32 KiB, and HDMI uses two small line
buffers plus the existing indexed palette RAM.

Build the default 64 MiB SDRAM profile with:

```bash
./scripts/build-ulx3s-12f-doom.sh
```

For a 32 MiB SDRAM population, keep FPGA, monitor and Doom maps matched:

```bash
HAZARD3_MEMORY_PROFILE=32m ./scripts/build-ulx3s-12f-doom.sh
```

The 12F does not have enough EBR for the resident 85F monitor. After programming
the FPGA and starting OpenOCD, load the monitor into its uncached SDRAM region:

```bash
./scripts/load-firmware-12f.sh
```

The normal monitor UART, SD, SAO and Doom workflows then apply. The 12F profile
intentionally supports the standard 320x200 Doom/video path only; 400x240 Doom
and 512x300 GUI modes remain features of the larger framebuffer profile.

### ULX3S HDMI framebuffer profiles

The ULX3S build supports two framebuffer hardware profiles. The default
`extended` profile preserves the 400x240 experimental source and packed 512x300
GUI source. For unrelated FPGA development, select the lean `standard` profile
to synthesize only the double-buffered 320x200 framebuffer:

```bash
HAZARD3_HDMI_EXTENDED_MODES=0 ./scripts/build-ulx3s-doom.sh
```

Use the extended profile explicitly when testing 400x240 or 512x300 video:

```bash
HAZARD3_HDMI_EXTENDED_MODES=1 ./scripts/build-ulx3s-doom.sh
```

The standard profile instantiates 64 framebuffer DP16KD banks instead of 95.
The build records the active profile and automatically invalidates an existing
synthesized ULX3S netlist when the requested profile changes.

## Seed Sweep Workflow

Use `sweep-peek.sh` as a fast screening pass before running the much more
expensive full `sweep.sh`.

`sweep-peek.sh` reuses the existing synthesized `fpga_ulx3s.json`, runs the
same simulated-annealing placer and ULX3S 85F device selection used by the
normal build, and stops before routing with `--no-route`. It records estimated
placement timing for `clk_sys`, `clk_video_pix`, and `clk_tmds_x5`.

From the repository root, run one seed for calibration or investigation:

```bash
./scripts/sweep-peek.sh 178
```

With no seed parameter, it scans seeds 1 through 260:

```bash
./scripts/sweep-peek.sh
```

Single-seed results are written under
`third_party/Hazard3/example_soc/synth/placement-sweep/` as
`results-seed-<seed>.csv`. A complete placement sweep writes
`placement-sweep/results.csv`; individual nextpnr logs are saved as
`placement-sweep/seed-<seed>.log`.

Placement-only timing is a screening result, not final timing. A promising
placement can still fail during routing. Rank the `sweep-peek.sh` results,
select the strongest candidates, and then use the full routing flow to
determine actual timing PASS/FAIL.

`sweep.sh` is the authoritative full sweep. It rebuilds the resident monitor
image used by the cold-boot FPGA netlist, runs complete FPGA place-and-route
for each seed, and preserves each `pnr.log` and generated `.bit` file under
`build/ulx3s-seed-sweep/`.

In short:

```text
sweep-peek.sh
    placement only
    no routing
    no bitstream
    fast candidate ranking
        |
        v
select strongest seeds
        |
        v
sweep.sh
    full placement and routing
    final timing PASS/FAIL
    generated bitstreams
```

Run a new seed search whenever the FPGA netlist changes materially. A seed that
was optimal for an earlier design is not guaranteed to remain optimal after
changes such as framebuffer size, EBR usage, or other FPGA resource changes.

## Setup Scripts

- `doomgeneric-version.sh` - Defines the pinned DoomGeneric repository and commit.
- `setup-doomgeneric.sh` - Validates the pinned DoomGeneric checkout and required source files.
- `setup-submodules.sh` - Initializes the repository submodules required for building.
- `setup-xpack-riscv-gcc.cmd` - Configures and validates the xPack RISC-V GCC toolchain used by the Windows scripts.

## Programming and Debugging

- `hazard3-debug.gdb` - Provides GDB commands for connecting to and debugging Hazard3 through OpenOCD.
- `load-firmware.bat` - Loads and starts the monitor firmware through GDB and OpenOCD on Windows.
- `load-firmware.sh` - Loads and starts the monitor firmware through GDB and OpenOCD on Linux or WSL.
- `load-firmware-12f.sh` - Loads the ULX3S 12F SDRAM-resident monitor after FPGA configuration.
- `load-fpga-bitstream.bat` - Programs the FPGA with a generated or prebuilt bitstream on Windows.
- `start-openocd.bat` - Starts the OpenOCD server with the repository configuration on Windows.
- `start-openocd.sh` - Starts the OpenOCD server with the repository configuration on Linux or WSL.

## Validation and Cleanup

- `check_submodules.bat` - Reports the current and expected Git submodule revisions on Windows.
- `check-nettype.sh` - Checks Verilog sources for consistent `default_nettype` directives.
- `full-clean.sh` - Removes generated ULX3S, ULX4M-LD, monitor, and Doom build outputs.

## Supercon Helpers

The normal Hazard3-Doom build remains normal. The Supercon demo uses a separate,
explicit noncombat image and one canonical WAD source.

- `build-doom-noncombat.sh` - builds `build/doom-image-noncombat/hazard3-doom.h3d` with 200% armor, zero ammo, no pistol ownership, no weapon/fist overlay, and Fire disabled.
- `apply-doom-noncombat.py` - internal transform used only on the generated DoomGeneric build copy.
- `build-supercon10-wad.py` - verifies the fixed-heading PWAD and merges it with local `wads/DOOM1.WAD` into `wads/SUPERCON10.WAD`.
- `return-to-monitor.py` - sends Ctrl-X over UART and releases the serial port.
- `cleanup-supercon-dev.py` - dry-run cleanup for exact obsolete files from earlier iterations; add `--apply` only after reviewing the list.

From the repository root:

```bash
./scripts/build-doom-noncombat.sh
./scripts/build-supercon10-wad.py

./scripts/return-to-monitor.py --port /dev/ttyS7
./doom/upload-doom-image.py ./build/doom-image-noncombat/hazard3-doom.h3d --port /dev/ttyS7
./doom/upload-wad.py ./wads/SUPERCON10.WAD --port /dev/ttyS7 --launch
```

The normal Doom image still builds to `build/doom-image/hazard3-doom.h3d`.

## Documentation

- `README.md` - Describes every build, setup, programming, debugging, validation, and cleanup file in this directory.
