# FPGA USB DFU bootloaders: ULX3S, ULX4M, ULX5M-GS

This directory is a clean source tree for the supported bootloaders.
The existing ECP5 ULX3S/ULX4M build remains under `Makefile`.
The GateMate ULX5M-GS has one canonical build: `Makefile.ulx5m-gs`.
Milestones and experimental branches belong in Git history, not in
parallel versioned source files, Makefiles, or test scripts.

## ULX5M-GS offline workflow

From `bootloader-serv/` in WSL:

```sh
make -f Makefile.ulx5m-gs prepare
make -f Makefile.ulx5m-gs test
make -f Makefile.ulx5m-gs build SEED=60
make -f Makefile.ulx5m-gs qualify SEED=60
```

`prepare` generates the initial 27-byte handoff ROM and USB microcode.
`test` requires Python 3, native GCC, Icarus Verilog and vvp.
`build` requires the pinned GateMate OSS CAD Suite, `gmpack`, and a RISC-V
GCC/objcopy toolchain. It verifies the external SERV 1.4.0 checkout at
commit `7d9cde4` (cloning it to `third_party/serv` if absent). Use the
locally pinned toolchain; **do not switch versions during timing comparison**.

The ULX5M primary uses the board 25 MHz oscillator through one CC_IBUF,
feeds a 25 MHz global clock for autonomous CC_CFG_CTRL, and the PLL and
a separate global buffer for 48 MHz SERV/USB. The two domains communicate
only via the double-synchronized, latched normal-mode request; the CFG
controller remains independent of SERV firmware and USB activity.
In normal mode SERV only displays a pre-handoff D0 witness; legacy
firmware-initiated SPI handoff and image-probing code have been removed.

The build creates a local `build-ulx5m-gs/bootloader/` directory. The
packed image has a stable `top_ulx5m_gs_bootloader-PACK-ONLY.bit` name;
`qualify` independently checks exact input hashes, a matching packed-image
ROM, global clock connections, routed 25/48 MHz timing, and flash pad mapping.
A failed route or stale build cannot produce a qualified result. There is
no automatic FPGA SRAM/flash program, JTAG, or DFU install target.

**Not yet proven on ULX5M-GS hardware:** autonomous secondary SPI-active
boot and reliable normal-mode LED behavior. The USB DFU writer is still a
restricted, explicitly armed 4 KiB native image test, not a general-purpose
image updater. Do not install the PACK-ONLY image as persistent stage0.

## Existing ULX3S / ULX4M builds

```sh
make MODEL=ulx3s BOARD=ulx3s-v20
make MODEL=ulx4m BOARD=ulx4m-v002 DEVICE=um-85k
```

Follow your working local board settings if different. Repository-root
CI scripts outside this replacement directory may still reference legacy
ULX5M filenames; update those references before expecting CI to pass.
