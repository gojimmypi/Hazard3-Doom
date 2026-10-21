# ULX4M-LD USB DFU Bootloader Build, Recovery, and Installation

This document describes the validated procedure for building, testing, recovering,
and installing the USB DFU bootloader on a ULX4M-LD v0.0.3 with an
LFE5UM-85F FPGA.

The procedure was validated on real hardware. It intentionally keeps the
existing bootloader architecture intact and changes only the board-specific
ULX4M-LD pin mapping and button remapping required by this board.

## 1. Validated hardware and flash layout

Validated target:

- Board: ULX4M-LD v0.0.3
- FPGA: Lattice ECP5 LFE5UM-85F, CABGA381
- JTAG IDCODE: `0x01113043`
- Oscillator: 25 MHz
- USB DFU VID:PID: `1d50:614b`
- Bootloader flash region: `0x000000-0x1FFFFF` (2 MiB)
- User bitstream region starts at: `0x200000`

The DFU alternate settings used by the bootloader are:

| Alt | Flash range | Purpose |
| ---: | --- | --- |
| 5 | `0x000000-0x1FFFFF` | Bootloader Bitstream |
| 4 | `0x800000-0xFFFFFF` | User Data |
| 3 | `0x400000-0xFFFFFF` | User Data |
| 2 | `0x360000-0x3FFFFF` | Saxonsoc u-boot |
| 1 | `0x340000-0x35FFFF` | Saxonsoc fw_jump |
| 0 | `0x200000-0xFFFFFF` | User Bitstream |

Alt 5 is intentionally hidden during ordinary DFU operation. It is exposed only
when bootloader-upgrade/write-enable mode is active.

## 2. Validated ULX4M-LD pin mapping

The active USB signals used by this bootloader are:

| Signal | FPGA pin |
| --- | --- |
| `usb_fpga_bd_dp` | F4 |
| `usb_fpga_bd_dn` | E3 |
| `usb_fpga_pu_dp` | F5 |

These three pins have been validated by successful USB enumeration and DFU
transfers on the ULX4M-LD hardware.

The physical PCB buttons use one-based silkscreen labels, while the Verilog
button vector uses zero-based indices. Do not equate `btn[1]` with PCB BTN1.
The validated mapping is:

| PCB label | Verilog input | FPGA pin | Bootloader function |
| --- | --- | --- | --- |
| BTN1 | `btn[0]` | E1 | Reserved |
| BTN2 | `btn[1]` | D2 | Bootloader upgrade/write-enable |
| BTN3 | `btn[2]` | F1 | Stay in DFU during startup |

The three physical button constraints use `PULLMODE=DOWN` so that the released
state is defined low at power-up.

The bootloader's `soc_had_misc` block expects eight physical PIO-backed button
inputs. Keep the original seven-bit top-level button bus plus scalar `sw`:

```verilog
input wire [6:0] btn;
input wire sw;
...
.btn({sw,btn}),
```

The remaining compatibility button inputs are constrained as real PIOs:

| Input | FPGA pin | Pull mode |
| --- | --- | --- |
| `btn[3]` | H4 | UP |
| `btn[4]` | E4 | UP |
| `btn[5]` | E5 | UP |
| `btn[6]` | H5 | UP |
| `sw` | G3 | UP |

Do not replace these compatibility inputs with constants unless
`soc_had_misc` is also redesigned. It instantiates `TRELLIS_IO` and ECP5 input
registers for all eight button inputs.

## 3. Normal and emergency button remapping

In this section, `btn[n]` always means the zero-based Verilog input and `PCB BTNn`
always means the one-based label printed on the board.

The validated normal ULX4M-LD remapper is:

```verilog
assign btn_remap_i = ~
{
  btn_remap_o[1]   , // PCB BTN2 / btn[1]: enable bootloader upgrade/write access
  btn_remap_o[2]   , // PCB BTN3 / btn[2]: stay in DFU during startup
  btn_remap_o[6:3] , // Reserved inputs
  1'b0             , // Disabled input
 ~btn_remap_o[0]     // PCB BTN1 / btn[0]: reserved; ULX3S uses inverted polarity
};
```

Because a Verilog concatenation is written most-significant bit first, the
mapping before the outer inversion is:

```text
[7]   btn_remap_o[1]   PCB BTN2 / btn[1] upgrade/write-enable
[6]   btn_remap_o[2]   PCB BTN3 / btn[2] stay in DFU
[5:2] btn_remap_o[6:3] reserved
[1]   1'b0             disabled
[0]  ~btn_remap_o[0]   PCB BTN1 / btn[0] special polarity handling
```

The resulting physical behavior was validated in SRAM:

- PCB BTN3 alone: stay in DFU, alt 0 through alt 4 visible, alt 5 hidden.
- PCB BTN2 + BTN3: stay in DFU and enable bootloader access, alt 0 through alt 5 visible.
- PCB BTN2 alone: upgrade/write-enable is asserted, but it does not by itself keep the bootloader in DFU.

Two emergency modes are useful when recovering a board whose persistent
bootloader is unavailable or whose physical button behavior has not yet been
validated:

```verilog
`ifdef EMERGENCY_RESTORE1
    // bit 6: force stay in DFU; bootloader write access remains disabled
    assign btn_remap_i = ~8'b01000000;
`elif EMERGENCY_RESTORE2
    // bit 7: force bootloader upgrade/write-enable
    // bit 6: force stay in DFU
    assign btn_remap_i = ~8'b11000000;
`else
    // Normal button-controlled remapper goes here.
`endif
```

`EMERGENCY_RESTORE1` forces ordinary DFU mode but keeps alt 5 hidden.

`EMERGENCY_RESTORE2` forces DFU mode and exposes alt 5. This is the useful mode
for restoring the bootloader flash region through a JTAG-loaded SRAM image.

## 4. Required tools

The validated workflow used:

- Yosys
- nextpnr-ecp5
- Project Trellis tools: `ecppack`, `ecpbram`, and `ecpmulti`
- RISC-V GCC toolchain
- `openFPGALoader.exe`
- `dfu-util.exe` 0.9
- Tigard for JTAG recovery and SRAM testing

Example paths used during validation:

```text
Bootloader source:
/mnt/c/workspace/Hazard3-Doom/bootloader

Programming utilities:
/mnt/c/workspace/Hazard3-Doom/bin/openFPGALoader.exe
/mnt/c/workspace/Hazard3-Doom/bin/dfu-util.exe
```

### Self-contained Hazard3-Doom bootloader layout

Hazard3-Doom vendors the bootloader directly at `bootloader/`. The upstream
had2019 build system also requires its shared build helpers plus the `misc` and
`usb` cores. Keep those dependencies below the same directory:

```text
Hazard3-Doom/
  bootloader/
    Makefile
    mk/
      core-magic.mk
      core-rules.mk
      project-rules.mk
      ulx3s-passthru-inc.mk
    cores/
      misc/
      usb/
    data/
    fw/
    rtl/
```

The ``mk/`` directory contains vendored upstream make rules and is part of the
bootloader source tree; check it into Git. In contrast, ``build-tmp/`` contains
generated build artifacts and should not be checked in. The upstream directory
name is ``build/``; Hazard3-Doom intentionally vendors those make-rule files as
``bootloader/mk/`` to avoid confusing them with generated build output.

The imported `bootloader/Makefile` sets `ROOT` to the bootloader directory so
these vendored paths are used instead of assuming the original
`had2019-playground/projects/bootloader` repository nesting. Preserve the
upstream copyright and license notices when copying the `build`, `cores/misc`,
and `cores/usb` directories.

The bootloader project expects the older `riscv-none-embed-*` tool names. If the
installed compiler uses the `riscv32-unknown-elf-*` prefix, a temporary shim can
be created without modifying the installed toolchain:

```bash
mkdir -p /tmp/had2019-riscv-tools

for tool in /opt/riscv/bin/riscv32-unknown-elf-*; do
    suffix="${tool##*/riscv32-unknown-elf-}"
    ln -sf "${tool}" "/tmp/had2019-riscv-tools/riscv-none-embed-${suffix}"
done

export PATH="/tmp/had2019-riscv-tools:$PATH"
```

## 5. Tigard/JTAG setup

The validated Tigard setup uses:

- Tigard target power: OFF
- Target Vref: 3.3 V
- FTDI channel A/interface 0: normal FTDI VCP/UART
- FTDI channel B/interface 1: libusbK for JTAG
- JTAG clock used by openFPGALoader: 6 MHz

The hard ECP5 JTAG TAP should identify the FPGA as:

```text
0x01113043
```

Use only an 85F bootloader image built for this IDCODE. Do not substitute an
image for a different ECP5 density.

## 6. Build the normal bootloader

From the bootloader project:

```bash
cd /mnt/c/workspace/Hazard3-Doom/bootloader

make MODEL=ulx4m BOARD=ulx4m-v002 DEVICE=um-85k clean
make MODEL=ulx4m BOARD=ulx4m-v002 DEVICE=um-85k
```

The historical `BOARD=ulx4m-v002` selector is still used by the build system;
the corresponding LPF contains the ULX4M-LD v0.0.3 mappings documented above.

A successful build finishes by inserting the firmware with `ecpbram` and
packing `build-tmp/bootloader.bit` with settings equivalent to:

```text
--spimode qspi
--freq 38.8
--bootaddr 0x200000
--compress
```

The generated `bootloader.bit` is the flash/multiboot form. Do not use that file
directly for the JTAG SRAM functional test.

## 7. Create an SRAM-only test bitstream

Repack the already routed and firmware-patched configuration without
`--bootaddr`:

```bash
cd /mnt/c/workspace/Hazard3-Doom/bootloader

ecppack \
    --compress \
    --idcode 0x01113043 \
    --input build-tmp/bootloader-sw.config \
    --bit build-tmp/bootloader-sram-ld-normal.bit
```

This is the image used for volatile JTAG testing. It does not modify SPI flash.

## 8. SRAM-test ordinary DFU mode

Hold PCB-labeled BTN3 while loading the SRAM image. Keep BTN3 held until USB has
had time to enumerate, then release it.

From the Hazard3-Doom checkout:

```bash
cd /mnt/c/workspace/Hazard3-Doom

./bin/openFPGALoader.exe \
    -c tigard \
    C:/workspace/Hazard3-Doom/bootloader/build-tmp/bootloader-sram-ld-normal.bit
```

List DFU interfaces:

```bash
./bin/dfu-util.exe -l
```

Expected result: alt 0 through alt 4 are present and alt 5 is absent. A validated
listing contains entries equivalent to:

```text
alt=4, name="0x800000-0xFFFFFF User Data"
alt=3, name="0x400000-0xFFFFFF User Data"
alt=2, name="0x360000-0x3FFFFF Saxonsoc u-boot"
alt=1, name="0x340000-0x35FFFF Saxonsoc fw_jump"
alt=0, name="0x200000-0xFFFFFF User Bitstream"
```

This validates PCB BTN3 as the ordinary DFU-entry button and confirms that the
bootloader region remains protected during normal DFU operation.

## 9. SRAM-test bootloader upgrade mode

Use the exact same SRAM image, but hold PCB BTN2 and BTN3 together while loading
it. Keep both buttons held until USB has had time to enumerate, then release them.

```bash
cd /mnt/c/workspace/Hazard3-Doom

./bin/openFPGALoader.exe \
    -c tigard \
    C:/workspace/Hazard3-Doom/bootloader/build-tmp/bootloader-sram-ld-normal.bit

./bin/dfu-util.exe -l
```

Expected result: alt 5 appears in addition to alt 0 through alt 4:

```text
alt=5, name="0x000000-0x1FFFFF Bootloader Bitstream"
```

Do not install the normal bootloader persistently until both SRAM tests pass.

## 10. Recovery workflow when the persistent DFU bootloader is unavailable

If the board does not enumerate as `1d50:614b`, JTAG can be used to load an
emergency bootloader into FPGA SRAM.

Build an SRAM image with `EMERGENCY_RESTORE2` active, then pack it without
`--bootaddr` exactly as described above. Load it through Tigard:

```bash
cd /mnt/c/workspace/Hazard3-Doom

./bin/openFPGALoader.exe \
    -c tigard \
    C:/workspace/Hazard3-Doom/bootloader/build-tmp/bootloader-sram-ld-upgrade.bit
```

Then verify:

```bash
./bin/dfu-util.exe -l
```

The emergency image should enumerate as `1d50:614b` and expose alt 5. Once alt
5 is visible, the first 2 MiB of flash can be backed up or restored through
DFU.

## 11. Back up the existing bootloader region before overwriting it

Whenever alt 5 is available, save the current first 2 MiB of flash before
writing a replacement:

```bash
cd /mnt/c/workspace/Hazard3-Doom

./bin/dfu-util.exe \
    -d 1d50:614b \
    -a 5 \
    -U C:/workspace/Hazard3-Doom/bootloader/build-tmp/bootloader-alt5-before-update.bin
```

Verify that the backup is exactly 2 MiB and record its SHA256:

```bash
cd /mnt/c/workspace/Hazard3-Doom/bootloader

stat -c '%n: %s bytes' \
    build-tmp/bootloader-alt5-before-update.bin

sha256sum build-tmp/bootloader-alt5-before-update.bin
```

Expected size:

```text
2097152 bytes
```

Keep this backup outside temporary build output if it is important for later
recovery or forensic comparison.

## 12. Build the final normal multiboot image

After the normal SRAM button tests pass, do not modify the RTL or LPF again.
Use the exact validated `build-tmp/bootloader.bit` from that build.

First build the passthrough image if it is not already present:

```bash
cd /mnt/c/workspace/Hazard3-Doom/bootloader

make MODEL=ulx4m BOARD=ulx4m-v002 DEVICE=um-85k passthru
```

Confirm the required inputs exist:

```bash
stat -c '%n: %s bytes' \
    build-tmp/bootloader.bit \
    build-tmp/passthru.bit

sha256sum \
    build-tmp/bootloader.bit \
    build-tmp/passthru.bit
```

Now create the 85F multiboot image explicitly with the correct input and output
IDCODE:

```bash
ecpmulti \
    --input build-tmp/bootloader.bit \
    --address 0x200000 \
    --input build-tmp/passthru.bit \
    --flashsize 128 \
    --input-idcode 0x01113043 \
    --output-idcode 0x01113043 \
    --output build-tmp/multiboot-ulx4m-85f.img
```

The resulting layout is:

```text
flash 0x000000: normal DFU bootloader
flash 0x200000: passthrough/user-bitstream entry point
```

The `ecpmulti` output does not need to be padded to the full flash capacity for
this procedure. Alt 5 accepts only the first 2 MiB bootloader region.

## 13. Extract exactly the first 2 MiB for DFU alt 5

Extract exactly the bootloader region:

```bash
dd \
    if=build-tmp/multiboot-ulx4m-85f.img \
    of=build-tmp/bootloader-alt5-2m.img \
    bs=2M count=1
```

Verify the size and record the hash:

```bash
stat -c '%n: %s bytes' \
    build-tmp/bootloader-alt5-2m.img

sha256sum build-tmp/bootloader-alt5-2m.img
```

The required size is exactly:

```text
2097152 bytes
```

Do not write a differently sized image to alt 5.

## 14. Run the normal SRAM image in PCB BTN2+BTN3 upgrade mode

Before writing the final bootloader, load the already validated normal SRAM
image again while holding PCB BTN2+BTN3:

```bash
cd /mnt/c/workspace/Hazard3-Doom

./bin/openFPGALoader.exe \
    -c tigard \
    C:/workspace/Hazard3-Doom/bootloader/build-tmp/bootloader-sram-ld-normal.bit

./bin/dfu-util.exe -l
```

Confirm that alt 5 is present before proceeding.

This is important: the write is performed by the currently running SRAM copy of
the known-good normal bootloader. The persistent bootloader in flash is not
executing while it is being replaced.

## 15. Write the final normal bootloader to alt 5

With the SRAM normal bootloader still running in PCB BTN2+BTN3 mode:

```bash
cd /mnt/c/workspace/Hazard3-Doom

./bin/dfu-util.exe \
    -d 1d50:614b \
    -a 5 \
    -D C:/workspace/Hazard3-Doom/bootloader/build-tmp/bootloader-alt5-2m.img
```

A successful `dfu-util` 0.9 transfer ends with output equivalent to:

```text
Download done.
state(2) = dfuIDLE, status(0) = No error condition is present
Done!
```

`dfu-util` 0.9 may print:

```text
Invalid DFU suffix signature
A valid DFU suffix will be required in a future dfu-util release!!!
```

That warning is expected for this raw flash image. The important result is a
complete 2 MiB download followed by DFU status 0 and `Done!`.

Do not use `-e`, `-R`, or power-cycle immediately after the write.

## 16. Read alt 5 back and verify it byte-for-byte

While the same SRAM bootloader is still running, read the first 2 MiB back from
flash:

```bash
cd /mnt/c/workspace/Hazard3-Doom

./bin/dfu-util.exe \
    -d 1d50:614b \
    -a 5 \
    -U C:/workspace/Hazard3-Doom/bootloader/build-tmp/bootloader-alt5-after-update.bin
```

Verify the readback size and compare SHA256 hashes:

```bash
cd /mnt/c/workspace/Hazard3-Doom/bootloader

stat -c '%n: %s bytes' \
    build-tmp/bootloader-alt5-after-update.bin

sha256sum \
    build-tmp/bootloader-alt5-2m.img \
    build-tmp/bootloader-alt5-after-update.bin
```

Both files must be exactly 2097152 bytes and the two SHA256 values must match.

Do not power-cycle if the hashes differ.

## 17. Cold-boot verification of the persistent normal bootloader

Only after the alt 5 readback matches byte-for-byte should power be removed.
This ensures the SRAM-loaded test image is lost and the next boot truly comes
from SPI flash.

Perform all three tests.

### 17.1 No buttons: user bitstream boots

1. Remove all board power/USB.
2. Do not press any button.
3. Apply power normally.
4. Confirm the valid user bitstream at `0x200000` starts and behaves as expected.

If a user bitstream has not yet been installed, program one through ordinary
DFU first as described later in this document.

### 17.2 PCB BTN3: ordinary protected DFU

1. Remove all board power/USB.
2. Hold PCB-labeled BTN3.
3. Connect the ULX4M USB cable/apply power.
4. Wait for USB enumeration.
5. Release BTN3.
6. Run:

```bash
cd /mnt/c/workspace/Hazard3-Doom
./bin/dfu-util.exe -l
```

Expected result: alt 0 through alt 4 are listed; alt 5 is absent.

This confirms that the normal persistent bootloader is running and that its own
flash region is protected during ordinary DFU operation.

### 17.3 PCB BTN2+BTN3: bootloader upgrade DFU

1. Remove all board power/USB.
2. Hold PCB-labeled BTN2 and BTN3 together.
3. Connect the ULX4M USB cable/apply power.
4. Wait for USB enumeration.
5. Release both buttons.
6. Run:

```bash
cd /mnt/c/workspace/Hazard3-Doom
./bin/dfu-util.exe -l
```

Expected result: alt 5 is present in addition to alt 0 through alt 4:

```text
alt=5, name="0x000000-0x1FFFFF Bootloader Bitstream"
```

When all three cold-boot tests pass, the normal persistent ULX4M-LD DFU
bootloader installation is complete. The validated installation described here
used PCB BTN3 for ordinary DFU entry and produced a 2 MiB alt-5 image with
SHA256 `85be161e23228b21af37f05e0227e5bcdb11d23d8efd931785c2cf1065a93086`.

## 18. Program a user bitstream through the normal bootloader

Ordinary user-bitstream programming does not require alt 5.

1. Remove power.
2. Hold PCB-labeled BTN3.
3. Connect USB/apply power.
4. Release BTN3 after DFU enumerates.
5. Program alt 0.

A validated command is:

```bash
cd /mnt/c/workspace/Hazard3-Doom

./bin/openFPGALoader.exe \
    --dfu \
    --vid 0x1d50 \
    --pid 0x614b \
    --altsetting 0 \
    ./build/fpga_ulx4m_ld.bit
```

Alt 0 begins at flash address `0x200000`; this operation does not overwrite the
bootloader region at `0x000000-0x1FFFFF`.

After programming, cold-boot the board without holding a button to run the user
bitstream.

## 19. Recommended artifacts to preserve

For a reproducible release or recovery package, preserve at least:

```text
rtl/top-ulx4m.v
data/top-ulx4m-v002.lpf
build-tmp/bootloader.bit
build-tmp/bootloader-sram-ld-normal.bit
build-tmp/passthru.bit
build-tmp/multiboot-ulx4m-85f.img
build-tmp/bootloader-alt5-2m.img
bootloader-alt5-before-update.bin
bootloader-alt5-after-update.bin
```

Also record:

```bash
sha256sum \
    build-tmp/bootloader.bit \
    build-tmp/bootloader-sram-ld-normal.bit \
    build-tmp/passthru.bit \
    build-tmp/multiboot-ulx4m-85f.img \
    build-tmp/bootloader-alt5-2m.img \
    build-tmp/bootloader-alt5-after-update.bin
```

Record the FPGA tool versions used for the build as well. Bitstreams can change
when synthesis or place-and-route tool versions change, even when the source is
unchanged.

## 20. Operational summary

The validated button behavior is:

| Startup condition | Result |
| --- | --- |
| No buttons | Boot user bitstream from `0x200000` |
| PCB BTN3 | Stay in DFU, alt 0-4 visible, alt 5 hidden |
| PCB BTN2 + BTN3 | Stay in DFU, alt 0-5 visible |

The validated recovery chain is:

```text
Tigard JTAG
    -> SRAM emergency/normal bootloader
    -> USB DFU 1d50:614b
    -> alt 5 access
    -> write exactly first 2 MiB
    -> read back exactly first 2 MiB
    -> SHA256 match
    -> cold boot from SPI flash
```

The key rule is to validate a new normal bootloader from SRAM first, then write
it to alt 5 only while a known-good SRAM bootloader is currently running, and
always perform a byte-for-byte readback verification before the first
power-cycle.
