# ULX5M-GS SERV bootloader regression tests

Use `scripts/test-ulx5m-serv.sh` from the repository root. The GitHub Actions
workflow `.github/workflows/ulx5m-serv-tests.yml` invokes this same runner.

## Offline tests (WSL or GitHub Actions)

```bash
./scripts/test-ulx5m-serv.sh --offline
./scripts/test-ulx5m-serv.sh --offline --synth
```

The first command runs source guards, Python syntax and decoder self-tests,
C host tests (including ASan/UBSan), Icarus Verilog simulations of the
PicoRV32 and SERV buses, EP0/USB TX/RX/ACK, the firmware boot harness,
and the USB microcode receive-timeout test. It builds the SERV RV32I
firmware but does not program the FPGA. `--synth` also runs the GateMate
SERV netlist synthesis target, without placement or routing.

Requirements: Python 3, GCC, Icarus Verilog (`iverilog`, `vvp`), Git, Make,
RISC-V GCC, and (with `--synth`) Yosys with GateMate support.
The Makefile automatically fetches the pinned SERV 1.4.0 source if absent.
For GitHub Actions the OSS CAD Suite and xPack GCC releases are pinned.

The old `check-ulx5m-gs-flash-jedec.py` is deliberately not called: it
expects `flash-jedec: $(JEDEC_BIT)` in the Makefile, but that target is not
present. This is an existing static-check/Makefile mismatch, not a passing
test. The read-only flash-read checker is included.

## Local hardware tests (native Windows USB, via WSL)

Load the verified seed-5 SERV bitstream **into SRAM**, using the existing
Tigard/openFPGALoader procedure. Do not write the configuration flash.
Attach the known-good right-side USB-C port directly to the Windows host.
Use WSL to run offline tests and PowerShell/Windows Python for USB access.

```bash
./scripts/test-ulx5m-serv.sh --all
./scripts/test-ulx5m-serv.sh --hardware-only --rounds 256
```

Or run the hardware portion in native Windows PowerShell:

```powershell
.\scripts\test-ulx5m-serv-hardware.ps1 -Rounds 256
```

Windows prerequisites: native Python 3, `pip install pyusb`, WinUSB bound
to the ULX5M USB device, and `bin/libusb-1.0.dll`. Hardware tests issue
only control-IN requests: JEDEC/32-byte flash sample, EP0 diagnostics,
USB descriptor A/B and stress tests. A failed test is reported as failed;
all checks run to collect diagnostic results. Logs/CSV are written under
`bootloader-serv/build-ulx5m-gs/hardware/`.

The raw hardware trace requires an already frozen capture. Read it only
when requested (no rearm, no FPGA programming):

```bash
./scripts/test-ulx5m-serv.sh --hardware-only --capture
```

The known left USB-C port compatibility problem is not an automated CI
test; repeat manually with a changed cable/port only when investigating
that issue. These tests cannot validate on-wire CRC, EOP, or host ACK
analog behavior without an external USB protocol analyzer or scope.

The workflows do not invoke `flash`, `dfu`, openFPGALoader, or any flash
write/erase command. GateMate placement and timing sweeps remain in
`.github/workflows/bootloader-seed-sweep.yml`. Synthesis success alone
does not prove that the 48 MHz timing requirement was met.
