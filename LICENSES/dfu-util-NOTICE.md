# dfu-util notice

Hazard3-Doom redistributes Windows dfu-util utilities in `bin/` for USB
Device Firmware Upgrade (DFU) workflows:

- `dfu-prefix.exe`
- `dfu-suffix.exe`
- `dfu-util.exe`
- `dfu-util-static.exe`

Upstream project:
https://dfu-util.sourceforge.net/

Upstream source and releases:
https://sourceforge.net/projects/dfu-util/

## License

The dfu-util source headers and manual identify the program as free software
under the GNU General Public License, version 2 or (at the user's option) any
later version. The upstream `COPYING` file distributed with dfu-util contains
the GNU GPL version 2 text. A copy is preserved here as:

    LICENSES/dfu-util-COPYING.txt

The dfu-util binaries are third-party software and are not relicensed by
Hazard3-Doom. Distribution of the binaries must satisfy the applicable GPL
requirements, including the corresponding-source requirements for the exact
binary version being distributed.

## Attribution

dfu-util originated in the OpenMoko project. Upstream documentation credits
Weston Schmidt and Harald Welte as original authors. The project has been
maintained and developed by Tormod Volden, Stefan Schmidt, and additional
contributors. Copyright notices in upstream source also identify OpenMoko,
Inc. for portions of the implementation.

All dfu-util contributors are acknowledged by reference to the upstream
project and source history.

## Release provenance requirement

Before publishing these convenience binaries, record for the exact files in
`bin/`:

- the dfu-util release or source revision;
- the origin/download archive;
- SHA-256 hashes;
- the matching upstream `COPYING`, source, and other required notices; and
- the licenses and source obligations of any libraries incorporated into or
  shipped with the binaries.

In particular, do not assume that `dfu-util-static.exe` has the same dependency
packaging obligations as `dfu-util.exe`. The static executable may incorporate
library code that is supplied separately for the dynamically linked build, so
its exact build provenance and dependency licenses must be audited.

The presence of `libusb-1.0.dll` beside `dfu-util.exe` does not by itself prove
which libusb version or other dependencies were used by every bundled dfu-util
executable. Pin the exact upstream binary package before release.
