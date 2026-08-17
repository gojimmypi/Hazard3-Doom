# Hazard3 upstream branch and PR plan

## Current temporary dependency

Hazard3-Doom currently pins:

```text
Repository: https://github.com/gojimmypi/Hazard3.git
Branch: ulx3s-dev
Commit: c9c22a56caf68086edad98ee65dcffe67fc088e3
```

This branch contains both reusable hardware support and application files. It
is suitable as a temporary integration dependency, but not as the final
upstream pull request.

## Files now owned by Hazard3-Doom

The following application orchestration scripts were copied and adapted into
Hazard3-Doom:

```text
Hazard3 example_soc/synth/build-ulx3s-doom.sh
    -> Hazard3-Doom scripts/build-ulx3s-doom.sh

Hazard3 example_soc/synth/build-ulx4m-ld-doom.sh
    -> Hazard3-Doom scripts/build-ulx4m-ld-doom.sh
```

The following application tree is also owned by Hazard3-Doom:

```text
Hazard3 example_soc/synth/hazard3-fw/
    -> Hazard3-Doom src/, doom/, scripts/, and VisualGDB/

Hazard3 example_soc/hazard3-debug.gdb
    -> Hazard3-Doom scripts/hazard3-debug.gdb
```

These files still exist on the temporary `ulx3s-dev` branch. Delete them from
the cleaned Hazard3 branch before opening an upstream PR.

## Files that remain Hazard3-owned

The hardware-only branch must retain the files required to synthesize reusable
ULX3S and ULX4M targets. The exact set should be reviewed and reduced from
`ulx3s-dev`, but the current ULX3S and ULX4M-LD build depends on these groups:

```text
example_soc/fpga/fpga_ulx3s.f
example_soc/fpga/fpga_ulx3s.v
example_soc/fpga/fpga_ulx4m_ld.f
example_soc/fpga/fpga_ulx4m_ld.v
example_soc/fpga/pll_25_50_250.v
example_soc/fpga/ulx3s_hdmi_framebuffer.v
example_soc/fpga/ulx3s_hdmi_test_pattern.v

example_soc/soc/ahb_litedram.v
example_soc/soc/ahb_sdram.v
example_soc/soc/apb_gpio.v
example_soc/soc/cache_tags_zero.hex
example_soc/soc/example_soc.v
example_soc/soc/soc.f
example_soc/soc/ulx3s_sdram_controller.v

example_soc/synth/ULX3S.mk
example_soc/synth/ULX4M_LD_85F.mk
example_soc/synth/fpga_ulx3s.lpf
example_soc/synth/fpga_ulx4m_ld.lpf

example_soc/third_party/LiteDRAM/LICENSE
example_soc/third_party/LiteDRAM/README.md
example_soc/third_party/LiteDRAM/generated/LITEDRAM_VERSIONS.txt
example_soc/third_party/LiteDRAM/generated/litedram_ulx4m_cpu.yml
example_soc/third_party/LiteDRAM/generated/litedram_ulx4m_cpu.v
example_soc/third_party/LiteDRAM/generated/litedram_ulx4m_cpu_rom.init
example_soc/third_party/LiteDRAM/generated/litedram_ulx4m_cpu_sram.init

example_soc/ulx3s-openocd.cfg
example_soc/ulx4m-openocd.cfg
```

ULX4M-LS and standalone blinky files should be included only if they are
independently validated and documented as general Hazard3 example targets.

## Files to exclude from an upstream PR

Do not include application, generated host output, personal, or redistributed
tool files:

```text
README_DDR_test.md
README_DOOM.md
example_soc/ULX3S_ULX4M_SHARED_BUILD_SUPPORT_R5A.md
example_soc/ULX4M_ULX3S_DOOM_PERFORMANCE_R5.md
example_soc/synth/hazard3-fw/
example_soc/synth/build-ulx3s-doom.sh
example_soc/synth/build-ulx4m-ld-doom.sh
example_soc/hazard3-debug.gdb
example_soc/openocd_tigard.bat
example_soc/synth/blinky_build.sh
example_soc/synth/build_flash.sh
example_soc/synth/fujprog-v48-win64.exe
example_soc/synth/openFPGALoader.exe
doc/images/ULX4M-USB-enumeration.jpg
```

Do not copy the root `.gitignore` change wholesale. Its VisualGDB, Doom WAD,
firmware ELF, and temporary-directory rules belong to the application work and
should be reviewed separately from reusable hardware support.

The generated LiteDRAM Verilog and initialization files need a maintainer
policy decision. Prefer a checked-in LiteDRAM configuration and a documented
regeneration command. Commit generated output only if upstream explicitly
accepts generated HDL for reproducible builds.

## Remove Doom-specific language from reusable hardware

Before upstream review, replace application-specific comments and parameter
names with hardware descriptions. Examples currently include:

```text
Doom frame
IWAD
Performance-R5
Doom image, heap and IWAD accesses
```

The hardware should instead describe:

```text
indexed 320x200 framebuffer
cacheable external-memory window
uncached diagnostic window
uncached video aperture
ULX3S 85F HDMI and SDR SDRAM target
ULX4M-LD 85F HDMI and LiteDRAM DDR3 target
```

The memory aperture parameters should remain configurable and should not encode
Doom ownership in the generic SoC interface.

## Synthesis script issue to resolve

The Hazard3 Makefiles currently assign:

```make
PLACER=heap
```

The pinned `fpgascripts/synth_ecp5.mk` does not consume `PLACER`; it invokes
`nextpnr-ecp5` with `--placer sa` directly. Before an upstream PR, either remove
the unused Makefile assignments or submit a separate `fpgascripts` change that
adds a supported placer variable. Do not imply that the current builds use the
heap placer when they use the simulated-annealing placer.

## Recommended branch creation

The current official default branch is `stable`. Create the clean staging
branch from the current upstream stable head unless the maintainer asks for
another base:

```bash
cd /mnt/c/workspace/Hazard3

git remote add upstream https://github.com/Wren6991/Hazard3.git
git fetch upstream --prune

git switch -c ulx-doom upstream/stable
```

If the `upstream` remote already exists, omit the `git remote add` command.
Restore only reviewed hardware files from `ulx3s-dev`:

```bash
git checkout ulx3s-dev -- <reviewed-hardware-file-list>
```

Do not merge `ulx3s-dev` wholesale. Its history contains the application tree,
binaries, generated files, and experimental bring-up commits.

## Recommended PR split

Use `ulx-doom` only as a staging branch. Prepare smaller review branches from
it:

```text
1. ulx-external-memory
   Generic cached AHB external-memory support, SDR SDRAM controller, APB GPIO,
   and parameterized diagnostic/video apertures.

2. ulx3s-hdmi
   ULX3S 85F top level, HDMI framebuffer, source list, constraints, Makefile,
   and OpenOCD compatibility update.

3. ulx4m-ld
   ULX4M-LD 85F top level, LiteDRAM adapter/configuration, constraints,
   Makefile, and OpenOCD configuration.
```

Each branch should build independently and should contain a focused README with
commands, board revision, required tools, expected output filename, and tested
hardware status.

## Validation required before PR

For every target included in a PR:

```text
- Recursive clone succeeds.
- Synthesis starts from a clean checkout.
- Yosys and nextpnr complete.
- The bitstream programs successfully.
- Hazard3 JTAG identifies and halts the CPU.
- UART monitor output is correct.
- External memory qualification passes.
- HDMI test pattern or framebuffer test passes without Doom.
- git status remains clean except for ignored build outputs.
```

After a cleaned hardware branch is available, update the Hazard3-Doom
`.gitmodules` branch from `ulx3s-dev` to `ulx-doom` and record the new submodule
commit.
