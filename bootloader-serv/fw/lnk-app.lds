/* -----------------------------------------------------------------------------
 * File:        lnk-app.lds
 * Path:        bootloader/fw/lnk-app.lds
 *
 * Project:     Hazard3-Doom
 * Purpose:     Define the RISC-V bootloader firmware memory layout and linker sections.
 *
 * Original author(s):    Sylvain Munaut (smunaut)
 *
 * Upstream:    HAD2019 / ULX3S / ULX4M DFU bootloader
 * Upstream license: No file-level license notice was present in this
 *                   imported upstream file; do not infer one here.
 *
 * This file contains third-party material and is not relicensed by
 * Hazard3-Doom. Preserve its upstream history and provenance.
 * See LICENSES/HAD2019-Bootloader-NOTICE.md for provenance and licensing.
 * See LICENSING.md for project licensing policy and scope.
 * -------------------------------------------------------------------------- */

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 0x8000
}
ENTRY(_start)
SECTIONS {
    .text :
    {
        . = ALIGN(4);
        *(.text.start)
        *(.text)
        *(.text*)
        *(.rodata)
        *(.rodata*)
        *(.srodata)
        *(.srodata*)
        . = ALIGN(4);
        _etext = .;
        _sidata = _etext;
    } >RAM
    .data : AT ( _sidata )
    {
        . = ALIGN(4);
        _sdata = .;
        _ram_start = .;
        . = ALIGN(4);
        *(.data)
        *(.data*)
        *(.sdata)
        *(.sdata*)
        . = ALIGN(4);
        _edata = .;
    } >RAM
    .bss :
    {
        . = ALIGN(4);
        _sbss = .;
        *(.bss)
        *(.bss*)
        *(.sbss)
        *(.sbss*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } >RAM
    .heap :
    {
        . = ALIGN(4);
        _heap_start = .;
    } >RAM
}
