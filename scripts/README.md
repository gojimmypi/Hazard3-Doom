# Hazard3-Doom Scripts

Build, setup, programming, debugging, validation, and cleanup utilities for the
Hazard3-Doom ULX3S and ULX4M-LD targets.

## Quick Start

- `build-ulx3s-doom.sh` - Builds the complete ULX3S Doom target: bitstream, monitor, and Doom image.
- `build-ulx4m-ld-doom.sh` - Builds the complete ULX4M-LD Doom target: bitstream, monitor, and Doom image.

Existing nonempty FPGA bitstreams are reused and displayed with their modification
timestamps. Set `FORCE_BITSTREAM_REBUILD=1` to run synthesis and nextpnr again.

## Build Scripts

- `build.sh` - Builds the shared Hazard3 monitor firmware.
- `build-ulx3s-85f-bitstream.sh` - Builds or reuses the ULX3S 85F FPGA bitstream.
- `build-ulx3s-doom.sh` - Builds the complete ULX3S Doom target.
- `build-ulx4m-ld-bitstream.sh` - Builds or reuses the ULX4M-LD 85F FPGA bitstream.
- `build-ulx4m-ld-doom.sh` - Builds the complete ULX4M-LD Doom target.
- `build-xpack.cmd` - Builds the Hazard3 firmware on Windows using the configured xPack RISC-V GCC toolchain.
- `sweep.sh` - Forces a rebuild for each nextpnr seed and saves every timing result and bitstream.

## Setup Scripts

- `doomgeneric-version.sh` - Defines the pinned DoomGeneric repository and commit.
- `setup-doomgeneric.sh` - Validates the pinned DoomGeneric checkout and required source files.
- `setup-submodules.sh` - Initializes the repository submodules required for building.
- `setup-xpack-riscv-gcc.cmd` - Configures and validates the xPack RISC-V GCC toolchain used by the Windows scripts.

## Programming and Debugging

- `hazard3-debug.gdb` - Provides GDB commands for connecting to and debugging Hazard3 through OpenOCD.
- `load-firmware.bat` - Loads and starts the monitor firmware through GDB and OpenOCD on Windows.
- `load-firmware.sh` - Loads and starts the monitor firmware through GDB and OpenOCD on Linux or WSL.
- `load-fpga-bitstream.bat` - Programs the FPGA with a generated or prebuilt bitstream on Windows.
- `start-openocd.bat` - Starts the OpenOCD server with the repository configuration on Windows.
- `start-openocd.sh` - Starts the OpenOCD server with the repository configuration on Linux or WSL.

## Validation and Cleanup

- `check_submodules.bat` - Reports the current and expected Git submodule revisions on Windows.
- `check-nettype.sh` - Checks Verilog sources for consistent `default_nettype` directives.
- `full-clean.sh` - Removes generated ULX3S, ULX4M-LD, monitor, and Doom build outputs.

## Documentation

- `README.md` - Describes every build, setup, programming, debugging, validation, and cleanup file in this directory.
