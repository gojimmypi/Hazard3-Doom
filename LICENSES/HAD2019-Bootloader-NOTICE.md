# HAD2019 / ULX3S / ULX4M DFU bootloader notice

Hazard3-Doom includes or derives bootloader material from the DFU bootloader in
`had2019-playground`, whose lineage begins with the Hackaday Supercon 2019
badge bootloader and continues through ULX3S and ULX4M adaptations.

Upstream source lineage:

- https://github.com/smunaut/had2019-playground/tree/master/projects/bootloader
- https://github.com/lawrie/had2019-playground/tree/master/projects/bootloader
- https://github.com/emard/had2019-playground/tree/master/projects/bootloader

The upstream repository states that licensing is individual to each IP
core/project and source file. The source-file headers and the exact upstream
revision used by Hazard3-Doom are therefore authoritative. This notice does not
replace or narrow those upstream notices.

## Principal contributors and embedded third-party authors

- Sylvain Munaut (`smunaut`) - original Hackaday Supercon 2019 badge
  bootloader author and principal original copyright holder.
- Jeroen Domburg (`Spritetm`) - author of multiple commits in the original
  bootloader history, including DFU, flash-selection, and protection changes.
- Lawrie Griffiths (`lawrie`) - contributor to the ULX3S fork/adaptation and
  later bootloader changes.
- Davor Jadrijevic (`emard`) - extensive ULX3S/ULX4M adaptation, integration,
  maintenance, and board-specific work.
- Clifford Wolf - author/copyright holder of the PicoRV32 core included by the
  upstream bootloader.
- Michal Ludvig - author/copyright holder of the minimal `snprintf`
  implementation in upstream `fw/mini-printf.c`.
- All other contributors recorded in the upstream repositories and Git
  histories are acknowledged by reference.

## Licensing summary

The bootloader must not be treated as a single dual-licensed component. Apply
the license attached to each upstream file or incorporated component. In the
reviewed upstream source:

- Bootloader firmware source files carrying Sylvain Munaut's `LGPL v3+` notice
  are licensed under LGPL-3.0-or-later. The GNU LGPL v3 text is in
  `LGPL-3.0.txt`.
- Bootloader RTL files carrying Sylvain Munaut's `BSD 3-clause` notice are
  licensed under BSD-3-Clause. The matching upstream license text is in
  `BSD-3-Clause-HAD2019-Bootloader.txt`.
- `rtl/picorv32.v` carries Clifford Wolf's ISC license notice. See
  `ISC-PicoRV32.txt`.
- `fw/mini-printf.c` carries Michal Ludvig's BSD-style 3-clause notice. See
  `BSD-3-Clause-mini-printf.txt`.
- Some adaptation, build, generated-data, or board-specific files may not carry
  one of the notices above. Preserve their exact upstream history and headers,
  and review the exact revision before redistribution rather than assigning a
  license by inference.

Redistributions should preserve all applicable source-file copyright/license
headers and reproduce license notices required for binary distributions.
Attribution here does not imply endorsement by any upstream author or
contributor.
