# Hazard3-Doom/src

This directory contains the source files for the Hazard3-Doom resident boot monitor `hazard3-boot-monitor`
and the Tiny Tapeout project template.

## Hazard3-Doom Resident Boot Monitor

The resident boot monitor is the firmware that starts with the Hazard3-Doom system
and provides the boot and console environment used before launching Doom.

Core resident monitor files:

- `link.ld` - linker script for the resident monitor
- `link-12f-sdram.ld` - linker script for the ULX3S 12F SDRAM-resident monitor
- `main.c` - main resident monitor implementation
- `start.S` - startup and entry code
- `bootstrap-12f.S` - minimal 115200-baud cold-boot message for the 12F EBR
- `link-12f-bootstrap.ld` - linker script constraining that bootstrap to 1 KiB

## Tiny Tapeout Template Files

- `config.json`
- `project.v`

### FPGA smoke-test behavior

`project.v` implements a small standalone Tiny Tapeout test, not the
Hazard3 CPU, boot monitor, or Doom hardware. Its dedicated outputs are:

- `uo_out[7:5] = 3'b110` - fixed smoke-image identification bits.
- `uo_out[4]` - bit-level loopback from `ui_in[3]` (UART RX), synchronized
  through two flip-flops. Idle is high when disabled or in reset.
- `uo_out[3:0]` - visible counter bits driven by `clk` while `ena` is high.
- `uio_oe = 0` - all bidirectional pins remain inputs (not driven).

The loopback does not decode UART bytes or guarantee an exact baud-rate
phase. It is useful for checking pin connectivity at the FPGA test boundary.
The complete Hazard3-Doom FPGA builds and timing closure are independent.

Warnings involving `uart_tx_pin`, `gp1`, or undriven input nets in the
shared `tt_fpga_top_ulx3s.v` wrapper must be investigated in
`ulx3s/tt-support-tools`; editing this project alone does not repair
wrapper wiring.

The detailed ULX3S Tiny Tapeout FPGA build flow, including the
`ulx3s/tt-gds-action` GitHub Action, the `ulx3s/tt-support-tools` backend,
local build commands, generated artifacts, UART mapping, and troubleshooting,
is documented in `docs/getting-started/tiny-tapeout-ulx3s.rst`.

## ULX3S Chat and support

### Discord channel

- [https://discord.gg/qwMUk6W](https://discord.gg/qwMUk6W) (problems/question/general chat); [#hazard3-doom](https://discord.com/channels/690209441953480758/1546280673822642186)

### Gitter channel

- [https://gitter.im/ulx3s/Lobby](https://gitter.im/ulx3s/Lobby) (Focused on development)

### Email

- [ulx3s.fpga@gmail.com](mailto:ulx3s.fpga@gmail.com) (If you do not use chats)
