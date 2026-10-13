# CoreMark notice

Hazard3-Doom uses the CoreMark workload from
`third_party/Hazard3/test/sim/coremark/dist` with platform support in
`benchmarks/coremark`.

CoreMark is a registered trademark of the Embedded Microprocessor Benchmark
Consortium (EEMBC). Use of CoreMark in Hazard3-Doom does not imply EEMBC
endorsement or certification.

Upstream references:

- Source: https://github.com/eembc/coremark
- License: https://github.com/eembc/coremark/blob/main/LICENSE.md
- Run and reporting rules: https://github.com/eembc/coremark/blob/main/README.md

## Software license and trademark terms

The upstream `LICENSE.md` contains both the CoreMark Acceptable Use Agreement
and Apache License 2.0. An unmodified reference copy retrieved on 2026-10-13
(UTC) is preserved in `CoreMark-LICENSE.md`. For a release, verify these terms
against the exact CoreMark source revision being distributed; the reference
copy does not establish the provenance of the Hazard3 workload files.

Apache-2.0 permits use, modification, and redistribution of the software under
its conditions. The separate agreement governs use of the CoreMark trademark.
Section 1.2 restricts trademark use with modified software, and section 2.1
requires an appropriate ownership notice. The agreement also contains
indemnification, termination/removal, and legal-fee provisions. Neither this
notice nor the project's Apache-2.0 declarations replace those terms.

## Platform port and benchmark integrity

The upstream run rules permit platform changes to `core_portme.c`,
`core_portme.h`, and `core_portme.mak`, and changes to iteration count,
toolchain, build/load/run options, memory allocation, and seed acquisition.
Other benchmark source files must remain unchanged for a conforming run.

Keep Hazard3 startup, linker, UART, timing, and host-capture support separate
from the workload. Verify the workload against an identified official CoreMark
revision before publishing a score. The build's source-integrity check against
the checked-out Hazard3 commit establishes local consistency; it does not by
itself prove equality with official CoreMark sources or trademark compliance.

## Reporting results

Before reporting a standard score:

- Use a total data size of 2000 bytes. Validate both seed configurations:
  `0,0,0x66` and `0x3415,0x3415,0x66`.
- Run each benchmark for at least 10 seconds and compile all benchmark source
  files with the same flags. Follow the upstream type-size and, if applicable,
  profile-guided optimization rules.
- Record compiler version and flags, iterations, actual CPU clock, code/data/
  stack placement, source revisions, ELF hash, and the captured run results.
- Use the upstream reporting format. Include memory-placement details when
  reporting CoreMark/MHz. For this port, use the host rate calculated from the
  full 64-bit cycle count rather than the integer-truncated target rate.

The local runner's `RESULT : VALID` means that its implemented checks passed.
It is not EEMBC certification or approval. Identify results as locally measured.
Do not represent an altered workload as a standard CoreMark result.

## Redistribution

When distributing CoreMark source or compiled benchmark binaries, include the
applicable complete upstream license, retain source copyright and attribution
notices, identify changes to modified files, and preserve applicable upstream
NOTICE material. Include the trademark ownership notice with benchmark
information. Upstream contributor acknowledgements are retained in
`../ATTRIBUTION.md`.
