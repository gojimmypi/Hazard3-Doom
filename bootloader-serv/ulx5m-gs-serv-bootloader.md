# ULX5M-GS SERV bootloader: operation, setup, and recovery

**Hardware checkpoint: October 30, 2026.** This guide covers the ULX5M-GS
V005 GateMate bootloader in `bootloader-serv/`. It distinguishes capabilities
verified on physical hardware from experimental firmware paths. It is not a
claim that full-image USB flash programming is already production-qualified.

## 1. Current capabilities

| Capability | Status as of October 30, 2026 |
| --- | --- |
| Persistent primary bootloader in SPI flash | Hardware PASS, seed-160 golden image |
| BTN2-held power-up enters USB DFU mode | Hardware PASS, persistent `FWTN` |
| USB enumeration, descriptors, vendor control requests | Hardware PASS, `1D50:614B` |
| AT25QL321 identification and secondary USB readback | Hardware PASS, `FWTN` and `FWTF` |
| Independent 25 MHz autonomous secondary reconfiguration | Hardware PASS, BTN2 released at cold boot |
| Secondary application at `0x201000` | Hardware PASS, 3,026-byte walking LEDs |
| Return from volatile `FWTF` to persistent `FWTN` | Hardware PASS after power cycle |
| Full-image DFU receiver, bounds, CRC and flash mock tests | Offline PASS |
| `FWTF` full-image firmware in JTAG-loaded FPGA SRAM | Hardware PASS for USB readback only |
| Full-image USB erase/program/FINISH to physical flash | **NOT YET hardware-qualified** |
| Power-loss-safe atomic update and automatic rollback | **NOT implemented** |

The primary is a small SERV RV32I SoC with firmware embedded in FPGA block
RAM. It is *not* the Hazard3 CPU or Doom application. The verified secondary
is a GateMate walking-LED design. Booting Doom as a ULX5M secondary is a
separate future integration task.

## 2. Boot sequence and hardware architecture

The ULX5M-GS uses the board's 25 MHz reference clock. A separate 25 MHz
clock domain drives `rtl/ulx5m_cfg_autoboot_25.v`, which controls the GateMate
`CC_CFG_CTRL` configuration command and `RECFG` sequence. A PLL supplies the
48 MHz SERV/USB domain. The two domains have a synchronized, latched mode
request; the configuration controller does not rely on CPU firmware to hand
off to the secondary.

At **SPI-active cold boot** (`SW1 OFF/OFF`), the FPGA first configures the
persistent primary stored at flash address `0x000000`:

- **BTN2 held before and through startup:** mode selection latches DFU. The
  primary runs SERV/USB, attaches its full-speed USB interface, and remains
  in DFU even after BTN2 is released.
- **BTN2 not held:** mode selection latches normal boot. The independent
  25 MHz controller issues the image-derived configuration command and
  reconfigures from flash `0x201000`. With the known-good secondary, walking
  LEDs start after approximately 2.68 seconds. The USB controller remains
  disabled in this mode.

In **JTAG configuration mode** (`SW1 ON/ON`), `openFPGALoader.exe -m` can load
an alternate primary into *volatile* FPGA configuration SRAM. This does not
replace the persistent primary. For a JTAG-loaded DFU image, keep BTN2 held
through the entire load and startup; releasing BTN2 too soon can latch normal
mode and prevent USB enumeration.

The RTL keeps the USB D+/D- pin placement and active-high D+ attach circuit
specific to the ULX5M-GS V005. Do not substitute ULX3S/ULX4M or TinyDFU
USB pin constraints. The independent 25 MHz handoff is a hardware-proven
feature and should not be changed just to develop the flash updater.

The SERV firmware is loaded into synthesized block RAM; there is no runtime
secondary CPU firmware upload. The 48 MHz Wishbone peripheral decode exposes
these firmware MMIO bases (`fw/config.h`):

| Base | Function |
| --- | --- |
| `0x80000000` | LED, button, PLL and mode status |
| `0x81000000` | Console UART logic (TX not wired to a board pin here) |
| `0x82000000` | USB controller |
| `0x83000000` | USB endpoint RAM |
| `0x84000000` | SPI flash controller |

The sixth Wishbone peripheral is the configuration-controller status/ACK
bridge; autonomous configuration control itself remains on the 25 MHz clock.
The flash SPI pins are released to configuration during normal-mode handoff,
preventing SERV firmware from competing with the FPGA configuration engine.

### LED indications (primary active)

| LED | Meaning |
| --- | --- |
| D7 | 48 MHz-domain heartbeat (blinks) |
| D6 | PLL locked |
| D5 | Startup mode selection latched |
| D4 | DFU mode selected |
| D3 | Normal mode selected (before secondary handoff) |
| D2 | Live BTN2 pressed indication |
| D1, D0 | Firmware-controlled status/witness LEDs |

A verified golden DFU startup after releasing BTN2 has D0/D1 ON, D2/D3
OFF, D4/D5/D6 ON, and D7 blinking. Normal-mode primary LEDs are not the
secondary walking-LED pattern. A blinking D7 alone does not prove that USB
is running.

## 3. SPI flash layout and image formats

Board U9 is an AT25QL321 (4 MiB / 32 Mbit), JEDEC `1F 42 16`. Erase sectors
are 4 KiB; page programming is limited to 256 bytes.

| Address range | Length | Purpose and policy |
| --- | ---: | --- |
| `0x000000..0x07FFFF` | 512 KiB | Primary FPGA image. **Protected during secondary DFU** |
| `0x080000..0x1FFFFF` | 1.5 MiB | Existing/unknown contents. **Reserved, do not erase** |
| `0x200000..0x200FFF` | 4 KiB | Reserved metadata/candidate sector. **Do not erase** |
| `0x201000..0x3FFFFF` | 2,093,056 bytes | Native secondary update window in opt-in `FWTF` |

Protection is a **software range policy**, not a claim of physical flash
write protection. No secondary writer should accept an arbitrary host target
address. The native secondary begins at exactly `0x201000`; the largest
legal secondary is `0x1FF000` bytes, not `0x200000`.

Two `.bit` files have very different roles:

- `build-ulx5m-gs/bootloader/top_ulx5m_gs_bootloader-PACK-ONLY.bit` is
  the **primary** FPGA bootloader built with the image-derived configuration
  handoff command. It belongs at the beginning of flash, not at `0x201000`.
- A **native secondary** is a separately packed GateMate image for address
  `0x201000`. The verified example recovered from flash is
  `build-ulx5m-gs/native-v41-secondary-3026.bit` (not created by a clean
  source checkout). Do not use the primary `.bit` as an updater payload.

The updater's host preflight accepts 256..2,093,056 bytes with GateMate
synchronization `D9 01 ED 96`, parses the command stream, requires a
12-byte terminal `CHG_STATUS`, and rejects a terminal reconfiguration
`JUMP`. This is structural validation, not cryptographic signing.

## 4. USB DFU interface and firmware profiles

The DFU-mode device enumerates as USB VID:PID **`1D50:614B`**, full speed,
interface class/subclass/protocol **`FE/01/02`**, DFU version **1.1**, with
64-byte control transfer blocks and no separate data endpoints. The visible
product descriptor is `ULX5M-GS FPGA (DFU Probe)`. Windows may display a
cached ULX4M-LS name in its USB tree; check VID:PID and the actual descriptor.

| Profile | Build selection | Function |
| --- | --- | --- |
| `FWTN` | `DFU_FULL_IMAGE=0` (default) | Golden, hardware-proven DFU and readback; restricted 4 KiB experimental native-slot writer, **not** a full-image updater |
| `FWTF` | `DFU_FULL_IMAGE=1` | Experimental full-image secondary writer; USB and readback proven in volatile SRAM, physical writing still unqualified |

`fw/Makefile.ulx5m-gs` selects the profile; both builds use the same canonical
FPGA RTL and `Makefile.ulx5m-gs`. The normal/default profile should not be
silently replaced by the experimental one. The USB updater refuses destructive
`--execute` unless firmware reports `FWTF`.

### Read and control protocol

| Request | Direction | Use |
| --- | --- | --- |
| `0x51` | Vendor IN | Legacy read-only three-byte JEDEC identification |
| `0x52` | Vendor IN | Legacy SPI flash read, up to 32 bytes |
| `0x53` / `0x54` | Vendor IN | Read-only USB EP0 diagnostics (test firmware) |
| `0x55` / `0x56` | Vendor IN / OUT | USB EP0 waveform snapshot read / capture arm (test firmware; no flash write) |
| `0x5A` | Vendor IN | `A251` signature, JEDEC bytes, flash status |
| `0x5B` | Vendor IN | AT25QL321 read at `wIndex:wValue`; up to 32 bytes |
| `0x58` | Vendor IN | `FLM1` 32-byte flash layout descriptor |
| `0x59` | Vendor IN | `STR1` DFU stream state, count, CRC32 and maximum |
| `0x5D` | Vendor IN | 24-byte `FWTN`/`FWTF` writer status and error |
| `0x5C` | Vendor OUT | Explicit ARM, only for the applicable writer profile |
| DFU `DNLOAD` | Class OUT | Consecutive, zero-based 64-byte blocks after ARM in `FWTF` |
| DFU `GETSTATUS` | Class IN | Block accept/state transitions |
| `0x5E` | Vendor OUT | Explicit FINISH/verification for the armed writer |

The diagnostic EP0 registers provide snapshots and a captured 48 MHz
IDDR waveform for USB troubleshooting; they are not part of the DFU update
contract. The standard DFU descriptor does not imply that a generic
`dfu-util -D` command can safely program this image. Use the project's
custom host protocol with explicit ARM/FINISH, not an unqualified generic
DFU uploader.

The host updater currently uses a 16-byte `U5WF` ARM payload containing
image length, CRC32 and an authorization token, plus fixed request fields.
Firmware checks chip identity, status, size and ordering before writing.
The flash state machine performs bounded 4 KiB erases, 256-byte page programs,
immediate page readback, CRC32 tracking and final readback CRC verification.
A separate host readback uses `0x5B` and compares every byte plus SHA256.
Failures are reported through DFU/writer status. Standard DFU `UPLOAD` is
not implemented; independent readback uses the vendor IN interface.

**Current limitation:** `FWTF` FINISH synchronously verifies the image and
scans all remaining secondary sectors for stale contents, erasing dirty
trailing sectors. This may require reading nearly 2 MiB even after a short
update; USB timeout behavior on physical SERV hardware remains unqualified.
The tail region must also be confirmed safe before the first write. No
atomic staging, signed image, rollback slot or automatic RECFG is provided.
Activation occurs only at a subsequent BTN2-released cold boot.

## 5. Newcomer setup (Windows 11 + WSL)

On a fresh Windows 11/WSL installation, install WSL and your Linux
distribution first, then obtain the source (or check out the matching
Hazard3-Doom revision). The following is a **new-checkout example**; do not
rerun `git clone` over an existing project directory:

```bash
mkdir -p /mnt/c/workspace
cd /mnt/c/workspace
sudo apt-get update
sudo apt-get install -y git make python3 gcc iverilog
# Git submodules resolve to revisions recorded by this checkout, not latest HEAD.
git clone https://github.com/gojimmypi/Hazard3-Doom.git
cd /mnt/c/workspace/Hazard3-Doom
git submodule update --init --recursive
cd /mnt/c/workspace/Hazard3-Doom/bootloader-serv
```

All subsequent WSL commands start from `bootloader-serv/`; Windows-native
USB/JTAG executables can be launched from WSL. **WSL does not require native
USB or `usbipd` for the verified workflow.** If your checkout is elsewhere,
substitute its actual `bootloader-serv` path. Installing the pinned GateMate
and RISC-V toolchains is a separate prerequisite; the APT packages above do
not provide those exact versions.

Confirm the following prerequisites:

- Python 3, GNU Make, native GCC and Git in WSL; Icarus Verilog (`iverilog`,
  `vvp`) for RTL tests.
- Pinned GateMate OSS CAD Suite **2026-07-20**, including `yosys`,
  `nextpnr-himbaechel` and `gmpack`, on the WSL `PATH`.
- RISC-V GCC/objcopy **12.2.0** (the known local installation is under
  `/opt/riscv/bin`). The Makefile checks the compiler version.
- The external SERV **1.4.0**, commit `7d9cde4`. The canonical Makefile
  checks this and can fetch the exact tagged source if it is absent.
- For JTAG: ULX5M-GS V005, Tigard, and the original, unmodified Windows
  `../bin/openFPGALoader.exe` v1.2.0. For USB: Windows Python 3 with PyUSB,
  working libusb backend and the USB-visible ULX5M device. A project-local
  `../bin/libusb-1.0.dll` was used successfully in the Windows workflow.

Install Windows PyUSB in the Python environment used by `py -3` if required
(e.g. `py -3 -m pip install pyusb` from Windows PowerShell). Windows must have
a USB driver/backend accessible to libusb. Do not change Tigard or unrelated
USB device drivers merely because WSL `lsusb` does not show the FPGA.

### Offline build and qualification

```bash
cd /mnt/c/workspace/Hazard3-Doom/bootloader-serv
make -f Makefile.ulx5m-gs show-settings
make -f Makefile.ulx5m-gs test-host
make -f Makefile.ulx5m-gs test
make -f Makefile.ulx5m-gs build SEED=160
make -f Makefile.ulx5m-gs qualify SEED=160
python3 tests/ulx5m_flash_install.py preflight
```

For an **experimental `FWTF` image**, first preserve the golden build and
recovery directory **outside** `build-ulx5m-gs/`, then run:

```bash
cd /mnt/c/workspace/Hazard3-Doom/bootloader-serv
make -f Makefile.ulx5m-gs build SEED=160 DFU_FULL_IMAGE=1
make -f Makefile.ulx5m-gs qualify SEED=160 DFU_FULL_IMAGE=1
```

Do not build both profiles simultaneously in the shared output directory;
they have the same output filename and different firmware. The seed alone
does not identify the firmware profile. A changed firmware image changes
FPGA routing; an earlier successful seed does not guarantee a later build.

The build packs `top_ulx5m_gs_bootloader-PACK-ONLY.bit`, derives its 27-byte
`CC_CFG_CTRL` handoff ROM from that actual packed image, and iterates up to
three times to obtain a match. `qualify` verifies the source fingerprint,
ROM, routing/timing, pin mapping and build stamp. It is **offline evidence**,
not proof of physical boot. There is no Makefile target that automatically
programs FPGA SRAM or flash.

### Run a candidate temporarily (no flash installation)

Power both boards off; set **SW1 ON/ON** for JTAG. Hold BTN2, power the ULX5M,
then power Tigard; keep BTN2 held through the JTAG load. With the board
powered before Tigard, JTAG detection has been reliable:

```bash
cd /mnt/c/workspace/Hazard3-Doom/bootloader-serv
../bin/openFPGALoader.exe -c tigard --freq 1000k --detect
../bin/openFPGALoader.exe -c tigard --freq 1000k -m \
  "$(wslpath -w "$PWD/build-ulx5m-gs/bootloader/top_ulx5m_gs_bootloader-PACK-ONLY.bit")"
```

`--detect` should show GateMate IDCODE `0x20000001`. `-m` loads volatile
FPGA configuration SRAM; **do not use `-f`** for this test. Keep BTN2 held
until D4=ON and D3=OFF, and only then release. D2 follows the button;
D4 stays ON. Windows should enumerate `1D50:614B`.

### Read-only USB verification (Windows-native Python from WSL)

The `--image` file must be a **real native secondary**, not the PACK-ONLY
primary. The example below uses the recovered v41 image; it exists only
when the user has recovered/supplied that known-good image, not on a fresh
checkout. A newcomer with a different installed secondary must use its
own exact matching native image.

```bash
cd /mnt/c/workspace/Hazard3-Doom/bootloader-serv
python3 tests/ulx5m_dfu_update.py \
  --image build-ulx5m-gs/native-v41-secondary-3026.bit
```

The preceding command is a **local-only format preflight**. To read and
compare physical flash through native Windows USB (without WSL USB):

```bash
cd /mnt/c/workspace/Hazard3-Doom/bootloader-serv
SCRIPT_WIN="$(wslpath -w "$PWD/tests/ulx5m_dfu_update.py")"
IMAGE_WIN="$(wslpath -w "$PWD/build-ulx5m-gs/native-v41-secondary-3026.bit")"
BIN_WIN="$(wslpath -w "$PWD/../bin")"
powershell.exe -NoProfile -Command \
  "\$env:PATH='$BIN_WIN;' + \$env:PATH; py -3 '$SCRIPT_WIN' --image '$IMAGE_WIN' --probe"
```

`--probe` sends **vendor IN reads only**. It works with both `FWTN` and
`FWTF`; it verifies all image bytes and the SHA256 without ARM, erase,
program, FINISH or RECFG. In the October 30 tests, the known-good secondary
was 3,026 bytes with SHA256
`68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd`.

To return to the persistent primary, power off both boards, set **SW1
OFF/OFF**, leave Tigard off, hold BTN2 before applying ULX5M power, then
release it after DFU startup. A `--probe` should now show `FWTN` instead of
`FWTF`. On a separate BTN2-released cold boot with Tigard powered off,
normal configuration should launch the walking-LED secondary.

### Persistent primary installation: guarded maintenance only

A new or blank board is **not** provisioned by simply running `build`.
The primary installer, `tests/ulx5m_flash_install.py`, is intentionally
restricted to a previously initialized flash with a present secondary.
For an already provisioned, independently recoverable board, the supported
maintenance workflow is: offline qualify candidate, JTAG-detect the device,
run the guarded installer, retain its two equal full 4 MiB pre-install
backups, and require a complete post-write flash match. It modifies only
the 512 KiB primary partition and attempts primary-only rollback if its
verification fails. The installer automatically reads flash in 128 KiB
chunks to avoid the Windows tool's large-read stack issue.

After validating the chosen candidate and arranging external recovery,
review `python3 tests/ulx5m_flash_install.py --help` and the `preflight`
output. The destructive operation is explicitly authorized by:

```bash
cd /mnt/c/workspace/Hazard3-Doom/bootloader-serv
python3 tests/ulx5m_flash_install.py install \
  --confirm I_AUTHORIZE_ULX5M_PRIMARY_512K_WITH_VERIFIED_ROLLBACK
```

**Do not run that install command on the proven golden primary as part of
normal setup or merely to test new DFU firmware.** It is a maintenance
operation that changes persistent flash, not a prerequisite for SRAM and
USB testing. The installer refuses an erased/missing secondary and does
not replace a factory-provisioning procedure for a blank chip. Preserve
`build-ulx5m-gs/flash-install-*` recovery sessions outside the build tree
before cleaning or rebuilding. Restoring a recorded primary requires the
separate guarded `restore` mode and its explicit authorization; it cannot
repair an unrelated or changed secondary partition.

## 6. Full-image DFU update: implemented but not yet a safe newcomer action

`tests/ulx5m_dfu_update.py` provides three modes:

- **Default (no flags):** validate a native secondary image locally; no USB.
- **`--probe`:** verify installed secondary over USB without changing flash.
- **`--execute` plus `--confirm`:** experimental in-place `FWTF` secondary
  erase/program/verification path. **Do not run until first physical-write
  qualification and recovery planning are complete.** `FWTN` is refused.

The source has sequential transfers, guarded ARM/status/FINISH, flash-sector
bounds, per-page and final CRC readback, stale-tail handling, and independent
host SHA256 comparison. Host mocks exercise realistic and maximum-sized
transfers, invalid ordering, aborted sessions and flash faults. **No full
physical write has passed as of this checkpoint.** The update is not atomic:
loss of power after erasure may leave the secondary unbootable; the verified
recovery entry is BTN2-held primary DFU, not automatic rollback. An invalid
secondary's normal-mode behavior is not yet qualified; keep BTN2 held when
recovering from an interrupted write.

The next engineering gate is to bound or restructure the potentially long
synchronous FINISH readback/tail scan and verify secondary-region use. Then
rerun host/RTL tests, build and qualify, reload `FWTF` into volatile SRAM,
and repeat read-only USB verification. Only after fresh full-chip backups
and an approved hardware procedure should the first physical USB write be
attempted. Do not modify known-good USB pin, clock or BTN2-selection RTL
without evidence of a defect.

## 7. Troubleshooting

| Symptom | Check first |
| --- | --- |
| JTAG does not detect FPGA | SW1 ON/ON; ULX5M powered before Tigard; cable/ground; expect `0x20000001` |
| `-m` says `Done`, but no USB | D3/D4 LEDs: BTN2 must remain held through *post-load* startup; reconfigure with D4=ON |
| USB shows older ULX4M label | Inspect actual descriptor `ULX5M-GS FPGA (DFU Probe)` and `1D50:614B` |
| WSL `lsusb` does not show board | Expected in the established setup; use Windows `py -3` and Windows libusb |
| `pyusb and a working libusb backend are required` | Test `py -3 -c "import usb.core"` on Windows; install PyUSB/backend there |
| Host says `FWTN` after JTAG trial | You are seeing the persistent golden profile, not the intended `FWTF` candidate |
| Image preflight rejects file | Check that it is a native *secondary*, not the primary PACK-ONLY image |
| `FWTF` update fails/interrupted | Do not normal-boot an uncertain secondary; power-cycle into BTN2 DFU for recovery |
| Build passes but USB fails | Check mode LEDs, physical enumeration, build hash and firmware profile before changing RTL |

## 8. Hardware-proven October 30 reference (dated, not permanent defaults)

- Golden seed-160 primary PACK-ONLY: **420,175 bytes**, SHA256
  `c41830bd09e0e924facd2425f10a8072878e59505d12b82aff533be7df8cfe27`.
- Full-image `FWTF` seed-160 candidate PACK-ONLY: **420,175 bytes**, SHA256
  `6c1bb2b8219f9b0c69c56725467b9a6c40f80a3a5caf6262dfe5769842528c97`.
- Known working native v41 secondary: **3,026 bytes**, SHA256
  `68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd`.
- Two matching full-flash pre-install backups: SHA256
  `09542df4b40bb6bcce00a327bb890f6a2d46099eae2e41f7a89e8e602614007d`.
- Verified golden primary recovery session:
  `build-ulx5m-gs/flash-install-20261030T155241133153Z`.
- The golden automatic boot and walking LEDs were confirmed with Tigard
  powered off. Both `FWTN` and JTAG-loaded `FWTF` successfully read back
  the entire native secondary through Windows USB, with matching SHA256.
- The latest archived `FWTF` build passed offline timing; routed clocks
  were approximately 67.96 MHz capability for 25 MHz and 49.06 MHz
  capability for 48 MHz. Physical USB readback subsequently passed.

The hashes identify **two distinct primary images** despite their shared
`top_ulx5m_gs_bootloader-PACK-ONLY.bit` filename. Verify which one is
present before JTAG testing or maintenance. Never treat a successful
seed number alone as a reproducibility check.

## 9. Source map

| Path | Responsibility |
| --- | --- |
| `Makefile.ulx5m-gs` | Canonical offline build, ROM derivation and qualification |
| `fw/Makefile.ulx5m-gs` | SERV firmware and opt-in DFU profile selection |
| `rtl/top_ulx5m_gs_bootloader.v` | SERV SoC, USB, flash peripherals and LED mapping |
| `rtl/ulx5m_btn2_boot_select.v` | BTN2 sampling and persistent mode latch |
| `rtl/ulx5m_cfg_autoboot_25.v` | Independent secondary configuration/RECFG controller |
| `fw/ulx5m_bootloader.c` | USB EP0 dispatch, flash read/status, DFU vendor interface |
| `fw/ulx5m_dfu_stream.[ch]` | Ordered 64-byte class DFU receiver and stream status |
| `fw/ulx5m_flash_hw_test.[ch]` | Experimental ARM/STATUS/FINISH and flash sink |
| `fw/ulx5m_flash_program.[ch]` | Bounded erase/page/write/readback state machine |
| `fw/ulx5m_flash_layout.[ch]` | Flash geometry, protected ranges and `FLM1` |
| `fw/ulx5m_at25ql321*` | JEDEC/status/SPI flash access and hardware binding |
| `tests/ulx5m_dfu_update.py` | Host image preflight, read-only probe, guarded updater |
| `tests/ulx5m_flash_install.py` | Separate JTAG primary installer/backups/rollback |
| `tests/test_ulx5m_bootloader.py` | Offline regression and host USB mocks |

Do not add one-off seed/version source files. Keep changes in the canonical
files, preserve the proven flash recovery artifacts, and distinguish mock
results from physical board tests.
