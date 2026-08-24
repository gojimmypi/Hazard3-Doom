# Hazard3 cached-path software verifier

This is a standalone hardware-exercising software test for the failure observed
on the ULX3S 12F while Doom initializes texture lookup tables. It does not
modify the FPGA RTL, DoomGeneric, the resident monitor, or the WAD.

The verifier is deliberately linked at `0x20000040`, so its instructions execute
from the same cached external-SDRAM region used by the ULX3S 12F resident
monitor. It then runs four phases:

1. Register/control-flow canary with a fixed expected signature.
2. Uncached SDRAM control test.
3. Cached SDRAM pattern and cache-churn verification across widely separated
   regions.
4. A Doom-like texture lookup canary using mixed 8-, 16-, and 32-bit accesses,
   a 128-column `patchcount` table, a 96-byte composite stride, guard words,
   and continuous verification of the `texturecompositesize` invariant.

The Doom-like phase is intentionally modeled after the symptom that produced
`R_GenerateLookup: texture N is >64k`. For a valid 128x96 synthetic texture its
composite size must finish at 12288 bytes and can never legitimately approach
64 KiB.

## Build

From the Hazard3-Doom repository root:

```bash
./tests/software-verify/build.sh
```

The output is:

```text
build/software-verify/hazard3-software-verify.elf
```

The default test performs 10000 Doom-like rounds. Increase it without changing
source:

```bash
VERIFY_ROUNDS=100000 ./tests/software-verify/build.sh
```

## Run manually

Configure the FPGA and keep the board-specific OpenOCD session running on port
3333. Close WebSerial, PuTTY, or anything else that owns the UART. Then:

```bash
./tests/software-verify/build.sh
./scripts/load-firmware.sh build/software-verify/hazard3-software-verify.elf
```

Open the UART at 115200 8N1. A successful run ends with:

```text
VERIFY RESULT: PASS
```

A detected mismatch stops immediately with a diagnostic such as:

```text
VERIFY FAIL phase=lookup-final-size pass=0x00000023 index=0x00000080 \
addr=0x20500xxx expected=0x00003000 actual=0x0000F000
VERIFY RESULT: FAIL
```

An unexpected CPU trap is also reported as a failure with `mcause`, `mepc`, and
`mtval`.

The test parks in `wfi` after PASS or FAIL. Reload the normal resident monitor
afterward with the appropriate board loader.

## One-command run

If `pyserial` is installed, the wrapper builds, opens the UART before the target
is resumed, loads the verifier through the existing OpenOCD/GDB loader, and
returns a shell success/failure status:

```bash
./tests/software-verify/run.sh /dev/ttyS6
```

The default UART-result timeout is 120 seconds. Override it with:

```bash
VERIFY_TIMEOUT_S=300 VERIFY_ROUNDS=100000 \
    ./tests/software-verify/run.sh /dev/ttyS6
```

## 85F control comparison

The verifier intentionally touches only addresses within the first 32 MiB of
external SDRAM, so the same ELF can also be run on the ULX3S 85F as a control.
Use the appropriate FPGA bitstream and OpenOCD configuration, but do not rebuild
the verifier between the 12F and 85F runs if you want the strongest A/B
comparison.

A PASS is evidence that this particular workload did not expose an error; it is
not a substitute for FPGA timing closure. A 12F FAIL combined with an 85F PASS
on the same ELF is a useful software-visible discriminator for the current
problem.
