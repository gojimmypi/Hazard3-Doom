# FPGA USB DFU bootloaders: ULX3S, ULX4M, ULX5M-GS

This directory is a clean source tree for the supported bootloaders.
The existing ECP5 ULX3S/ULX4M build remains under `Makefile`.
The GateMate ULX5M-GS has one canonical build: `Makefile.ulx5m-gs`.
Milestones and experimental branches belong in Git history, not in
parallel versioned source files, Makefiles, or test scripts.

## ULX5M-GS current status (October 30, 2026)

**Hardware verified:** a persistent seed-160 primary starts in BTN2-held
USB DFU (`FWTN`) or, with BTN2 released, autonomously reconfigures a native
secondary at flash `0x201000`. The walking-LED secondary has booted after
multiple cold starts with Tigard powered off. Both the persistent `FWTN`
and volatile JTAG-loaded full-image candidate `FWTF` enumerate as
USB `1D50:614B` and have independently read back the complete 3,026-byte
secondary with a matching SHA256.

**Not yet hardware verified:** a full-image USB secondary erase/program/FINISH
cycle, interrupted-update recovery, or automatic rollback. The `FWTF`
writer is experimental; the installed golden primary must remain protected.

See **[ULX5M-GS SERV bootloader: operation, setup, and recovery](docs/ulx5m-gs-serv-bootloader.md)**
for hardware architecture, LED interpretation, USB protocol, SPI flash
layout, prerequisite toolchains, newcomer build/install/usage steps,
Windows-native USB probing from WSL, safety restrictions, and recovery.

For quick offline qualification from `bootloader-serv/` in WSL:

```sh
make -f Makefile.ulx5m-gs show-settings
make -f Makefile.ulx5m-gs test
make -f Makefile.ulx5m-gs build SEED=160
make -f Makefile.ulx5m-gs qualify SEED=160
```

A build packs `build-ulx5m-gs/bootloader/top_ulx5m_gs_bootloader-PACK-ONLY.bit`
and derives the 27-byte secondary boot command from that packed result.
The default firmware is the restricted `FWTN` profile. Explicitly passing
`DFU_FULL_IMAGE=1` selects the experimental `FWTF` profile; it changes the
image hash and requires independent build, timing, and hardware qualification.
No standard Makefile target programs FPGA SRAM or persistent flash.

## Existing ULX3S / ULX4M builds

```sh
make MODEL=ulx3s BOARD=ulx3s-v20
make MODEL=ulx4m BOARD=ulx4m-v002 DEVICE=um-85k
```

Follow your working local board settings if different. Repository-root
CI scripts outside this replacement directory may still reference legacy
ULX5M filenames; update those references before expecting CI to pass.
