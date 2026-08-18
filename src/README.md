# Hazard3-Doom/src

This directory contains the source files for the Hazard3-Doom resident boot monitor `hazard3-boot-monitor`
and the Tiny Tapeout project template.

## Hazard3-Doom Resident Boot Monitor

The resident boot monitor is the firmware that starts with the Hazard3-Doom system
and provides the boot and console environment used before launching Doom.

Core resident monitor files:

- `link.ld` - linker script for the resident monitor
- `main.c` - main resident monitor implementation
- `start.S` - startup and entry code

## Tiny Tapeout Template Files

- `config.json`
- `project.v`
