/* -----------------------------------------------------------------------------
 * File:        link.ld
 * Path:        src/link.ld
 *
 * Project:     Hazard3-Doom
 * Purpose:     Define the default resident Hazard3-Doom monitor memory layout.
 *
 * Copyright (c) 2026 gojimmypi
 *
 * Licensed under the Apache License, Version 2.0.
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * This software is provided under the terms of the applicable license.
 * See LICENSES/Apache-2.0.txt for the complete license terms.
 * See LICENSING.md for project licensing policy and scope.
 * -------------------------------------------------------------------------- */

ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 64K
}

SECTIONS
{
    .vectors 0x00000040 :
    {
        KEEP(*(.vectors))
    } > RAM

    .text :
    {
        *(.text*)
        *(.rodata*)
    } > RAM

    .data :
    {
        *(.data*)
        *(.sdata*)
    } > RAM

    .bss :
    {
        __bss_start = .;
        *(.bss*)
        *(.sbss*)
        *(COMMON)
        __bss_end = .;
    } > RAM

    . = ALIGN(16);
    __stack_top = ORIGIN(RAM) + LENGTH(RAM);

    /*
     * The upper 64 KiB of the physical 128 KiB SRAM is a dedicated Doom
     * 320x200 indexed working screen. Keeping the Doom renderer target out of
     * the unified SDRAM cache leaves that cache available for code, WAD and
     * heap. Experimental higher-resolution HDMI presentation is scaled from
     * this standard renderer buffer and does not enlarge the on-chip region.
     */
    __doom_screenbuffer_base = 0x00010000;
    __doom_screenbuffer_end = __doom_screenbuffer_base + 320 * 200;

    ASSERT(__bss_end <= __stack_top - 16K,
        "Monitor image leaves less than 16 KiB for the Doom/interrupt stack")
    ASSERT(__doom_screenbuffer_end <= 0x00020000,
        "Doom screen buffer exceeds internal SRAM")
}
