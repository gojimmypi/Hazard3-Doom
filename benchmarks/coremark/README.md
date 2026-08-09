# CoreMark on Hazard3 ULX3S

This directory contains the Hazard3-Doom ULX3S bare-metal port used to run
CoreMark on the Hazard3 soft CPU implemented in the ULX3S FPGA design.

The benchmark workload sources are not duplicated or modified here. The build
uses the CoreMark sources already present in the pinned Hazard3 tree at:

```text
third_party/Hazard3/test/sim/coremark/dist
```

The ULX3S-specific files provide startup, 64-bit hardware-counter timing,
retired-instruction measurement, UART output, linking, source-integrity checks,
ELF ISA analysis, and host-side result capture and qualification.

## Source and attribution

The Hazard3 ULX3S CoreMark port and its support code were based on and adapted
from the CoreMark simulation integration in Luke Wren's upstream Hazard3
repository:

- Hazard3 repository: <https://github.com/Wren6991/Hazard3>
- Upstream Hazard3 CoreMark simulation:
  <https://github.com/Wren6991/Hazard3/tree/stable/test/sim/coremark>

In particular, the port follows the upstream Hazard3 approach for CoreMark
platform support and hardware-counter timing. Hazard3 resets `mcycle` and
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
    analyze_elf.py
    check_coremark_sources.py
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

The benchmark workload files `core_main.c`, `core_list_join.c`, `core_matrix.c`,
`core_state.c`, `core_util.c`, and `coremark.h` are taken directly from the
pinned Hazard3 CoreMark `dist` directory. `build-coremark.sh` verifies their
bytes against the checked-out Hazard3 Git commit before compiling them.

## Current ULX3S CPU target

The build targets:

```text
RV32IMC_Zicsr_Zifencei_Zba_Zbb_Zbs
```

with:

```text
-march=rv32imc_zicsr_zifencei_zba_zbb_zbs
-mabi=ilp32
```

The default CPU clock is 50 MHz. Code, benchmark data, and stack are linked into
the internal SRAM region defined by `link.ld`. The target reports that region's
base, size, image end, and stack top from linker symbols at runtime. The hart
cannot determine whether that SRAM was physically synthesized as ECP5 EBR, LUT
RAM, an ASIC SRAM macro, or another implementation unless the SoC exposes that
information separately.

## Prerequisites

Before running CoreMark:

1. Program the ULX3S with the matching Hazard3 FPGA bitstream.
2. Initialize the Hazard3 dependencies/submodules.
3. Ensure the RISC-V GCC toolchain is available. The default prefix is:

   ```text
   /opt/riscv/bin/riscv32-unknown-elf-
   ```

4. Start OpenOCD using the Hazard3 ULX3S configuration.
5. Connect the external UART. The benchmark uses 115200 baud, 8N1.
6. Install pyserial for the host runner if needed:

   ```bash
   python3 -m pip install pyserial
   ```

## Build

From the Hazard3-Doom repository root:

```bash
./scripts/build-coremark.sh
```

The baseline build creates:

```text
build/coremark/baseline/coremark-performance.elf
build/coremark/baseline/coremark-validation.elf
```

Before compilation, the build checks the CoreMark workload files against the
pinned `third_party/Hazard3` Git commit. A modified workload file is a hard
error. Port files in `benchmarks/coremark` are intentionally not included in
that check because CoreMark permits platform-specific `core_portme*` changes.

For each ELF the build also creates:

```text
coremark-performance.isa.json
coremark-performance.isa.txt
coremark-validation.isa.json
coremark-validation.isa.txt
source-integrity.json
build-info.txt
```

The ISA reports use `readelf -A` and `objdump -d -M no-aliases` to record the
ELF `Tag_RISCV_arch` and count generated instructions from the implemented ISA
families. The build also compiles a tiny reference object with the exact requested
`-march`/`-mabi` and requires the final ELF `Tag_RISCV_arch` to match it. This
catches library or toolchain objects which silently broaden the ELF ISA before
the image is loaded on hardware.

### Tuned build

```bash
COREMARK_BUILD_PROFILE=tuned ./scripts/build-coremark.sh
```

The tuned profile uses `-O3` plus the Hazard3-oriented optimization options in
`build-coremark.sh`. It retains the same hardware-supported ISA and does not
turn on unsupported extensions.

## Start OpenOCD

Run OpenOCD in a separate terminal and leave it running:

```bash
./bin/openocd.exe -d2 \
    -f ./openocd/ulx3s-openocd.cfg
```

A normal connection should include output similar to:

```text
Examined RISC-V core; found 1 harts
hart 0: XLEN=32, misa=0x40801106
Listening on port 3333 for gdb connections
```

## Run the performance benchmark

```bash
./scripts/run-coremark.sh performance /dev/ttyS7
```

Replace `/dev/ttyS7` with the UART device connected to the board.

The runner loads the ELF through the existing Hazard3 GDB loader, captures UART
output, and calculates the authoritative result from the full 64-bit hardware
cycle count. It also records the 64-bit retired-instruction count and reports:

```text
cycles
instructions
cycles/instruction
instructions/iteration
elapsed seconds
CoreMark/s
CoreMark/MHz
hardware/ELF ISA compatibility
source integrity
ELF instruction-use counts
ELF SHA256
```

Run logs and machine-readable result JSON are saved alongside the ELF:

```text
coremark-performance.run.log
coremark-performance.result.json
```

## Hardware ISA and implementation report

Every target run reports the ISA implemented by the running hart. RV32I/RV32E
and the standard single-letter fields available in `misa` are read directly
from `misa`. Hazard3's `h3.misa` CSR at `0xbf1` is then used for the extended
standard-extension bitmap. `h3.misa` follows the extension bit assignments from
the RISC-V C API.

The target prints Hazard3-relevant extensions plus the raw `h3.misa` bitmap
length and words. The host runner decodes those words using the complete current
RISC-V C API queryable standard-extension table and lists extensions outside the
Hazard3 v1.1.1 implementation set separately. Keeping that catalog on the host
prevents extension-table growth from changing the benchmark ELF layout. If a bit
is beyond the bitmap length reported by the running Hazard3 core, its state is
shown as `not-enumerated` rather than incorrectly reported as `no`.

`Zicsr` is reported from the fact that the running program successfully executes
CSR accesses including `misa` and `h3.misa`. `Zicntr` is reported from the
working `cycle`/`instret` counter support required by this CoreMark port. The
modern `Zaamo` and `Zalrsc` subsets are reported with `A`, because the standard
A extension comprises both subsets and Hazard3's A implementation provides both
LR/SC and AMO instructions.

For the current ULX3S image the beginning of the report should resemble:

```text
Hazard3 ISA:   misa       = 0x40801106
   RV32E      = no
   RV32I      = yes
   M          = yes;  integer multiply/divide/modulo
   A          = no;  atomic memory operations, with AHB5 global exclusives
   Zaamo      = no;  atomic memory operations subset of A
   Zalrsc     = no;  load-reserved/store-conditional subset of A
   C          = yes;  compressed instructions
   Zicsr      = yes;  CSR access (required to read misa/h3.misa)
   Zicntr     = yes;  cycle/instret counters used by CoreMark
   ...
   h3.misa bitmap length = ... bits
   h3.misa[0] = 0x........
   ...
```

The report also probes Hazard3 implementation features without modifying the
CoreMark timed workload:

```text
Hazard3 implementation features:
   Machine mode       = yes
   User mode          = yes/no
   Supervisor mode    = no;  not implemented by Hazard3
   Trap support       = yes/no
   ecall              = yes
   ebreak             = yes
   mret               = yes
   wfi                = yes
   Current privilege  = Machine
   Debug support      = yes/no/unknown;  trigger CSR support
   External debug     = not hart-detectable from M-mode
   Debug transport    = not hart-detectable (JTAG/APB is integration-specific)
   HW breakpoints     = <count>
   PMP                = yes/no/unknown
   ...
```

Trap support is detected reversibly through `mscratch`. The four privileged
system instructions are reported as implemented because Hazard3 v1.1.1 decodes
`ecall`, `ebreak`, `mret`, and `wfi` whenever its CSR support is present; this
CoreMark port has already proven that CSR support by reading `misa` and `h3.misa`.
When trap support and a writable `mtvec` are available, optional CSR accesses use
a temporary illegal-instruction handler. Standard trigger CSRs are enumerated with `tselect`/`tinfo`,
so the hardware instruction-address breakpoint count is detected without
programming a breakpoint. PMP presence is detected by whether the standard PMP
CSR is implemented.

Hazard3 can implement up to 16 PMP regions, including hardwired regions. There
is no universally safe, non-destructive hart-visible method to recover the exact
configured `PMP_REGIONS`, `PMP_MATCH_NAPOT`, or `PMP_MATCH_TOR` parameters in
all configurations, so those details are explicitly reported as not
hart-detectable when PMP is present rather than guessed. Likewise, trigger-CSR
support is hart-detectable, but external-debug presence and whether the integration
connects it through JTAG or APB are SoC-level facts,
not M-mode hart ISA properties. The host runner separately reports whether the
external debug loader completed successfully.

The host runner compares the runtime extension report with the ISA declared by
the ELF. RV32I and RV32E are detected independently from the standard `misa` I
and E bits. An RV32I hart is accepted as a compatible superset for an RV32E ELF,
but an RV32E-only hart is not accepted for an RV32I ELF. A required extension
reported as absent fails compatibility; a required extension which the running
core cannot enumerate leaves compatibility `UNKNOWN` and does not qualify as a
passing run.

## 64-bit timing and retired instructions

The port reads `mcycle/mcycleh` and `minstret/minstreth` with the normal RV32
high-low-high retry sequence, so measurements do not wrap at the 32-bit
`mcycle` boundary. Decimal formatting and `time_in_secs()` use local shift/subtract
64-by-32 arithmetic rather than compiler 64-bit divide/modulo helpers, so the
CoreMark image does not need to pull `_udivdi3`/`_umoddi3` from a mismatched
`libgcc` multilib. The timed CoreMark workload remains unchanged.

Startup enables both counters with:

```asm
csrci mcountinhibit, 0x5
```

Target output after the CoreMark validation text includes:

```text
Hazard3 counters:
   cycles       = ...
   instructions = ...
COREMARK_DONE
```

The Python runner uses `Hazard3 counters` as the authoritative timing source.
CoreMark's standard `Total ticks` line is retained for compatibility with the
upstream output format. Because this port builds with `HAS_FLOAT=0`, CoreMark's
standard target-side `Total time (secs)` and `Iterations/Sec` values use integer
seconds and are therefore truncated approximations. Use the host summary's
`elapsed seconds`, `CoreMark/s`, and `CoreMark/MHz`, which are calculated from
the raw 64-bit cycle count, for performance comparisons and reporting.

CPI is calculated as measured cycles divided by retired instructions. The
counter-read overhead is a handful of instructions outside the CoreMark
workload and is negligible for a standard multi-second run; it should still be
kept identical when comparing build profiles.

Diagnostic/printing functions and the temporary CSR-probe trap are placed in a
dedicated `.coremark_diag.text` input section. The linker places normal `.text*`
first and diagnostics afterward, so adding capability-reporting code does not
move the timed CoreMark functions.

## Run validation

```bash
./scripts/run-coremark.sh validation /dev/ttyS7
```

A successful run reports:

```text
Correct operation validated. See README.md for run and reporting rules.
COREMARK_DONE
```

The standard 2K performance-run component CRCs include:

```text
crclist   = 0xe714
crcmatrix = 0x1fd7
crcstate  = 0x8e3a
```

`crcfinal` accumulates across iterations and can differ when the iteration count
changes.

## Qualification command

To run both required seed configurations and get one final qualification
summary:

```bash
./scripts/run-coremark.sh qualify /dev/ttyS7
```

The command runs the performance image and then the validation image and checks:

```text
performance validation
validation-seed validation
minimum 10-second run time
CoreMark source integrity
runtime hardware versus ELF ISA compatibility
```

The final summary is:

```text
Hazard3 ULX3S CoreMark qualification
  performance run    : PASS
  validation run     : PASS
  source integrity   : PASS
  ISA compatibility  : PASS
  RESULT             : VALID
```

A non-passing check causes a nonzero exit status.

## Run the tuned profile

```bash
COREMARK_BUILD_PROFILE=tuned ./scripts/build-coremark.sh
COREMARK_BUILD_PROFILE=tuned ./scripts/run-coremark.sh qualify /dev/ttyS7
```

Keep baseline and tuned results separate. CPI and instructions/iteration are
particularly useful when comparing them: a performance improvement can come
from fewer generated instructions, fewer cycles per retired instruction, or
both.

## Valid run duration

CoreMark results are valid for reporting only when each benchmark execution is
at least 10 seconds. The default is:

```text
COREMARK_ITERATIONS=3000
TOTAL_DATA_SIZE=2000
HAZARD3_SYS_CLK_HZ=50000000
```

If a faster configuration finishes in under 10 seconds, increase iterations and
rebuild, for example:

```bash
COREMARK_ITERATIONS=4000 ./scripts/build-coremark.sh
./scripts/run-coremark.sh qualify /dev/ttyS7
```

## Memory placement and reporting

The linker script is the authoritative source for the standalone CoreMark RAM
region. It exports `__ram_origin`, `__ram_length`, `__image_end`, and
`__stack_top`, and the running program prints those values rather than duplicating
a hard-coded `128 KiB` description in C. With the current linker script the
report is expected to begin with:

```text
Memory:
   type         = internal SRAM
   base         = 0x00000000
   size         = 131072 bytes (128 KiB)
   placement    = code/data/stack
   image end    = 0x........
   stack top    = 0x00020000
   image->stack = ........ bytes
   physical     = not hart-detectable (e.g. ECP5 EBR vs other SRAM)
```

This standalone image does not benchmark Doom's SDRAM/cache/frame-buffer path.
The standard CoreMark `Memory location` string therefore identifies the memory
as linker-defined internal SRAM. The target deliberately does not print
`Memory:core = 1:1`, because that ratio had not been established by runtime
detection and could be confused with a zero-wait-state memory claim.

When publishing a CoreMark/MHz result, retain the runtime memory report, CPU
clock, compiler version and flags, iteration count, and the relevant commit and
ELF hash from the generated metadata.

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
./scripts/run-coremark.sh qualify /dev/ttyS7
```
