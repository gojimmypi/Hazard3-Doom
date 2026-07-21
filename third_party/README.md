# Third-party source

This directory contains two Git submodules:

```text
third_party/doomgeneric
    Upstream DoomGeneric source pinned by the parent repository.

third_party/Hazard3
    Hazard3 CPU and ULX3S/ULX4M hardware support. The temporary branch is
    ulx3s-dev until the hardware-only ulx-doom branch is prepared.
```

From the Hazard3-Doom repository root, initialize the submodules required for
the FPGA and Doom builds with:

```bash
./scripts/setup-submodules.sh
```

This initializes DoomGeneric, Hazard3, Hazard3's `scripts` submodule, and
Hazard3's `example_soc/libfpga` submodule. It does not download the large
compliance, formal, RISC-V test, or Embench submodules.

To initialize every Hazard3 test submodule as well, use:

```bash
HAZARD3_INIT_ALL_SUBMODULES=1 ./scripts/setup-submodules.sh
```

Doom builds copy the DoomGeneric source into `build/` and apply the local patch
there. The DoomGeneric submodule must remain clean.
