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
