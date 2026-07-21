# Hazard3-Doom Scripts

Build, setup, programming, debugging, and cleanup utilities for the Hazard3-Doom ULX3S and ULX4M-LD targets.

## Quick Start

- `build-ulx3s-doom.sh` - Builds the complete ULX3S Doom target: bitstream, monitor, and Doom image.
- `build-ulx4m-ld-doom.sh` - Builds the complete ULX4M-LD Doom target.

Existing nonempty FPGA bitstreams are reused and displayed with their modification
timestamps. Set `FORCE_BITSTREAM_REBUILD=1` to run synthesis and nextpnr again.

## Other Scripts

- `build.sh` - Builds the shared Hazard3 monitor firmware.
- `build-ulx3s-85f-bitstream.sh` - Builds or reuses the ULX3S 85F FPGA bitstream.
- `build-ulx4m-ld-bitstream.sh` - Builds or reuses the ULX4M-LD 85F FPGA bitstream.
- `doomgeneric-version.sh` - Defines the pinned DoomGeneric repository and commit.
- `full-clean.sh` - Removes generated ULX3S, ULX4M-LD, monitor, and Doom build outputs.
- `hazard3-debug.gdb` - Provides GDB commands for connecting to and debugging Hazard3 through OpenOCD.
- `load_firmware.sh` - Loads and starts the monitor firmware through GDB and OpenOCD.
- `setup-doomgeneric.sh` - Validates the pinned DoomGeneric checkout and required source files.
- `setup-submodules.sh` - Initializes the repository submodules required for building.
- `sweep.sh` - Forces a rebuild for each nextpnr seed and saves every timing result and bitstream.
