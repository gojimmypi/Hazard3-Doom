# Hazard3 Doom initialization verifier

This is a software-only diagnostic for the ULX3S 12F Doom startup failure.
It does not change RTL, the FPGA bitstream, the resident monitor, or the
DoomGeneric submodule working tree.

The verifier runs inside the real Doom `R_InitTextures()` and
`R_GenerateLookup()` paths. It is designed to stop at the first software-
visible inconsistency instead of eventually reporting the less-specific
`R_InitTextures: bad texture directory` or `texture N is >64k` errors.

## What it verifies

All diagnostic state is static image BSS. No extra Doom Zone allocations are
made, so the normal Zone allocation order remains unchanged.

The build checks:

1. `PNAMES` cached data against an independent second `W_ReadLump()` copy.
2. `TEXTURE1` cached data against an independent second `W_ReadLump()` copy.
3. The known DOOM1.WAD `PNAMES` and `TEXTURE1` FNV-1a hashes.
4. Every `TEXTURE1` directory offset before Doom uses it.
5. Every raw `maptexture_t` against the independent TEXTURE1 snapshot.
6. Every constructed `textures[i]` pointer, name, dimensions, patch count,
   patch placement and resolved patch lump numbers.
7. Texture-object stability across the column-table Zone allocations.
8. Texture-object stability before and after every patch cache operation.
9. `texturecompositesize[i]` from zero through every composite-column update.
10. Uncovered columns and the exact first composite-size invariant failure.

The current diagnostic intentionally targets the shareware `DOOM1.WAD` used in
this 12F investigation. It refuses an IWAD with `TEXTURE2` rather than silently
running a weaker test.

## Verify the host WAD

Optional, but fast:

```bash
./tests/doom-init-verify/reference-wad.py ./wads/DOOM1.WAD
```

Expected:

```text
PNAMES: PASS ... fnv1a=0x70DCD40A
TEXTURE1: PASS ... fnv1a=0x7BFCE9C1
```

## Build

```bash
chmod +x tests/doom-init-verify/build.sh
./tests/doom-init-verify/build.sh
```

Output:

```text
build/doom-init-verify/doom-image/hazard3-doom.h3d
```

This rebuilds only the diagnostic Doom image. It does not synthesize or route
the FPGA.

## Run on ULX3S 12F

Keep the existing FPGA bitstream. Load the normal 12F monitor if needed:

```bash
./scripts/load-firmware-12f.sh
```

Wait for the resident monitor `>` prompt. A valid WAD must already be loaded at
the 32 MiB profile address. If needed:

```bash
./doom/upload-wad.py ./wads/DOOM1.WAD \
    --port /dev/ttyS6 \
    --memory-profile 32m
```

Upload only the diagnostic Doom image:

```bash
python3 doom/upload-doom-image.py \
    build/doom-init-verify/doom-image/hazard3-doom.h3d \
    --port /dev/ttyS6
```

At the monitor prompt:

```text
j
```

Capture the first line beginning with `H3DIV FAIL`. No GDB is needed.

## Reading the first failure

Important failure stages include:

- `known-wad-hash`: the bytes read through Doom's WAD path do not match the
  known DOOM1.WAD PNAMES/TEXTURE1 data.
- `pnames-cache-copy` / `texture1-cache-copy`: the cached lump differs from an
  immediate independent reread.
- `directory-pointer`: Doom's sequential directory pointer no longer points at
  the directory entry for the current texture.
- `directory-word`: that directory entry differs from the independent TEXTURE1
  snapshot.
- `raw-texture-copy`: the raw texture definition differs from the snapshot.
- `after-columnlump-alloc` / `after-columnofs-alloc`: a constructed texture was
  changed by subsequent Zone allocation activity.
- `lookup-pre-cache` / `lookup-post-cache`: the texture changed around a patch
  `W_CacheLumpNum()` operation.
- `composite-mutated-during-cache` / `composite-mutated-before-scan`: the
  composite size changed before the scan is allowed to modify it.
- `composite-pre` / `composite-post`: the composite size stopped matching the
  exact mathematical value expected for the number of composite columns.
- `column-uncovered`: the texture definition used by lookup leaves a column
  uncovered; this is a fail-fast version of the warning seen in the original
  failure.

If both final lines appear, the whole instrumented texture path passed:

```text
H3DIV texture construction: PASS textures=125
H3DIV texture lookup: PASS textures=125
```
