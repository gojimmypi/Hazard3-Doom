/* -----------------------------------------------------------------------------
 * File:        link-12f-bootstrap.ld
 * Path:        src/link-12f-bootstrap.ld
 *
 * Project:     Hazard3-Doom
 * Purpose:     Link the ULX3S 12F UART bootstrap into its 1 KiB EBR window.
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
    BOOT (rx) : ORIGIN = 0x00000000, LENGTH = 1K
}

SECTIONS
{
    .text 0x00000040 :
    {
        KEEP(*(.text.start))
        *(.text*)
        *(.rodata*)
    } > BOOT

    . = ALIGN(4);
    __bootstrap_end = .;

    /DISCARD/ :
    {
        *(.comment*)
        *(.riscv.attributes*)
    }

    ASSERT(__bootstrap_end <= ORIGIN(BOOT) + LENGTH(BOOT),
        "ULX3S 12F bootstrap exceeds the 1 KiB EBR window")
}
