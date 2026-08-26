# Hazard3 Doom initialization verifier

Focused verifier for the ULX3S-12F Doom initialization failure.

The failing run established that `W_CacheLumpName("TEXTURE1")` returned the
still-live `PNAMES` buffer: the reported count was 350 and the first directory
word was `0x4c4c4157` (`WALL`). The expected `TEXTURE1` values are 125 and
`0x000001f8`.

This verifier exposes the monitor-provided IWAD as a mapped, immutable WAD.
Doom therefore reads lumps directly from their uploaded SDRAM addresses and
does not create redundant Zone-cache copies with owner pointers.

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

The first decisive line must be:

```text
H3DIV TEXTURE1 cache count=125 dir0=000001f8 bytes=00002412
```

Any different count or first directory offset is a hard failure before texture
construction begins.
