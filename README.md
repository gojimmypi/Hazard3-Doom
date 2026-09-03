[![CI](https://github.com/ulx3s/Hazard3-Doom/actions/workflows/ci.yml/badge.svg)](https://github.com/ulx3s/Hazard3-Doom/actions/workflows/ci.yml)
[![Check Verilog default_nettype](https://github.com/ulx3s/Hazard3-Doom/actions/workflows/check-nettype.yaml/badge.svg)](https://github.com/ulx3s/Hazard3-Doom/actions/workflows/check-nettype.yaml)
[![fpga-gojimmypi](https://github.com/ulx3s/Hazard3-Doom/actions/workflows/tt-fpga-ulx.yaml/badge.svg)](https://github.com/ulx3s/Hazard3-Doom/actions/workflows/tt-fpga-ulx.yaml)

# Hazard3-Doom for ULX3S and ULX4M

This repository contains the standalone monitor firmware, loadable Doom image,
UART upload tools, Hazard3-specific DoomGeneric port, and board build wrappers
used by the ULX3S and ULX4M Doom projects.

This `Hazard3-Doom` is intentionally separate from upstream [Wren6991/Hazard3](https://github.com/Wren6991/Hazard3). 
The compatible hardware is maintained on the [ulx-doom branch of the ulx3s/Hazard3 fork](https://github.com/ulx3s/Hazard3/tree/ulx-doom) 
and consumed as a pinned submodule under `third_party/Hazard3`. The Doom application and monitor remain owned by this repository.

See the Quick Start and overview: https://ulx3s.github.io/ulx-doom/

## Objective

Hazard3-Doom is an educational and experimental FPGA/RISC-V project.

It is provided for learning, research, development, and experimentation.
Hardware designs and software are provided without warranty. Users are
responsible for evaluating the suitability and safety of the project for
their intended application.

See the applicable [licenses](./LICENSES/README.md) for the complete warranty and liability terms.

## Repository scope

Included here:

- the resident Hazard3 monitor and UART image/WAD loaders;
- the linked Doom image and its monitor ABI;
- the ULX3S/ULX4M memory profiles and indexed HDMI software interface;
- host-side Python upload tools: `doom/upload-doom-image.py` and `doom/upload-wad.py`;
- [VisualGDB settings](./VisualGDB/) for building monitor ELF and JTAG debugging in Windows;
- pinned Hazard3 and DoomGeneric submodules in [./third_party/](./third_party/);
- ULX3S and ULX4M-LD board build wrappers;
- prebuilt FPGA bitstreams in [./bin/](./bin/);

Not included here:

- the RISC-V or FPGA toolchains;
- a Doom IWAD.

The monitor and Doom image require a compatible ULX3S or ULX4M Hazard3 FPGA
build implementing monitor ABI version 3, the documented SDRAM map, the cached
SDRAM path, and the indexed HDMI presentation registers.

## Source layout

```text
Hazard3-Doom/
|-- benchmarks/coremark      Hazard3 ULX3S specific CoreMark port
|-- bin/                     Windows executables, prebuilt FPGA bitstreams, and prebuilt Doom image.
|-- src/                     resident monitor entry point, linker script, and main
|-- doom/                    Doom port, image/WAD protocols, and host uploaders
|-- scripts/                 monitor, board, load, and submodule scripts
|-- VisualGDB/               Visual Studio + VisualGDB project settings
|-- third_party/Hazard3/     pinned Hazard3 hardware submodule
|-- third_party/doomgeneric/ pinned DoomGeneric source submodule
|-- docs/                    ownership and upstream contribution notes
|-- wads/                    local IWAD location (WAD files are ignored by Git)
`-- build/                   all generated outputs (ignored by Git)
```

## Prerequisites

The known working RISC-V toolchain prefix is:

```text
/opt/riscv/bin/riscv32-unknown-elf-
```

Override it when needed:

```bash
TOOLCHAIN_PREFIX=/path/to/riscv32-unknown-elf- ./scripts/build.sh
```

Python 3 and `pyserial` are required for UART uploads:

```bash
python3 -m pip install pyserial
```

## Clone and initialize submodules

Use a recursive clone so Hazard3, DoomGeneric, and the nested Hazard3 support
submodules are initialized together:

```bash
git clone --recursive https://github.com/ulx3s/Hazard3-Doom.git
```

For an existing checkout:

```bash
./scripts/setup-submodules.sh
```

or manually re-initialize submodules:

```bash
git fetch
git pull
git submodule sync --recursive
git submodule update --init --recursive
```

The compatibility command below initializes only DoomGeneric:

```bash
./scripts/setup-doomgeneric.sh
```

Normal builds use the pinned DoomGeneric fork. Development builds may use local
DoomGeneric changes by setting `HAZARD3_DOOM_ALLOW_DIRTY_DOOMGENERIC=1`.

## Board profiles

| Board       | Memory profile                  | System clock | External-memory clock/profile |
|-------------|---------------------------------:|-------------:|-------------------------------|
| ULX3S 85F    |    `64m`                         |       50 MHz | native SDR SDRAM              |
| ULX3S 12F    |    `32m` default; `64m` optional |       40 MHz | native SDR SDRAM              |
| ULX4M-LD 85F |    `64m`                         |       40 MHz | LiteDRAM user 60 MHz, init/ref 25 MHz |
| ULX4M-LS 85F |    `32m`                         |       50 MHz | native SDR SDRAM              |

The `64m` profile is the default for the 85F targets. The ULX3S 12F wrapper
defaults to `32m`. The profile used for the monitor, Doom image, and WAD
uploader must match.


ULX4M-LD uses device-specific generated LiteDRAM profiles. The current Micron
`MT41K512M16HA` population is hardware-qualified; the project also supports the
Alliance `AS4C256M16D3` population without changing the `ahb_litedram.v` AHB
bridge interface. Hazard3-Doom intentionally exposes only the 64 MiB software
map even when the physical DDR device is larger.

Current release validation uses seed 55 for ULX3S 85F and seed 65 for ULX3S
12F. ULX4M-LD now has a timing-passing and hardware-qualified 40/60 MHz
checkpoint: frozen-netlist seed 2 with HeAP timingweight 30, critexp 3, and
timing-driven rip-up. The Micron-populated board passed the complete DDR
qualification, heap stress, Doom smoke, and RV32-from-DDR execution tests. See
`docs/reference/board-profiles.rst` and `docs/reference/timing-sweeps.rst` for
the exact hashes and qualification caveats.


## Source and build ownership

The repository boundary is intentional:

| Item | Owner | Location |
|---|---|---|
| Doom monitor and loaders | Hazard3-Doom | `src/` and `doom/` |
| Complete board build wrappers | Hazard3-Doom | `scripts/build-*-doom.sh` |
| Hazard3 CPU and reusable SoC hardware | Hazard3 | `third_party/Hazard3/` |
| Board synthesis Makefiles and constraints | Hazard3 | `third_party/Hazard3/example_soc/synth/` |
| DoomGeneric upstream source | DoomGeneric | `third_party/doomgeneric/` |

The two complete board build wrappers were adapted from the temporary scripts
previously stored under `Hazard3/example_soc/synth/`. They now belong here
because they build the FPGA, the application monitor, and the Doom image as one
application release. The board Makefiles remain in Hazard3 because they build
reusable hardware targets without owning the Doom application.

See `docs/Hazard3-upstream-pr.md` for the proposed hardware-only upstream branch
and PR split.

## Build complete board targets

ULX3S 85F:

```bash
./scripts/build-ulx3s-doom.sh
```

ULX3S 12F:

```bash
./scripts/build-ulx3s-12f-doom.sh
```

ULX4M-LD 85F exploratory complete build:

```bash
ALLOW_TIMING_FAILURE=1 ./scripts/build-ulx4m-ld-doom.sh
```

The normal complete-build route still uses the board build flow rather than the
known-good sweep tuning, so this command is **not** the hardware-qualified
seed-2 route. Use the timing sweep with HeAP timingweight 30, critexp 3, and
timing-driven rip-up to select a timing-passing ULX4M-LD image. A complete
rebuild can also change the synthesized netlist when the resident monitor or
generated LiteDRAM profile changes, so rerun timing and DDR qualification for
the new netlist. `ALLOW_TIMING_FAILURE=1` is exploratory only.

The wrappers build the FPGA in the pinned Hazard3 submodule, then copy the final
bitstream into this repository:

```text
build/fpga_ulx3s.bit
build/fpga_ulx3s_12f.bit
build/fpga_ulx4m_ld.bit
build/hazard3-boot-monitor.elf
build/doom-image/hazard3-doom.h3d
```

Set `HAZARD3_ROOT` to test another Hazard3 checkout without changing the
submodule pointer:

```bash
HAZARD3_ROOT=/mnt/c/workspace/Hazard3 \
    ./scripts/build-ulx3s-doom.sh
```

## Build the resident monitor

The scripts are independent of the current working directory.

ULX3S:

```bash
./scripts/build.sh
```

ULX4M-LD:

```bash
HAZARD3_MEMORY_PROFILE=64m \
HAZARD3_SYS_CLK_HZ=40000000 \
    ./scripts/build.sh
```

To keep a software-only 40 MHz monitor separate from the resident preload while
testing an already-qualified FPGA image:

```bash
HAZARD3_BUILD_DIR="$PWD/build/ulx4m-ld-40mhz/monitor" \
HAZARD3_MEMORY_PROFILE=64m \
HAZARD3_SYS_CLK_HZ=40000000 \
    ./scripts/build.sh
```

ULX4M-LS:

```bash
HAZARD3_MEMORY_PROFILE=32m \
HAZARD3_SYS_CLK_HZ=50000000 \
    ./scripts/build.sh
```

Output:

```text
build/hazard3-boot-monitor.elf
build/hazard3-boot-monitor.map
```

## Load the resident monitor

Keep OpenOCD running on `localhost:3333` and disconnect VisualGDB before using
the batch loader:

```bash
./scripts/load-firmware.sh
```

An explicit ELF path may be supplied as the first argument:

```bash
./scripts/load-firmware.sh /path/to/hazard3-boot-monitor.elf
```

The loader halts the target, loads and compares the ELF sections, sets `_start`,
resumes the CPU, and disconnects.

For ULX4M-LD, the working Tigard arrangement is permanent: FT2232H Interface 0
uses the FTDI VCP driver for the 115200 UART, while Interface 1 uses libusbK for
OpenOCD JTAG (`ftdi channel 1`). The correct LFE5UM-85F IDCODE is
`0x01113043`. The established setup does not connect a target reset wire.

ULX4M DFU programming uses VID:PID `1d50:614b`, alternate setting 0. After
writing a user image, explicitly leave DFU to execute it:

```bash
./bin/dfu-util.exe -a 0 -e
```

Once the monitor is running, `s` should report `external_memory_ready=YES` and
LiteDRAM `init_done=YES`, `init_error=NO`, `pll_locked=YES`,
`user_clock_ready=YES`, and `ready=YES`. Run `q` for the complete DDR
qualification; the qualified checkpoint also passes `k`, `d`, and `x`.

Monitor commands used by Doom are:

```text
l    receive a packaged Doom image over UART
w    receive an IWAD into the reserved SDRAM region
j    launch the validated Doom image and IWAD
```

## Build the linked Doom image

ULX3S or ULX4M-LD:

```bash
HAZARD3_MEMORY_PROFILE=64m ./doom/build-doom-image.sh
```

ULX4M-LS:

```bash
HAZARD3_MEMORY_PROFILE=32m ./doom/build-doom-image.sh
```

Output:

```text
build/doom-image/hazard3-doom.elf
build/doom-image/hazard3-doom.map
build/doom-image/hazard3-doom.bin
build/doom-image/hazard3-doom.h3d
```

A compile-only object-size report is available with:

```bash
./doom/build-size-probe.sh
```

Its generated objects are placed under `build/doom-size-probe/`.

## Upload the Doom image and IWAD

**NOTE:** If Doom is _already_ running, connect to the UART with a serial terminal 
such as putty and press `Ctrl-X` to exit to monitor program that will listen 
for a new upload. See also the [return-to-monitor.py](./scripts/return-to-monitor.py) 
and [restart-from-monitor.py](./scripts/restart-from-monitor.py) scripts.

Close PuTTY or any other program that owns the UART port.

Upload the executable image without launching it:

```bash
python3 doom/upload-doom-image.py \
    build/doom-image/hazard3-doom.h3d \
    --port COM7
```

PowerShell:

```powershell
py .\doom\upload-doom-image.py `
    .\build\doom-image\hazard3-doom.h3d `
    --port COM7
```

Then upload a legally obtained IWAD and launch:

```powershell
py .\doom\upload-wad.py `
    C:\path\to\doom1.wad `
    --port COM7 `
    --launch
```

For ULX4M-LS, add:

```text
--memory-profile 32m
```

The default `64m` uploader profile is correct for ULX3S and ULX4M-LD.

Expected transfer markers:

```text
H3L READY
H3L DATA
H3L OK
H3W READY
H3W DATA
H3W OK
```

Expected startup markers include:

```text
Doom SDRAM image startup
  monitor ABI: PASS
Doom platform: cached indexed renderer + block-RAM HDMI initialized
Doom renderer: first indexed block-RAM frame queued
Doom interactive HDMI loop: READY
```

## Memory map

The internal 128 KiB SRAM map is shared by all targets:

- `0x00000000-0x0000ffff`: monitor, traps, and monitor/Doom stack
- `0x00010000-0x0001f9ff`: Doom 320x200 indexed working screen
- `0x0001fa00-0x0001ffff`: unused internal SRAM

The `64m` profile used by ULX3S and ULX4M-LD is:

- `0x20000000-0x23ffffff`: physical 64 MiB external memory
- `0x24000000-0x27ffffff`: uncached diagnostic alias
- `0x20100000-0x203fffff`: cached linked Doom image
- `0x20400000-0x22bfffff`: cached Doom heap and zone memory
- `0x22c00000-0x23bfffff`: cached IWAD reservation, 16 MiB
- `0x23c00000-0x23ffffff`: uncached video reservation

The `32m` ULX4M-LS profile is:

- `0x20000000-0x21ffffff`: physical 32 MiB SDRAM
- `0x24000000-0x25ffffff`: uncached diagnostic alias
- `0x20100000-0x203fffff`: cached linked Doom image
- `0x20400000-0x20ffffff`: cached Doom heap, 12 MiB
- `0x21000000-0x21bfffff`: cached IWAD reservation, 12 MiB
- `0x21c00000-0x21ffffff`: uncached video reservation

The HDMI controller registers remain at `0x4000c000`.

## Rendering and controls

The standard Doom build renders a 320x200 8-bit indexed screen and presents
completed frames through the direct APB-to-EBR path, swapping the inactive
block-RAM framebuffer during vertical blank. A hardware palette converts
indices to RGB332 during scanout.

An experimental native 400x240 renderer/source mode is available by setting
`HAZARD3_DOOM_HDMI_RESOLUTION=400x240`; 320x200 remains the default.

UART controls:

```text
Escape      menu/back
W / S       forward/back or menu up/down
A / D       turn or adjust menu value
Z / C       strafe left/right
F or Space  fire
E           use/open
M or Tab    automap
P           pause
1-7         select weapon
Enter       select
Ctrl-X      exit Doom and return to the monitor
```

Sound remains stubbed in this milestone.

## VisualGDB

For Windows users, the VisualGDB project settings are included under `VisualGDB/`.

The target ELF is `build/hazard3-boot-monitor.elf`. The GDB startup helper is
`scripts/hazard3-debug.gdb`. Per-user `.user` files are intentionally excluded.

## Tiny Tapeout

These files are includes only for testing the Tiny Tapeout workflows:

- `info.yml`
- `src/config.json`
- `src/project.v`
 
## Licensing and WAD files

DoomGeneric is licensed under GPL-2.0 and is included as a pinned submodule.
Hazard3 is licensed under Apache-2.0 and is included as a pinned submodule. The
original Hazard3-Doom files should receive an explicit project license before
public release.

Do not commit or redistribute commercial Doom IWAD files. Obtain an IWAD
legally and keep it outside Git or under the ignored `wads/` directory.

### Discord channel

- [https://discord.gg/qwMUk6W](https://discord.gg/qwMUk6W) (problems/question/general chat)

### Gitter channel

- [https://gitter.im/ulx3s/Lobby](https://gitter.im/ulx3s/Lobby) (Focused on development)

### Email

- [ulx3s.fpga@gmail.com](ulx3s.fpga@gmail.com) (If you do not use chats)
