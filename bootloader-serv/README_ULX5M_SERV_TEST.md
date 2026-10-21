# ULX5M-GS SERV read-only flash probe experiment

This experiment substitutes SERV for PicoRV32 in the **GateMate**
`flash-read-probe` configuration. It is not an ECP5 build. It does not
replace the existing PicoRV32 targets or add a configuration-flash writer.

## Requirements

- GateMate-capable Yosys, nextpnr-himbaechel, and gmpack (same as the
  existing ULX5M-GS build)
- RISC-V GCC/objcopy supported by `fw/Makefile.ulx5m-flash-read`
- Git and access to `https://github.com/olofk/serv` for the first build
- Icarus Verilog for the CPU-to-BRAM/MMIO simulation

The Makefile checks out SERV **1.4.0** (commit prefix `7d9cde4`) into
`third_party/serv` if it is not already present. It checks the revision and
will not overwrite an existing checkout. The external SERV files are not
included in this patch ZIP. They remain licensed by the SERV authors under
ISC; see the upstream `LICENSE` in the checkout.

## Build and test

From `bootloader-serv/`:

```sh
# Original regression checks and SERV-specific source guards.
make -f Makefile.ulx5m-gs check-serv

# Execute a small RV32I test on the actual SERV CPU against the existing
# registered BRAM and Wishbone bridge (word/byte/halfword read/writes).
make -f Makefile.ulx5m-gs test-flash-serv-bus

# Execute the actual SERV firmware against modeled peripheral registers.
# Does not simulate USB enumeration or physical SPI transactions.
make -f Makefile.ulx5m-gs test-flash-serv-firmware

# Existing PicoRV32 baseline. Uses original output filenames.
make -f Makefile.ulx5m-gs flash-read-probe

# Experimental SERV version. Uses separate firmware and output filenames.
make -f Makefile.ulx5m-gs flash-read-serv
```

Output files:

| Configuration | Bitstream | Place-and-route log |
| --- | --- | --- |
| PicoRV32 | `build-ulx5m-gs/top_ulx5m_gs_flash_read.bit` | `build-ulx5m-gs/flash-read-pnr.log` |
| SERV | `build-ulx5m-gs/top_ulx5m_gs_flash_read-serv.bit` | `build-ulx5m-gs/flash-read-serv-pnr.log` |

Review the nextpnr logs for Fmax, critical path, cell usage, warnings,
and the 48 MHz clock constraint. Both bitstreams use the **same pin
constraints and read-only USB/QSPI peripherals**, so the differences are
primarily the CPU and its integration logic. For a fair comparison, keep
synthesis and place-and-route tool versions and options unchanged.

**Do not load the SERV bitstream on hardware before the SERV bus simulation
passes.** After a passing simulation and timing run, load the SERV image
through volatile JTAG RAM only. Check USB enumeration and read-only JEDEC
ID/data requests. This patch contains no flash programming commands.

## Differences from PicoRV32

- `soc_serv_cpu.v` maps SERV's separate instruction and data buses onto
  the existing one-request PicoRV32 memory interface.
- The existing `soc_mem_response_reg` stage still issues one ACK per request.
  SERV ACKs are gated by their respective active bus cycles.
- SERV runs RV32I only: `W=1`, `WITH_CSR=0`, `COMPRESSED=0`, `MDU=0`.
  `PRE_REGISTER=0` favors timing over absolute minimum area.
- `fw/start.S` explicitly sets `sp=0x8000` **only** in the SERV firmware
  variant; PicoRV32 initializes `sp` using its `STACKADDR` parameter.
- SERV firmware initializes BRAM from
  `build-ulx5m-gs/serv/fw_ulx5m_flash_read.hex`. The PicoRV32 firmware
  image is unchanged.

## Status and known limitations (2026-10-18)

The user reported PASS for the static checks, the actual SERV RV32I
BRAM/Wishbone simulation, and execution of the compiled SERV firmware in
simulation (47,769 cycles, 782 fetches, 160 endpoint writes). GateMate
synthesis, routing, and `gmpack` also completed. The **final** post-route
Fmax was 48.35 MHz against a 48.00 MHz constraint. That is only about
0.15 ns of timing margin; the USB transaction microcode ROM-to-address
path is now critical. The CPU replacement did not provide ample margin.

The SERV bitstream was loaded through volatile JTAG SRAM using the native
Windows `bin/openFPGALoader.exe`. Windows reported a present, working USB
DFU-class device with bus-provided product string `ULX5M-GS FPGA (DFU
Probe)`. The old `ULX4M-LS FPGA (DFU)` friendly name is Windows-side
device/driver metadata for the reused development VID:PID 1D50:614B.
There was no ULX4M connected. Since the PicoRV32 and SERV builds use
the same USB descriptors, enumeration alone cannot independently identify
the running CPU. Do not change the VID:PID or Windows driver solely to
alter the friendly name.

USB enumeration does not yet prove that the SERV firmware handles the
vendor-control flash-read requests correctly. The 1.8 V QSPI pins,
JEDEC response, repeated flash data reads, and production reliability
remain to be checked in this integrated SERV design. No flash-writing
commands are enabled. The independent PicoRV32 work is kept as fallback
in the sibling `bootloader/` directory; do not change that tree from the
SERV experiment.

## Icarus SERV 1.4.0 compatibility

The pinned SERV source `serv_state.v` defines `trap_pending` after its first
use. Some Icarus Verilog versions reject this forward reference during
elaboration. `test-flash-serv-bus` now generates a build-only copy at
`build-ulx5m-gs/serv_state_iverilog.v`, with an explicit earlier declaration.
The official `third_party/serv` checkout remains unchanged. Yosys continues
to synthesize the unmodified upstream source. This is a simulator compatibility
fix; the SERV bus test must still pass before loading hardware.

The first timing comparison from GateMate showed 41.95 MHz for PicoRV32
(fail at 48 MHz) and 48.35 MHz for SERV (pass, with very little margin).
The SERV critical path now traverses USB transaction microcode logic rather
than the CPU ALU. Neither core's bitstream is a proven DFU implementation.

## Full SERV firmware boot simulation

`test-flash-serv-firmware` builds the **SERV** RV32I firmware with
`ULX5M_SERV_TEST=1`, loads the generated word-oriented `.hex` into the same
32 KiB BRAM and boots `soc_serv_cpu` through the registered memory bridge.
The Icarus testbench models the UART, LED, USB control/endpoint registers,
and SPI CSR at their real memory addresses, providing single-cycle
Wishbone acknowledgements. No USB host, USB PHY, or actual SPI flash is
simulated.

The test must observe the SERV stack initialization, startup UART and LED
stages, a stack RAM write, SPI deselect, all 160 USB endpoint descriptor
reset writes, USB pull-up enable and repeated idle USB CSR polls. It also
rejects any SPI data-register write before a host request. Timeout is
2,000,000 cycles and failure output reports the last observed stage.

From `bootloader-serv/`:

```sh
make -f Makefile.ulx5m-gs check-serv
make -f Makefile.ulx5m-gs test-flash-serv-bus
make -f Makefile.ulx5m-gs test-flash-serv-firmware
```

A passing test proves firmware can reach the USB attach/poll loop through
mocked Wishbone peripherals. It does **not** prove physical USB enumeration,
USB packet timing, actual JEDEC reads, or timing margin on hardware.
Those remain separate integration tests on a volatile JTAG-loaded image.

The download-verification stamp now lives in `build-ulx5m-gs/`, not inside
the pinned `third_party/serv` Git checkout. After applying this patch, the
old untracked stamp can be removed once:

```sh
rm -f third_party/serv/.ulx5m-serv-1.4.0
```

The local `bootloader-serv/.gitignore` excludes the downloaded checkout and GateMate build
outputs; no Git submodule is used.

## Next hardware test: read-only USB/QSPI access

Run this only with the **SERV** bitstream loaded and the ULX5M powered.
If the ULX5M was disconnected after the previous volatile JTAG load,
its SRAM configuration was lost and it must be loaded again. Tigard is
attached to Windows; the Linux `openFPGALoader` inside WSL cannot open
that FTDI device unless USB forwarding is configured. Use the Windows
EXE that has already worked, at the tested 100 kHz clock setting:

```sh
# WSL, from Hazard3-Doom repository root. Never use -f here.
./bin/openFPGALoader.exe -c tigard --freq 100k -m \
  bootloader-serv/build-ulx5m-gs/top_ulx5m_gs_flash_read-serv.bit
```

With the board still powered, use **native Windows PowerShell**, from
the repository root:

```powershell
py -m pip show pyusb
py .\bootloader-serv\tests\read-ulx5m-flash.py --offset 0 --length 32
```

Install PyUSB in that same Windows Python if it is not present:
`py -m pip install pyusb`. PyUSB also needs a compatible USB backend and
a driver permitting control transfers; Windows enumeration alone does
not prove Python access. If the command fails, record the exact Python
exception before changing any driver. Do not run DFU download, upload,
erase, or flash-program commands.

The script first sends vendor **device-to-host** control request
`bmRequestType=0xC0`, `bRequest=0x51` for three JEDEC ID bytes, then
`bRequest=0x52` to read 32 bytes at address zero using SPI command 0x03.
No vendor OUT request is sent. The expected first eight bytes from the
previously verified original board flash backup are:

```text
D9 01 ED 96 10 4D D6 00
```

Do not assume a specific JEDEC ID before observing the chip response.
If the first read succeeds, repeat it and compare the output. If values
are `00`/`FF` throughout, the request stalls, or the device drops off
USB, stop and investigate. Do not enable writes. This test is distinct
from merely reading the GateMate flash through JTAG.
