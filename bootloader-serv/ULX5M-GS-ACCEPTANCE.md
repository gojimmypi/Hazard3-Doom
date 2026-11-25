# ULX5M-GS SERV bootloader: independent acceptance test

This procedure tests the persistent **FWTF** (full-image USB DFU) primary
bootloader on an ULX5M-GS V005 GateMate board. It is intended for a person
using a fresh `Hazard3-Doom` source clone on **native Linux** or
**Windows 11 with WSL2**. The runner detects the host environment; no
platform flag is required.

The single interactive runner is `tests/ulx5m_acceptance.py`. It builds the
firmware and LED secondary locally, runs the canonical offline tests, pauses
for physical power/switch observations, verifies USB identity and readback,
and (only with a second explicit confirmation) rewrites the **same** known
secondary image over USB. It logs all automatic checks and operator responses.

**Scope:** the test establishes working normal boot, BTN2 DFU entry,
full-image DFU update, independent readback, and post-update recovery. Optional
JTAG audits measure whole-chip preservation. It does **not** prove atomic
power-failure recovery, lifetime reliability, or correct operation with every
possible user bitstream.

## 1. Hardware and software prerequisites

- ULX5M-GS V005 board with a Renesas AT25QL321 4 MiB SPI configuration flash.
- **One USB cable**, connected to the host PC, supplies both **power and
  USB data** to the ULX5M. There is no separate data-only USB cable.
- Two-section configuration switch **SW1** and push button **BTN2**.
- A *preinstalled, working FWTF primary* and the reference native LED secondary
  at `0x201000` for the USB-only full test. A Git clone does not install these
  images onto a blank FPGA board.
- Alternatively, for `--install-primary`, an existing **FWTN** golden primary
  and that **same verified native LED secondary**, plus a Tigard JTAG adapter.
  The guarded installer refuses an apparently blank secondary. A completely
  blank board requires a separately reviewed initial bring-up procedure.
- **Native Linux:** Python 3, PyUSB with libusb-1.0, and USB permission to
  access `VID_1D50:PID_614B` as a normal user. USB probing/programming runs
  directly under Linux (no PowerShell or Windows executables).
- **WSL2:** Windows 11 with WSL2/Ubuntu, Windows Python 3 (`py -3`), PyUSB,
  a working Windows libusb backend/driver for `VID_1D50:PID_614B`, PowerShell,
  and `wslpath`. USB operations run in Windows while FPGA builds run in WSL.
- **Either Linux environment:** `git`, `make`, `gcc`, `python3`, `iverilog`,
  `vvp`, `yosys`, `nextpnr-himbaechel`, and `gmpack`.
- **OSS CAD Suite 2026-07-20** (the hardware-tested toolchain) and RISC-V GCC
  **12.2.0** with matching `objcopy`. Do not silently substitute a newer CAD
  suite or RISC-V compiler for a reference-hash test.
- **Optional Tigard/JTAG audit or primary installation:** on native Linux,
  install native `openFPGALoader` **v1.2.0** and make it available on `PATH`.
  The guarded JTAG installer requires that exact reported version. On WSL,
  use the unmodified Windows `openFPGALoader.exe` **v1.2.0** at
  `Hazard3-Doom/bin/openFPGALoader.exe`, SHA-256
  `9be9dcdb6e00e6d473f1031a459658561c95630584b1a5739aa2b8788237adea`.
  On native Linux, check Tigard USB permissions separately before attempting
  the optional audit. A matching version string alone cannot verify the
  native binary's provenance.

Download/reference pages for setup:

- Source: <https://github.com/gojimmypi/Hazard3-Doom>
- FPGA toolchain: <https://github.com/YosysHQ/oss-cad-suite-build/releases>
- RISC-V toolchain: <https://github.com/riscv-collab/riscv-gnu-toolchain/releases>
- Python for Windows (WSL path only): <https://www.python.org/downloads/windows/>
- PyUSB: <https://github.com/pyusb/pyusb>
- Zadig driver setup (only if required): <https://zadig.akeo.ie/>
- openFPGALoader releases: <https://github.com/trabucayre/openFPGALoader/releases>

For Ubuntu (native Linux or WSL) base prerequisites:

```bash
sudo apt update
sudo apt install -y git make gcc python3 python3-usb libusb-1.0-0 iverilog
```

Install the pinned OSS CAD Suite and RISC-V GCC separately and add their
`bin` directories to the Linux/WSL `PATH`; this document does not assume a
universal installation directory. Verify:

```bash
yosys --version
nextpnr-himbaechel --version
gmpack --help
riscv32-unknown-elf-gcc -dumpfullversion
```

The exact RISC-V GCC prefix can differ; the canonical firmware Makefile
searches for supported cross compiler prefixes. The reported version must be
`12.2.0` and the matching `objcopy` must be available.

On **native Linux**, check Python USB support:

```bash
python3 -c "import usb.core, usb.backend.libusb1; assert usb.backend.libusb1.get_backend() is not None; print('PyUSB/libusb available')"
```

To allow normal-user USB access on a local Linux desktop using systemd-logind,
create an optional device-specific `udev` rule (requires administrator access):

```bash
printf '%s\n' 'SUBSYSTEM=="usb", ATTR{idVendor}=="1d50", ATTR{idProduct}=="614b", TAG+="uaccess"' | sudo tee /etc/udev/rules.d/70-ulx5m-dfu.rules
sudo udevadm control --reload-rules
```

Unplug and reconnect the board's single USB cable, then enter BTN2 DFU mode
again. Non-desktop/remote Linux sessions may need a different local USB access
policy; do not use `sudo` to run the acceptance script. The rule applies only
to `1D50:614B` and is not a blanket permission change.

For **WSL2**, install PyUSB in **Windows** Python using Windows PowerShell
(not the WSL shell):

```powershell
py -3 -m pip install pyusb
py -3 -c "import usb.core; print('PyUSB available')"
```

PyUSB alone does not install a compatible Windows libusb driver. Ensure the
ULX5M DFU interface is accessible on Windows. **Do not change drivers for
Tigard, other FPGA boards, or unrelated USB devices.** Both platforms check
`1D50:614B`, not the similarly named ULX4M-LS DFU interface.

## 2. Fresh-clone preparation

Clone the exact, published **FWTF-capable revision used for the test**. The
current default branch on GitHub might not yet contain the profile-guard
changes from the October 31, 2026 hardware qualification. The project
maintainer must publish a reviewed revision (and identify its commit SHA)
before asking other people to run this procedure. A historical unqualified
revision is not interchangeable with the tested one.

On **native Linux**:

```bash
mkdir -p ~/workspace
cd ~/workspace
git clone --recurse-submodules https://github.com/gojimmypi/Hazard3-Doom.git
cd ~/workspace/Hazard3-Doom/bootloader-serv

git rev-parse HEAD
python3 tests/ulx5m_acceptance.py --mode full --plan
```

On **Windows/WSL2** instead, use the WSL shell:

```bash
mkdir -p /mnt/c/workspace
cd /mnt/c/workspace
git clone --recurse-submodules https://github.com/gojimmypi/Hazard3-Doom.git
cd /mnt/c/workspace/Hazard3-Doom/bootloader-serv

git rev-parse HEAD
python3 tests/ulx5m_acceptance.py --mode full --plan
```

The plan prints `host=linux` or `host=wsl`. On native Linux, the runner uses
PyUSB directly for enumeration, readback, and programming, and the native
`openFPGALoader` executable for optional Tigard operations. On WSL, it uses
Windows PowerShell/Python for USB and the verified Windows programmer for JTAG.

If this runner is not yet committed to the selected revision, copy the two
files from the accompanying ZIP into their canonical repository paths:

```text
bootloader-serv/tests/ulx5m_acceptance.py
bootloader-serv/ULX5M-GS-ACCEPTANCE.md
```

The runner rejects a checkout that lacks the profile-qualified FWTF build
logic (the `DFU_FULL_IMAGE=1` build path and `FWTF` installer profile receipt).
**Do not bypass that guard or install a bitstream from an unknown branch.**
It also verifies the two built images against these specific hardware-tested
reference digests:

| Image | Expected bytes | Reference SHA-256 |
| --- | ---: | --- |
| FWTF primary, seed 160 | 420,175 | `c73b8d6fe1ac1150ad3e3bba72c6d64664ee495185fade339f188f628dcfe167` |
| Native LED secondary, seed 160 | 7,096 | `25334f8fb384c413ee192d1ceab8b4940604eb53972217fbb232baba33e507f5` |

If the Git revision/toolchain produces different hashes, stop and investigate
version drift. This conservative test intentionally does not accept arbitrary
new primary or secondary bitstreams.

## 3. Run the script

All commands below start in the **bootloader-serv** directory, whether the
checkout is under `~/workspace` (native Linux) or `/mnt/c/workspace` (WSL).

### Offline qualification: no hardware required

```bash
python3 tests/ulx5m_acceptance.py --mode offline
```

The script executes the existing canonical host/RTL/Python tests; builds and
qualifies FWTF and the LED secondary using seed 160; validates hashes, timing,
image-derived handoff command, USB/flash pin mapping, and source manifest;
then runs offline installation and secondary-update preflights. It does not
connect to a device or write FPGA flash.

### Full USB-only acceptance: already-installed FWTF primary

```bash
python3 tests/ulx5m_acceptance.py --mode full --cycles 3
```

This **requires a known-good FWTF primary and reference LED secondary already
installed**. The script stops at each physical step. Follow its instructions
exactly, observe the LEDs, and type `PASS` only if that observation is correct;
any other response stops. In normal boot, **no USB DFU enumeration is
expected** because the secondary owns the FPGA. During DFU, expect:

- SW1 OFF/OFF; BTN2 held **before** reconnecting USB and through mode-latch;
  D4 ON, D3 OFF, D5/D6 ON, D7 blinking, **no walking LEDs**.
- After releasing BTN2, Linux detects USB `1D50:614B` through PyUSB, or
  Windows enumerates `USB\\VID_1D50&PID_614B` when using WSL.
- The read-only FWTF probe identifies AT25QL321 `1F 42 16` and verifies the
  installed 7,096 bytes with the exact reference SHA-256.
- With BTN2 released during a fresh power-up, the walking/blinking LED
  secondary begins running automatically after a short startup interval.

The script repeats cold normal boot and recovery three times, then asks for
**one separate exact write authorization**:

```text
REPLACE-SECONDARY-0x201000
```

Without that response, it does **not** invoke a write. With authorization,
it invokes the existing guarded USB updater to rewrite the same known image
at `0x201000`, verifies the firmware's response and independent host-controlled
readback, then repeats normal boot, BTN2 recovery, and read-only verification.
The flash update is **in-place, not atomic**. Never remove power during a
write; if it fails, stop and retain the log. Hold BTN2 at startup to re-enter
recovery before attempting any further normal boot.

### Extended full-chip audit (optional; Tigard required)

```bash
python3 tests/ulx5m_acceptance.py --mode full --cycles 3 --audit-flash
```

This adds read-only JTAG snapshots around the USB rewrite using the native
Linux or Windows/WSL programmer, as detected. The runner pauses
for power-off/SW1 ON/ON/Tigard setup, reuses the **existing guarded JTAG flash
reader** with per-chunk JEDEC checking, captures *two matching 4 MiB baseline
dumps*, and captures a further 4 MiB dump after the USB update. It compares
**all 4,194,304 bytes** before and after. Since the secondary rewrite uses the
same image, the expected whole-chip result is byte-for-byte identical,
including primary, secondary-sector tails, and every other flash region.
It then prompts to return to SW1 OFF/OFF and verifies USB DFU recovery again.

This optional audit addresses a limitation of the USB-only run: USB readback
of the secondary plus host tests does not by itself prove *all other physical
flash bytes* are unchanged. JTAG read reliability is subject to the known
intermittent shifted-read issue. The guarded reader rejects the wrong JEDEC
ID and the runner requires two identical, valid baseline dumps.

### Initial primary replacement (advanced; authorized separately)

Only if the board already contains the verified `FWTN` golden primary and
**the same** working native LED secondary:

```bash
python3 tests/ulx5m_acceptance.py --mode full --install-primary --audit-flash
```

The runner first uses the golden primary for a read-only USB secondary check.
It then pauses for **SW1 ON/ON JTAG mode** (change switches only when the
board is powered off; power the board before Tigard), identifies the GateMate,
and requests the exact, **separate primary write authorization**:

```text
I_AUTHORIZE_ULX5M_PRIMARY_512K_WITH_VERIFIED_ROLLBACK
```

The platform-aware guarded installer backs up the **entire 4 MiB flash twice**,
rejects shifted/invalid JTAG reads, replaces only the 512 KiB primary at
`0x000000..0x07FFFF`, verifies the entire flash, and attempts primary-only
rollback on a verification failure. The runner also copies the recovery
session outside the checkout under `~/ulx5m-primary-recovery/` after success.
Do **not** use this command on a factory-empty board, a board with unknown
flash, or one already running FWTF. Never move SW1 with power applied.

**No unattended writes:** CLI flags select a plan; actual primary and
secondary writes each require their own typed consent after an operator
physical pause. The runner does not independently retry interrupted writes or initiate a
new rollback. The guarded primary installer may automatically attempt
primary-only rollback **within the explicitly authorized installation** if
verification fails; the failure and recovery session must still be reviewed.

## 4. PASS/FAIL and collected evidence

Each invocation writes a unique report inside:

```text
bootloader-serv/build-ulx5m-gs/acceptance-<UTC>/report.txt
```

A complete USB-only run ends with:

```text
[PASS] CORE FWTF BOOTLOADER ACCEPTANCE COMPLETE
```

A complete extended audit additionally reports:

```text
[PASS] byte-for-byte identical 4 MiB flash after USB rewrite
```

The report records the detected host (`linux`/`wsl`), source commit,
build profile, toolchain/build output,
qualification results, USB transfer and independent readback, and all operator
confirmations. Share the `report.txt`, Git revision, board revision, and an
accurate description of any nonstandard hardware/setup with the maintainer.
Do **not** share entire flash dumps unless specifically requested; they may
contain unrelated private or custom user images.

If the run stops, do not mark it PASS. Read the first `[FAIL/STOP]` or command
failure, preserve existing build/recovery files, and report the stage. A
missing compiler, unpublished source change, USB driver mismatch, or operator
pause is **not** itself evidence that the FPGA RTL failed.

## 5. Known limitations and failure history

- **One-bit JTAG SPI flash reads:** previously observed as a reproducible
  right-bit shift within 128 KiB read transactions, with a wrong JEDEC value
  (`0F A1 0B` instead of `1F 42 16`). The same unmodified programmer later
  produced repeated correct reads after SW1 reseating. **The physical cause
  is not conclusively identified**, so it must not be called a harmless fluke.
- **Unexpected absence of USB during walking LEDs:** normal secondary mode
  intentionally does not enumerate as DFU. The persistent FWTF primary was
  subsequently shown to enter DFU correctly when BTN2 was held across the
  power-on latch window. This observation alone did not establish a firmware
  defect.
- **Routing/seed sensitivity:** certain earlier builds failed timing or
  placement. The qualified seed-160 FWTF build met its constraints and was
  reproduced byte-for-byte in the verified local toolchain. Other tool versions
  or source revisions must be requalified; timing failure is not a USB fluke.
- **In-place flash writes:** interrupted updates remain an explicit recovery
  scenario. The firmware/host mock tests cover abort and interruption, but
  physical power-loss and repeated long-duration reliability have not been
  demonstrated. Do not advertise power-loss-safe atomic updating.

The proven core functionality is working. These specific limitations are
why a passing acceptance test should be reported as **functional
qualification of the tested hardware, firmware, source revision, and operating
procedure**, not an unconditional reliability guarantee.
