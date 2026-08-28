/* -----------------------------------------------------------------------------
 * File:        link.ld
 * Path:        tests/software-verify/link.ld
 *
 * Project:     Hazard3-Doom
 * Purpose:     Define the memory layout used by the standalone software
 *              verification payload.
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

OUTPUT_ARCH(riscv)
ENTRY(_start)

SECTIONS
{
    /*
     * Match the ULX3S-12F monitor execution path: code is loaded into the
     * cached external SDRAM window. Keep clear of the 0x20040000 framebuffer.
     */
    . = 0x20000040;

    .text :
    {
        KEEP(*(.text.start))
        *(.text*)
        *(.rodata*)
    }

    . = ALIGN(4);
    .data :
    {
        *(.sdata*)
        *(.data*)
    }

    . = ALIGN(4);
    __bss_start = .;
    .bss :
    {
        *(.sbss*)
        *(.bss*)
        *(COMMON)
    }
    __bss_end = .;

    ASSERT(. < 0x20030000, "software verifier image overlaps reserved stack area")

    __stack_top = 0x2003fff0;
}
