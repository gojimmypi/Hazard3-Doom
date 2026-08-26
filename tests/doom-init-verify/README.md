# Hazard3 Doom initialization verifier

Focused verifier for the ULX3S-12F Doom initialization failure.

The diagnostic runs established nondeterministic cache-backed SDRAM failures: the
same image alternately returned the live `PNAMES` buffer for `TEXTURE1`,
reported an invalid texture directory, faulted on a store through address
`0x00000007`, or completed that stage after a layout change.

The routed 50 MHz report identifies the failing path. The 12F `clk_sys` domain
closes at 30.61 MHz, with a 32.67 ns path beginning at the SDRAM cache tag EBR
and ending in the Hazard3 CPU pipeline. The correction keeps the required
50 MHz SDRAM/video/UART domain and adds one registered cycle to 12F SDRAM-cache
read hits, cutting that cache-to-CPU combinational path. The 85F keeps its
existing zero-wait read-hit behavior.

The verifier keeps the direct SDRAM WAD transport check and stock Zone-cache
semantics. It is intentionally not a mapped-WAD workaround.

Build:

```bash
./tests/doom-init-verify/build.sh
```

Output:

`build/doom-init-verify/doom-image/hazard3-doom.h3d`

The same command also rebuilds
`build/ulx3s-12f/monitor/hazard3-boot-monitor.elf`. Load that monitor before
launching the diagnostic image; it prints an immediate launch acknowledgement
before the restart-image copy and returns to a usable prompt after fatal exit.

This test requires the newly rebuilt 50 MHz 12F FPGA bitstream. Its routed
report must show `clk_sys` passing 50 MHz before the Doom test is meaningful.

The verifier should pass the
transport check and proceed beyond texture construction without a trap:

```text
H3DIV TEXTURE1 transport ... destination=7bfce9c1 expected=7bfce9c1 ...
```

Fatal exits must return immediately to the monitor prompt, and `j` must print
its launch acknowledgement before restoring the saved image.
