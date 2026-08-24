# Hazard3 Doom texture integrity verifier

This is a software-only diagnostic build. It does not modify RTL, the resident
monitor, or the DoomGeneric submodule.

The test builds a prepared copy of DoomGeneric and replaces only `r_data.c` in
that disposable build directory. The diagnostic `r_data.c` does not allocate
additional Doom Zone memory, so the Zone heap allocation order/layout remains
unchanged.

It checks four things:

1. Each constructed texture matches its raw TEXTURE1/TEXTURE2 directory entry.
2. Each `textures[i]` pointer remains the pointer originally returned for `i`.
3. Immutable texture fields and patch descriptors do not change during lookup.
4. `texturecompositesize[i]` is exactly the mathematically expected value before
   and after every composite-column update.

Any first mismatch terminates through the normal Doom `I_Error` path with an
`H3TV FAIL ...` line identifying the stage and texture index.

## Build

```bash
./tests/texture-verify/build.sh
```

The image is written to:

```text
build/texture-verify/doom-image/hazard3-doom.h3d
```

## ULX3S 12F test

With the 12F FPGA already configured and OpenOCD running:

```bash
./scripts/load-firmware-12f.sh
python3 doom/upload-doom-image.py \
    build/texture-verify/doom-image/hazard3-doom.h3d \
    --port /dev/ttyS6
```

The 12F monitor's SD cold boot may load the WAD before returning to the prompt.
If a valid WAD is already loaded at the 32 MiB profile address, enter `j`.
Otherwise upload it with `--memory-profile 32m` first.

Expected diagnostic progress includes:

```text
H3TV texture table build: PASS textures=...
H3TV texture lookup integrity: PASS textures=...
```

If Doom reproduces the current failure, capture the first line beginning with:

```text
H3TV FAIL
```

That single line should identify whether the first bad state is raw texture
construction, the pointer table, immutable texture contents, or composite-size
state.
