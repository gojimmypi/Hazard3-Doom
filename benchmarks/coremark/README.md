# CoreMark on Hazard3 ULX3S

This directory contains the Hazard3-Doom ULX3S bare-metal port used to run
CoreMark on the Hazard3 soft CPU implemented in the ULX3S FPGA design.

The benchmark workload sources are not duplicated here. The build uses the
CoreMark sources already present in the pinned Hazard3 tree at:

```text
third_party/Hazard3/test/sim/coremark/dist
```

The ULX3S-specific files in this directory provide startup, timing, UART output,
linking, and host-side result capture.

## Source and attribution

The Hazard3 ULX3S CoreMark port and its support code were based on and adapted
from the CoreMark simulation integration in Luke Wren's upstream Hazard3
repository:

- Hazard3 repository: <https://github.com/Wren6991/Hazard3>
- Upstream Hazard3 CoreMark simulation:
  <https://github.com/Wren6991/Hazard3/tree/stable/test/sim/coremark>

In particular, the port follows the upstream Hazard3 approach for CoreMark
platform support and cycle-counter timing. Hazard3 resets `mcycle` and
`minstret` inhibited; the ULX3S startup therefore enables them through
`mcountinhibit` before the benchmark starts.

CoreMark itself is maintained by EEMBC/SPEC Embedded Group:

- Official CoreMark repository: <https://github.com/eembc/coremark>
- CoreMark project page: <https://www.eembc.org/coremark/>

CoreMark is a registered trademark. Refer to the official CoreMark repository
for the benchmark license, acceptable-use terms, and reporting requirements.
Refer to the Hazard3 repository for the Hazard3 license and attribution terms.

## Files in this port

```text
benchmarks/coremark/
    README.md
    core_portme.c
    core_portme.h
    ee_printf.c
    link.ld
    run_coremark.py
    start.S

scripts/
    build-coremark.sh
    run-coremark.sh
```

The benchmark workload files such as `core_main.c`, `core_list_join.c`,
`core_matrix.c`, `core_state.c`, and `core_util.c` are taken directly from the
pinned Hazard3 CoreMark `dist` directory during the build and are not modified
by this port.

## Current ULX3S CPU target

The current build targets the Hazard3 ISA implemented by the ULX3S design:

```text
RV32IMC_Zicsr_Zifencei_Zba_Zbb_Zbs
```

The compiler setting is:

```text
-march=rv32imc_zicsr_zifencei_zba_zbb_zbs
-mabi=ilp32
```

The default CPU clock used by the benchmark is 50 MHz.

## Prerequisites

Before running CoreMark:

1. Program the ULX3S with the matching Hazard3 FPGA bitstream.
2. Initialize the Hazard3 and CoreMark dependencies/submodules.
3. Ensure the RISC-V GCC toolchain is available. The default prefix is:

   ```text
   /opt/riscv/bin/riscv32-unknown-elf-
   ```

4. Start OpenOCD using the Hazard3 ULX3S configuration.
5. Connect the external UART used by the Hazard3 design. The benchmark uses
   115200 baud, 8 data bits, no parity, and 1 stop bit.

## Build

From the Hazard3-Doom repository root:

```bash
./scripts/build-coremark.sh
```

The default baseline build creates both the performance and validation images:

```text
build/coremark/baseline/coremark-performance.elf
build/coremark/baseline/coremark-validation.elf
```

The baseline profile uses `-O2` and the same implemented ISA extensions listed
above.

### Tuned build

A separate tuned profile is available for performance comparison:

```bash
COREMARK_BUILD_PROFILE=tuned ./scripts/build-coremark.sh
```

The tuned images are written to:

```text
build/coremark/tuned/coremark-performance.elf
build/coremark/tuned/coremark-validation.elf
```

The tuned profile uses `-O3` plus Hazard3-oriented GCC optimization options. It
does not enable ISA extensions that are not implemented by the ULX3S CPU.

## Start OpenOCD

Run OpenOCD in a separate terminal and leave it running:

```bash
./bin/openocd.exe -d2 \
    -f ./third_party/Hazard3/example_soc/ulx3s-openocd.cfg
```

A normal connection should include output similar to:

```text
Examined RISC-V core; found 1 harts
hart 0: XLEN=32, misa=0x40801106
Listening on port 3333 for gdb connections
```

## Run the performance benchmark

With OpenOCD running, execute:

```bash
./scripts/run-coremark.sh performance /dev/ttyS7
```

Replace `/dev/ttyS7` with the UART device connected to the board.

The runner opens the UART, loads the standalone CoreMark ELF through the
existing Hazard3 GDB loader, captures the benchmark output, and prints a
summary including the measured cycles, elapsed time, CoreMark/s, and
CoreMark/MHz.

A valid performance run must execute for at least 10 seconds. The default is:

```text
COREMARK_ITERATIONS=3000
TOTAL_DATA_SIZE=2000
HAZARD3_SYS_CLK_HZ=50000000
```

If a different hardware/compiler configuration completes in less than 10
seconds, increase the iteration count, for example:

```bash
COREMARK_ITERATIONS=4000 ./scripts/build-coremark.sh
./scripts/run-coremark.sh performance /dev/ttyS7
```

## Run validation

After the performance run, execute the independent validation seed set:

```bash
./scripts/run-coremark.sh validation /dev/ttyS7
```

A successful run should report:

```text
Correct operation validated.
COREMARK_DONE
```

The standard 2K performance-run component CRCs are expected to include:

```text
crclist   = 0xe714
crcmatrix = 0x1fd7
crcstate  = 0x8e3a
```

`crcfinal` is also printed by CoreMark, but it accumulates across iterations and
therefore can differ when the iteration count changes.

## Run the tuned profile

Build and run the tuned performance image with:

```bash
COREMARK_BUILD_PROFILE=tuned ./scripts/build-coremark.sh
COREMARK_BUILD_PROFILE=tuned ./scripts/run-coremark.sh performance /dev/ttyS7
```

Then validate the tuned image separately:

```bash
COREMARK_BUILD_PROFILE=tuned ./scripts/run-coremark.sh validation /dev/ttyS7
```

Keep baseline and tuned results separate when recording or publishing scores.
Always record the compiler version, compiler flags, CPU clock, memory placement,
and iteration count with the result.

## Timing implementation

CoreMark timing uses the Hazard3 `mcycle` counter. The CPU clock is supplied to
the port with `HAZARD3_SYS_CLK_HZ`, which defaults to 50,000,000 Hz.

Hazard3 resets the cycle and retired-instruction counters inhibited. The
standalone startup therefore contains:

```asm
csrci mcountinhibit, 0x5
```

This enables `mcycle` and `minstret` before `main` is called. Removing this step
causes CoreMark to report zero ticks and an invalid zero-second run.

## Memory placement

The standalone CoreMark image uses the ULX3S Hazard3 internal SRAM rather than
the Doom runtime memory layout. This keeps the CPU benchmark independent of
Doom rendering and SDRAM/cache traffic and provides a cleaner core-performance
measurement.

When comparing or publishing CoreMark/MHz results, identify the memory placement
and CPU clock along with the compiler configuration.

## Useful environment variables

```text
COREMARK_BUILD_PROFILE       baseline or tuned
COREMARK_ITERATIONS          iteration count, default 3000
COREMARK_SERIAL_PORT         UART path used by run-coremark.sh
HAZARD3_SYS_CLK_HZ           CPU clock, default 50000000
TOOLCHAIN_PREFIX             RISC-V toolchain prefix
HAZARD3_ROOT                 Hazard3 source tree
COREMARK_DIR                 CoreMark dist source directory
HAZARD3_COREMARK_BUILD_DIR   override benchmark output directory
```

Example:

```bash
COREMARK_ITERATIONS=4000 \
COREMARK_BUILD_PROFILE=tuned \
./scripts/build-coremark.sh

COREMARK_BUILD_PROFILE=tuned \
./scripts/run-coremark.sh performance /dev/ttyS7
```
