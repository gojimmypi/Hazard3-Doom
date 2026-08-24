# Hazard3 Doom initialization verifier v3

Software-only A/B diagnostic for the ULX3S-12F Doom initialization failure.

Observed v2 failure:

- PNAMES cached correctly.
- The first cached TEXTURE1 copy was wrong.
- An immediate second W_ReadLump() into the exact same Zone buffer passed.
- BSS-to-Zone memcpy passed.
- BSS-to-Zone byte copy passed.
- The first bad TEXTURE1 byte was 0x5e, which is also the first byte of
  PNAMES in the tested DOOM1.WAD; correct TEXTURE1 begins with 0x7d.

This v3 test retains the v2 H3DIV instrumentation but substitutes a diagnostic
`w_file_stdc.c` that calls `setvbuf(fstream, NULL, _IONBF, 0)` immediately after
opening the WAD. This disables newlib stdio read buffering/fseek optimization
for the in-memory WAD stream while leaving Doom's WAD abstraction and the
Hazard3 `_lseek` / `_read` backend unchanged.

If TEXTURE1 now passes on its first cache fill and Doom proceeds, the failure is
isolated to buffered stdio/fseek state, not SDRAM, Zone allocation, memcpy, or
texture construction.

Build:

```bash
chmod +x tests/doom-init-verify/build.sh
./tests/doom-init-verify/build.sh
```

Output:

`build/doom-init-verify/doom-image/hazard3-doom.h3d`
