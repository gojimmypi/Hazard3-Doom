# Bootloader timing sweep (GitHub Actions)

The workflow `.github/workflows/bootloader-seed-sweep.yml` provides a manual,
non-programming seed sweep for the ULX5M-GS bootloader implementations.

In GitHub Actions, select **Bootloader seed sweep**, choose **Run workflow**,
select branch `develop`, and set:

- `bootloader`: `serv` or `picorv32`
- `board`: `ulx5m-gs` (only verified target currently)
- `start_seed`: first seed (default 1)
- `seed_count`: number of seeds (default 20; maximum 260)

The workflow synthesizes the relevant JSON netlist once, then invokes the
existing bootloader sweep script. No bitstream packing, JTAG access, DFU
transfers or flash writes are requested by the workflow.

Local equivalents, using WSL and an already configured OSS CAD Suite:

```bash
cd bootloader-serv
make -f Makefile.ulx5m-gs build-ulx5m-gs/top_ulx5m_gs_flash_read-serv.json
./scripts/sweep-ulx5m-serv.sh 1 20
```

```bash
cd bootloader
make -f Makefile.ulx5m-gs build-ulx5m-gs/top_ulx5m_gs_flash_read.json
./scripts/sweep-ulx5m-flash-read.sh 1 20
```

## Caveats

This is an initial standalone workflow, not an exact copy of the Doom sweep
UI. Existing Doom workflow input names and all local Makefile recipes were
not available for inspection when it was created. In particular, check
whether the two JSON targets require other generated prerequisites before
merging. The workflow intentionally does not expose a clock override,
timing weight or parallel routing until those are confirmed to be supported
by the selected bootloader scripts. The nextpnr target constraint remains
defined by the checked-in SDC rather than an unvalidated action input.

Keep the known-good SERV v16g2f seed-5 bitstream, JSON and constraint hashes
outside the new sweep's output directory. Sweeps do not validate USB/DFU
operation on hardware and must not replace a hardware-tested baseline.
