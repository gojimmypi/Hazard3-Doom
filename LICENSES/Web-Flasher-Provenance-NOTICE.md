# Browser WebUSB flasher provenance notice

Hazard3-Doom's browser-side ULX3S flasher is an original project integration,
but its engineering is informed by several independent upstream projects and
technical references.

The project handoff records that:

- browser-side `.bit` to ECP5 SRAM SVF conversion is based on knowledge from
  the Project Trellis ECP5 programming flow;
- the FT231X synchronous-bit-bang JTAG receive alignment follows behavior
  learned from fujprog;
- FTDI's synchronous bit-bang documentation explains the one-output-byte input
  pipeline behavior used to correct TDO sampling;
- FTDI/libftdi/fujprog references inform FT231X USB/UART request behavior.

Credits:

- Project Trellis / YosysHQ and all contributors;
- Marko Zec, EMARD, gojimmypi, kost, and other fujprog/ujprog contributors;
- FTDI documentation authors and device engineers;
- Intra2net/libftdi developers;
- WebUSB and Web Serial standards/browser implementers.

This notice intentionally distinguishes technical inspiration from copied
source. Before release, review `web/flasher.js` and related files against the
exact fujprog, Project Trellis, and other references used during implementation.
If source code, tables, literal command sequences, or other copyrightable
implementation material was copied or closely translated, retain the exact
upstream license notice with the derived code. Project Trellis code is
ISC-licensed upstream and its database is separately published under CC0; see
`CC0-1.0.txt` for the database license reference.
